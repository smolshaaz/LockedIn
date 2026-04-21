import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import { chatRequestSchema } from "../schemas/contracts"
import { domainsForRequest, normalizeChatRequest } from "../services/chat-context"
import { services } from "../services/container"
import { badRequest } from "../utils/http"

export const chatRoutes = new Hono()

chatRoutes.use("*", authMiddleware)

function parseChat(body: unknown) {
  const parsed = chatRequestSchema.safeParse(body)
  if (!parsed.success) {
    return {
      ok: false as const,
      error: parsed.error.issues[0]?.message ?? "Invalid chat payload",
    }
  }

  return {
    ok: true as const,
    request: parsed.data,
  }
}

async function loadChatContext(userId: string, request: { threadId: string; message: string }) {
  await services.threadState.hydrate(userId, request.threadId)
  const profile = await services.memory.getProfile(userId)
  const recalled = await services.memory.recall(userId, request.message)

  return {
    profile,
    recalled,
  }
}

async function runChat(userId: string, body: unknown) {
  const parsed = parseChat(body)
  if (!parsed.ok) return parsed

  const request = normalizeChatRequest(parsed.request)
  const context = await loadChatContext(userId, request)
  const reply = await services.coach.generateReply({
    userId,
    request,
    profile: context.profile,
    recalledMemory: context.recalled,
  })

  await services.memory.appendChatTurn(userId, request, reply.message)
  services.threadState.bump(userId, request.threadId)

  if (reply.suggestedProtocol) {
    const domains = domainsForRequest(request)
    reply.taskSync = await services.memory.createTasksFromProtocol({
      userId,
      plan: reply.suggestedProtocol,
      domain: domains.length === 1 ? domains[0] : undefined,
    })
  }

  return {
    ok: true as const,
    request,
    reply,
  }
}

chatRoutes.post("/", async (c) => {
  const userId = c.get("userId")
  const body = await c.req.json().catch(() => null)
  const result = await runChat(userId, body)

  if (!result.ok) {
    return badRequest(c, result.error)
  }

  return c.json(result.reply)
})

chatRoutes.post("/stream", async (c) => {
  const userId = c.get("userId")
  const body = await c.req.json().catch(() => null)
  const parsed = parseChat(body)

  if (!parsed.ok) {
    return badRequest(c, parsed.error)
  }

  const request = normalizeChatRequest(parsed.request)
  const context = await loadChatContext(userId, request)
  const coachStream = await services.coach.streamReply({
    userId,
    request,
    profile: context.profile,
    recalledMemory: context.recalled,
  })

  const encoder = new TextEncoder()

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const push = (event: string, data: unknown) => {
        const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`
        controller.enqueue(encoder.encode(payload))
      }

      push("meta", {
        modelUsed: coachStream.modelUsed,
        realityCheck: coachStream.realityCheck,
      })

      let replyMessage = ""

      if (coachStream.mode === "stream") {
        try {
          for await (const chunk of coachStream.textStream) {
            replyMessage += chunk
            push("token", { token: chunk })
          }
        } catch {
          if (!replyMessage.trim()) {
            replyMessage =
              "Model stream failed. Give me one concrete target and one deadline."
            push("token", { token: replyMessage })
          }
        }

        // Some providers may complete a stream without yielding text tokens.
        // Recover with a non-stream generation so UI never lands in an empty state.
        if (!replyMessage.trim()) {
          try {
            const recovered = await services.coach.generateReply({
              userId,
              request,
              profile: context.profile,
              recalledMemory: context.recalled,
            })
            replyMessage = recovered.message.trim()
            if (replyMessage) {
              push("token", { token: replyMessage })
            }
          } catch {
            // Keep existing fallback below.
          }
        }
      } else {
        replyMessage = coachStream.message
        const words = replyMessage.split(/\s+/).filter(Boolean)
        for (let i = 0; i < words.length; i++) {
          const hasNext = i < words.length - 1
          push("token", { token: words[i] + (hasNext ? " " : "") })
        }
      }

      const finalMessage = replyMessage.trim() || "No response generated."
      await services.memory.appendChatTurn(userId, request, finalMessage)
      services.threadState.bump(userId, request.threadId)

      const suggestedProtocol = await coachStream.suggestedProtocolPromise
      if (suggestedProtocol) {
        push("protocol", suggestedProtocol)
        const domains = domainsForRequest(request)
        const taskSync = await services.memory.createTasksFromProtocol({
          userId,
          plan: suggestedProtocol,
          domain: domains.length === 1 ? domains[0] : undefined,
        })
        push("tasks", taskSync)
      }

      push("done", {
        message: finalMessage,
      })
      controller.close()
    },
  })

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  })
})
