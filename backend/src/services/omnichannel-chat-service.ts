import { createDiscordAdapter } from "@chat-adapter/discord"
import { createRedisState } from "@chat-adapter/state-redis"
import { createTelegramAdapter } from "@chat-adapter/telegram"
import { Chat, type Adapter, type Message, type StateAdapter, type Thread } from "chat"
import {
  chatSdkConfig,
  hasChatStateRedisConfig,
  hasDiscordConfig,
  hasTelegramConfig,
  isChatSdkEnabled,
} from "../config/env"
import { InMemoryChatStateAdapter } from "../integrations/in-memory-chat-state-adapter"
import { MAXX_DOMAINS, type MaxxDomain } from "../types/domain"
import { services } from "./container"

type AdapterName = "telegram" | "discord"
type AutomationKind = "checkin" | "reminder" | "streak"

type ChatRequestContext = {
  wantsProtocol: boolean
  urgency: "low" | "normal" | "high"
  domain?: MaxxDomain
}

export type OmnichannelContact = {
  key: string
  adapterName: AdapterName
  platformUserId: string
  lockUserId: string
  threadId: string
  userName?: string
  fullName?: string
  lastSeenAt: string
}

const CONTACT_ITEM_PREFIX = "automation:contacts:item:"
const CONTACT_INDEX_KEY = "automation:contacts:index"
const CONTACT_TTL_MS = 1000 * 60 * 60 * 24 * 180

function nowISO() {
  return new Date().toISOString()
}

function inferDomain(message: string): MaxxDomain | undefined {
  const lower = message.toLowerCase()
  return MAXX_DOMAINS.find((domain) => lower.includes(domain))
}

function inferContext(message: string): ChatRequestContext {
  const lower = message.toLowerCase()
  const wantsProtocol =
    lower.includes("protocol") ||
    lower.includes("plan") ||
    lower.includes("roadmap") ||
    lower.includes("strategy")

  const urgency: ChatRequestContext["urgency"] =
    lower.includes("urgent") || lower.includes("asap")
      ? "high"
      : lower.includes("later")
        ? "low"
        : "normal"

  return {
    wantsProtocol,
    urgency,
    domain: inferDomain(message),
  }
}

function externalUserId(thread: Thread, message: Message): string {
  return `chat:${thread.adapter.name}:${message.author.userId}`
}

function toAdapterName(name: string): AdapterName | null {
  if (name === "telegram" || name === "discord") return name
  return null
}

function buildContactKey(adapterName: AdapterName, platformUserId: string): string {
  return `${adapterName}:${platformUserId}`
}

function resolveStateAdapter() {
  if (hasChatStateRedisConfig && chatSdkConfig.stateRedisUrl) {
    return createRedisState({
      url: chatSdkConfig.stateRedisUrl,
    })
  }

  return new InMemoryChatStateAdapter()
}

function buildAdapters(): Record<string, Adapter> {
  const adapters: Record<string, Adapter> = {}

  if (hasTelegramConfig) {
    adapters.telegram = createTelegramAdapter({
      botToken: chatSdkConfig.telegram.botToken,
      secretToken: chatSdkConfig.telegram.webhookSecretToken,
      userName: chatSdkConfig.telegram.botUserName,
    })
  }

  if (hasDiscordConfig) {
    adapters.discord = createDiscordAdapter({
      botToken: chatSdkConfig.discord.botToken,
      applicationId: chatSdkConfig.discord.applicationId,
      publicKey: chatSdkConfig.discord.publicKey,
      userName: chatSdkConfig.discord.botUserName,
    })
  }

  return adapters
}

class OmnichannelChatService {
  private readonly enabled = isChatSdkEnabled
  private readonly adapters = buildAdapters()
  private readonly chat: Chat<Record<string, Adapter>> | null

  constructor() {
    if (!this.enabled || Object.keys(this.adapters).length === 0) {
      this.chat = null
      return
    }

    this.chat = new Chat({
      userName: chatSdkConfig.botUserName,
      adapters: this.adapters,
      state: resolveStateAdapter(),
      logger: chatSdkConfig.logLevel,
    })

    this.registerHandlers(this.chat)
  }

  private async ensureInitialized(): Promise<boolean> {
    if (!this.chat) return false
    try {
      await this.chat.initialize()
      return true
    } catch (error) {
      console.error(
        `[omnichannel] initialize failed: ${error instanceof Error ? error.message : "unknown error"}`,
      )
      return false
    }
  }

  private getStateAdapter(): StateAdapter | null {
    if (!this.chat) return null
    return this.chat.getState()
  }

  private async rememberContact(thread: Thread, message: Message) {
    const adapterName = toAdapterName(thread.adapter.name)
    if (!adapterName) return

    const platformUserId = String(message.author.userId)
    const key = buildContactKey(adapterName, platformUserId)
    const contact: OmnichannelContact = {
      key,
      adapterName,
      platformUserId,
      lockUserId: externalUserId(thread, message),
      threadId: thread.id,
      userName: message.author.userName,
      fullName: message.author.fullName,
      lastSeenAt: nowISO(),
    }

    const state = this.getStateAdapter()
    if (!state) return

    const itemKey = `${CONTACT_ITEM_PREFIX}${key}`
    await state.set(itemKey, contact, CONTACT_TTL_MS)
    await state.appendToList(CONTACT_INDEX_KEY, key, {
      maxLength: 10000,
      ttlMs: CONTACT_TTL_MS,
    })
  }

  async listContacts(): Promise<OmnichannelContact[]> {
    const ready = await this.ensureInitialized()
    if (!ready) return []

    const state = this.getStateAdapter()
    if (!state) return []

    const keys = await state.getList<string>(CONTACT_INDEX_KEY)
    if (!keys.length) return []

    const dedupedKeys = [...new Set(keys)]
    const contacts: OmnichannelContact[] = []

    for (const key of dedupedKeys) {
      const contact = await state.get<OmnichannelContact>(`${CONTACT_ITEM_PREFIX}${key}`)
      if (!contact) continue
      contacts.push(contact)
    }

    return contacts
  }

  async sendMessageToContact(contact: OmnichannelContact, message: string) {
    const ready = await this.ensureInitialized()
    if (!ready) {
      return {
        ok: false as const,
        error: "Chat SDK unavailable",
      }
    }

    const adapter = this.adapters[contact.adapterName]
    if (!adapter) {
      return {
        ok: false as const,
        error: `Adapter "${contact.adapterName}" not configured`,
      }
    }

    try {
      await adapter.postMessage(contact.threadId, message)
      return {
        ok: true as const,
      }
    } catch (error) {
      return {
        ok: false as const,
        error: error instanceof Error ? error.message : "send failed",
      }
    }
  }

  async reserveAutomationSend(input: {
    kind: AutomationKind
    contactKey: string
    bucket: string
    ttlMs: number
  }): Promise<boolean> {
    const ready = await this.ensureInitialized()
    if (!ready) return false

    const state = this.getStateAdapter()
    if (!state) return false

    const key = `automation:sent:${input.kind}:${input.contactKey}:${input.bucket}`
    return state.setIfNotExists(
      key,
      {
        at: nowISO(),
      },
      input.ttlMs,
    )
  }

  private async runLockFlow(thread: Thread, message: Message) {
    const userId = externalUserId(thread, message)
    await this.rememberContact(thread, message)

    const request = {
      threadId: thread.id,
      message: message.text,
      context: inferContext(message.text),
    }

    const profile = await services.memory.getProfile(userId)
    const recalled = await services.memory.recall(userId, request.message)
    const streamResult = await services.coach.streamReply({
      userId,
      request,
      profile,
      recalledMemory: recalled,
    })

    let replyMessage = ""
    if (streamResult.mode === "stream") {
      const stream = streamResult.textStream
      async function* mirrorText() {
        for await (const chunk of stream) {
          replyMessage += chunk
          yield chunk
        }
      }
      await thread.post(mirrorText())
    } else {
      replyMessage = streamResult.message
      await thread.post(replyMessage)
    }

    const finalMessage = replyMessage.trim() || "No response generated."
    await services.memory.appendChatTurn(userId, request, finalMessage)

    const protocol = await streamResult.suggestedProtocolPromise
    if (!protocol) return

    const taskSync = await services.memory.createTasksFromProtocol({
      userId,
      plan: protocol,
      domain: request.context.domain,
    })

    await thread.post(
      `Protocol ready: ${protocol.objective}\nDrafted ${taskSync.createdDrafts.length} tasks, auto-activated ${taskSync.autoActivated.length}.`,
    )
  }

  private registerHandlers(chat: Chat<Record<string, Adapter>>) {
    chat.onNewMention(async (thread, message) => {
      await thread.subscribe()
      await this.runLockFlow(thread, message)
    })

    chat.onDirectMessage(async (thread, message) => {
      await thread.subscribe()
      await this.runLockFlow(thread, message)
    })

    chat.onSubscribedMessage(async (thread, message) => {
      await this.runLockFlow(thread, message)
    })
  }

  status() {
    return {
      enabled: this.enabled,
      configuredAdapters: Object.keys(this.adapters),
      webhookAdapters: this.chat ? Object.keys(this.adapters) : [],
      usingRedisState: hasChatStateRedisConfig,
    }
  }

  async handleWebhook(adapterName: AdapterName, request: Request): Promise<Response> {
    if (!this.chat) {
      return new Response(
        JSON.stringify({
          error: "Chat SDK disabled or no adapters configured",
        }),
        {
          status: 503,
          headers: { "Content-Type": "application/json" },
        },
      )
    }

    if (!this.adapters[adapterName]) {
      return new Response(
        JSON.stringify({
          error: `Adapter "${adapterName}" is not configured`,
        }),
        {
          status: 404,
          headers: { "Content-Type": "application/json" },
        },
      )
    }

    const handlers = this.chat.webhooks as Record<
      string,
      (request: Request) => Promise<Response>
    >
    return handlers[adapterName](request)
  }
}

const omnichannelService = new OmnichannelChatService()

export function getOmnichannelStatus() {
  return omnichannelService.status()
}

export async function handleOmnichannelWebhook(
  adapterName: AdapterName,
  request: Request,
): Promise<Response> {
  return omnichannelService.handleWebhook(adapterName, request)
}

export async function listOmnichannelContacts() {
  return omnichannelService.listContacts()
}

export async function sendOmnichannelMessageToContact(
  contact: OmnichannelContact,
  message: string,
) {
  return omnichannelService.sendMessageToContact(contact, message)
}

export async function reserveOmnichannelAutomationSend(input: {
  kind: AutomationKind
  contactKey: string
  bucket: string
  ttlMs: number
}) {
  return omnichannelService.reserveAutomationSend(input)
}
