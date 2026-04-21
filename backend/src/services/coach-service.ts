import {
  generateObject,
  generateText,
  stepCountIs,
  tool,
  ToolLoopAgent,
} from "ai"
import { z } from "zod"
import { aiConfig } from "../config/env"
import { resolveLanguageModel } from "../integrations/ai-models"
import {
  maxxDomainSchema,
  protocolPlanSchema,
  type ChatRequest,
  type CoachingTask,
  type CoachReply,
  type Profile,
  type ProtocolPlan,
} from "../schemas/contracts"
import {
  chooseFallbackModel,
  chooseModelForChat,
  type ModelName,
} from "./model-router-service"
import {
  domainsForRequest,
  primaryDomainForRequest,
  urgencyForDomain,
} from "./chat-context"
import type { MemoryService } from "./memory-service"

const STALE_COMPLETION_HOURS = 72
const MAX_ACTIVE_TASKS_BEFORE_DILUTION = 6
const DEFAULT_REALITY_CHECK =
  "Your calendar still decides your outcome. Protect one non-negotiable execution block today."

const COACH_SYSTEM_PROMPT = [
  "You are LOCK, an execution coach.",
  "Be blunt but not brutal. Be direct but not arrogant.",
  "Sound like a successful older brother who genuinely wants the user to win.",
  "Provide protocol depth, concrete planning, and hard accountability.",
  "No soft praise, no corporate wellness speak, no motivational fluff.",
  "Be direct, specific, and concise.",
  "Prioritize one concrete next action with a deadline.",
].join(" ")

const AGENT_SYSTEM_PROMPT = [
  COACH_SYSTEM_PROMPT,
  "You are allowed to use tools for protocol and task planning and execution.",
  "When the user asks for protocol/plan/task list/maxx actions, call create_protocol and then create_maxx_tasks before final answer.",
  "When the user asks to create, complete, reopen, approve, reject, or archive tasks, use the task tools and then confirm what changed.",
  "When user asks to pause a domain, use pause_domain.",
  "When user asks to change protocol objective for a domain, use set_domain_goal.",
  "Keep final answer short and execution-focused.",
].join(" ")

const maxxTaskListSchema = z.object({
  tasks: z.array(
    z.object({
      title: z.string().min(1),
      subtitle: z.string().min(1),
      domain: maxxDomainSchema.optional(),
      estimate: z.string().min(1),
      priority: z.number().int().min(1),
    }),
  ),
})

function buildProtocol(req: ChatRequest): ProtocolPlan {
  return {
    objective: req.context.domain
      ? `Upgrade your ${req.context.domain.toUpperCase()} score by 10 points in 14 days`
      : "Increase total LifeScore by 8 points in 14 days",
    horizonDays: 14,
    steps: [
      {
        title: "Baseline audit",
        action: "Write your current routine and recent misses in one honest note.",
        frequency: "Today",
        reason: "No optimization without accurate baseline.",
      },
      {
        title: "Execution block",
        action: "Schedule one non-negotiable 45-minute block daily for the highest leverage action.",
        frequency: "Daily",
        reason: "Consistency beats intensity spikes.",
      },
      {
        title: "Weekly accountability",
        action: "Complete the weekly check-in with metrics and failures, no sugarcoating.",
        frequency: "Weekly",
        reason: "Measured behavior is improved behavior.",
      },
    ],
    checkpoints: ["Day 3 compliance", "Day 7 score delta", "Day 14 outcome review"],
  }
}

function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  return value.filter((item): item is string => typeof item === "string" && item.trim().length > 0)
}

function readStringMap(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object") return {}
  const out: Record<string, string> = {}
  for (const [key, raw] of Object.entries(value)) {
    if (typeof raw === "string" && raw.trim().length > 0) {
      out[key] = raw.trim()
    }
  }
  return out
}

function profileLine(profile?: Profile): string {
  if (!profile) return "No profile yet. Ask for one clear goal and one hard constraint."

  const payload = profile as Profile & Record<string, unknown>
  const goals = profile.goals.join(", ")
  const constraints = profile.constraints.join(", ") || "none"
  const requestedMaxxes = readStringList(payload.requestedMaxxes)
  const maxxContext = readStringMap(payload.maxxContextNotes)
  const weakness = typeof payload.biggestWeakness === "string" ? payload.biggestWeakness : ""
  const ninetyDayGoal = typeof payload.ninetyDayGoal === "string" ? payload.ninetyDayGoal : ""

  const contextPreview = Object.entries(maxxContext)
    .slice(0, 3)
    .map(([domain, note]) => `${domain}: ${note}`)
    .join(" | ")

  const lines = [
    `Current focus: ${goals}. Constraints: ${constraints}.`,
    `Requested Maxxes: ${requestedMaxxes.join(", ") || "none"}.`,
  ]

  if (weakness.trim()) {
    lines.push(`Known weakness: ${weakness}.`)
  }

  if (ninetyDayGoal.trim()) {
    lines.push(`90-day goal: ${ninetyDayGoal}.`)
  }

  if (contextPreview.trim()) {
    lines.push(`Maxx context: ${contextPreview}.`)
  }

  return lines.join(" ")
}

function memoryLine(recalledMemory: string[]): string {
  if (recalledMemory.length === 0) return "Recall: no relevant history yet."
  return `Recall: ${recalledMemory.join("; ")}`
}

function summarizeTaskForTool(task: CoachingTask) {
  return {
    id: task.id,
    title: task.title,
    subtitle: task.subtitle,
    domain: task.domain,
    state: task.state,
    isCompleted: task.isCompleted,
    priority: task.priority,
    estimate: task.estimate,
    dueAt: task.dueAt,
  }
}

function buildCoachPrompt(input: {
  request: ChatRequest
  profile?: Profile
  recalledMemory: string[]
}): string {
  const domains = domainsForRequest(input.request)
  const primaryDomain = primaryDomainForRequest(input.request)
  const urgencyByDomain =
    domains.length > 0
      ? domains.map((domain) => `${domain}:${urgencyForDomain(input.request, domain)}`).join(", ")
      : "none"

  return [
    `User message: ${input.request.message}`,
    `Urgency: ${input.request.context.urgency}`,
    `Urgency by domain: ${urgencyByDomain}`,
    `Primary domain: ${primaryDomain ?? "none"}`,
    `Domains: ${domains.length > 0 ? domains.join(", ") : "none"}`,
    profileLine(input.profile),
    memoryLine(input.recalledMemory),
    "Return exactly 4 lines:",
    "1) Reality:",
    "2) Bottleneck:",
    "3) Execute now:",
    "4) Deadline:",
    "No filler. No praise. No corporate tone.",
  ].join("\n")
}

function buildAgentPrompt(input: {
  request: ChatRequest
  profile?: Profile
  recalledMemory: string[]
}): string {
  return [
    buildCoachPrompt(input),
    "If plan/protocol/tasks are requested, use tools first before final response.",
    "If user asks to create/update/complete tasks, use task tools first and then confirm exact change.",
  ].join("\n\n")
}

function buildProtocolPrompt(request: ChatRequest): string {
  const domains = domainsForRequest(request)
  const primaryDomain = primaryDomainForRequest(request)
  return [
    `User request: ${request.message}`,
    `Primary domain: ${primaryDomain ?? "general"}`,
    `Domains: ${domains.length > 0 ? domains.join(", ") : "none"}`,
    "Generate a realistic 14-day protocol.",
    "Steps must be executable and concrete.",
    "Avoid vague generic advice.",
  ].join("\n")
}

function heuristicMessage(input: {
  request: ChatRequest
  profile?: Profile
  recalledMemory: string[]
}): string {
  const primaryDomain = primaryDomainForRequest(input.request)
  const weakSignal = input.recalledMemory[0]
  const weakness = weakSignal
    ? weakSignal.slice(0, 120)
    : "No closed loop on your hardest execution task."

  return [
    `Reality: ${primaryDomain ? `${primaryDomain.toUpperCase()} needs immediate execution pressure.` : "Execution is not optional."}`,
    `Bottleneck: ${weakness}`,
    "Execute now: Lock one 45-minute block on your highest-priority task and start immediately.",
    "Deadline: Report completion or blocker in 60 minutes.",
  ].join("\n")
}

function shouldCreateProtocol(request: ChatRequest): boolean {
  const message = request.message.toLowerCase()
  const hasMentionedDomains = domainsForRequest(request).length > 0
  return (
    request.context.wantsProtocol ||
    hasMentionedDomains ||
    message.includes("protocol") ||
    message.includes("plan") ||
    message.includes("roadmap") ||
    message.includes("task") ||
    message.includes("maxx")
  )
}

function shouldHandleTaskOperation(request: ChatRequest): boolean {
  const message = request.message.toLowerCase()
  return (
    message.includes("create task") ||
    message.includes("add task") ||
    message.includes("new task") ||
    message.includes("complete task") ||
    message.includes("mark done") ||
    message.includes("finished") ||
    message.includes("reopen task") ||
    message.includes("approve draft") ||
    message.includes("reject draft") ||
    message.includes("archive task") ||
    message.includes("pause protocol") ||
    message.includes("pause maxx") ||
    message.includes("change goal") ||
    message.includes("change objective")
  )
}

type StreamReplyResult =
  | {
      mode: "stream"
      modelUsed: ModelName
      realityCheck: string
      textStream: AsyncIterable<string>
      suggestedProtocolPromise: Promise<ProtocolPlan | undefined>
    }
  | {
      mode: "fallback"
      modelUsed: ModelName
      realityCheck: string
      message: string
      suggestedProtocolPromise: Promise<ProtocolPlan | undefined>
    }

type AgentGeneratedReply = {
  message?: string
  suggestedProtocol?: ProtocolPlan
}

type CoachInput = {
  userId: string
  request: ChatRequest
  profile?: Profile
  recalledMemory: string[]
}

export class CoachService {
  constructor(private readonly memory: MemoryService) {}

  private canUseDistinctFallback(
    preferredModel: ModelName,
    fallbackModel: ModelName,
  ): boolean {
    if (preferredModel === fallbackModel) return false

    const preferred = resolveLanguageModel(preferredModel)
    const fallback = resolveLanguageModel(fallbackModel)

    if (!preferred.ok || !fallback.ok) return true

    return !(
      preferred.provider === fallback.provider &&
      preferred.modelId === fallback.modelId
    )
  }

  private mutationKey(prefix: string) {
    return `lock-chat:${prefix}:${crypto.randomUUID()}`
  }

  private taskQueryMatch(task: CoachingTask, query: string) {
    const normalized = query.trim().toLowerCase()
    if (!normalized) return false
    return `${task.title} ${task.subtitle}`.toLowerCase().includes(normalized)
  }

  private async resolveTaskByQuery(input: {
    userId: string
    query: string
    bucket: "active" | "draft" | "completed"
  }): Promise<CoachingTask | undefined> {
    const snapshot = await this.memory.getTaskSnapshot(input.userId)
    if (input.bucket === "active") {
      return snapshot.homeQueue.activeTasks.find((task) =>
        this.taskQueryMatch(task, input.query),
      )
    }

    if (input.bucket === "draft") {
      return snapshot.drafts.find((task) => this.taskQueryMatch(task, input.query))
    }

    return snapshot.allActive.find(
      (task) => task.isCompleted && this.taskQueryMatch(task, input.query),
    )
  }

  private taskOperationFallbackNote(input: CoachInput): string | undefined {
    if (!shouldHandleTaskOperation(input.request)) return undefined
    return "Task action failed. Reply with exact action (create|complete|reopen|approve|reject|archive|pause_domain|set_domain_goal) and task/domain details."
  }

  private profileWeakness(profile?: Profile): string | undefined {
    if (!profile) return undefined
    const payload = profile as Profile & Record<string, unknown>
    const weakness =
      typeof payload.biggestWeakness === "string" ? payload.biggestWeakness.trim() : ""
    return weakness || undefined
  }

  private hoursSince(iso?: string): number | null {
    if (!iso) return null
    const stamp = new Date(iso).getTime()
    if (!Number.isFinite(stamp)) return null
    return (Date.now() - stamp) / (1000 * 60 * 60)
  }

  private async buildRealityCheck(input: CoachInput): Promise<string> {
    const snapshot = await this.memory.getTaskSnapshot(input.userId)
    const active = snapshot.homeQueue.activeTasks
    const drafts = snapshot.drafts
    const latestCompleted = snapshot.homeQueue.latestCompleted
    const primaryDomain = primaryDomainForRequest(input.request)
    const highUrgencyDomain = domainsForRequest(input.request).find(
      (domain) => urgencyForDomain(input.request, domain) === "high",
    )

    if (highUrgencyDomain && !active.some((task) => task.domain === highUrgencyDomain)) {
      return `You marked ${highUrgencyDomain.toUpperCase()} as high urgency but have zero active ${highUrgencyDomain.toUpperCase()} tasks.`
    }

    if (active.length === 0 && drafts.length > 0) {
      return `You have ${drafts.length} draft tasks and zero active tasks. Decision avoidance is the bottleneck.`
    }

    if (active.length === 0) {
      return "You have no active tasks. No active plan means no measurable execution."
    }

    if (active.length > MAX_ACTIVE_TASKS_BEFORE_DILUTION) {
      return `You are carrying ${active.length} active tasks. Focus is diluted. Cut to top 3 today.`
    }

    const completionHours = this.hoursSince(latestCompleted?.completedAt ?? latestCompleted?.createdAt)
    if (completionHours === null || completionHours > STALE_COMPLETION_HOURS) {
      return "No completed-task signal in the last 72 hours. Intent without closure is noise."
    }

    const weakness = this.profileWeakness(input.profile)
    if (weakness) {
      return `Known weakness still unresolved: ${weakness}. Fix it before adding complexity.`
    }

    if (primaryDomain) {
      return `${primaryDomain.toUpperCase()} is the leverage domain right now. Do the hardest task first.`
    }

    return DEFAULT_REALITY_CHECK
  }

  private async generateMessageWithAlias(
    alias: ModelName,
    input: CoachInput,
  ): Promise<string | undefined> {
    const resolution = resolveLanguageModel(alias)
    if (!resolution.ok) return undefined

    const result = await generateText({
      model: resolution.model,
      system: COACH_SYSTEM_PROMPT,
      prompt: buildCoachPrompt(input),
    })

    const text = result.text.trim()
    if (!text) return undefined
    return text
  }

  private async generateProtocolWithAlias(
    alias: ModelName,
    request: ChatRequest,
  ): Promise<ProtocolPlan> {
    const resolution = resolveLanguageModel(alias)
    if (!resolution.ok) return buildProtocol(request)

    try {
      const result = await generateObject({
        model: resolution.model,
        schema: protocolPlanSchema,
        prompt: buildProtocolPrompt(request),
      })
      return result.object
    } catch {
      return buildProtocol(request)
    }
  }

  private createAgent(
    alias: ModelName,
    input: CoachInput,
  ): ToolLoopAgent<any, any, any> | null {
    const resolution = resolveLanguageModel(alias)
    if (!resolution.ok) return null

    const formatMutationResult = (result: {
      status: "created" | "ok" | "not_found" | "invalid_state" | "noop"
      idempotent: boolean
      task?: CoachingTask
    }) => ({
      status: result.status,
      idempotent: result.idempotent,
      task: result.task ? summarizeTaskForTool(result.task) : undefined,
      note:
        result.status === "created"
          ? "Task created."
          : result.status === "ok"
            ? "Task updated."
            : result.status === "noop"
              ? "No change needed."
              : result.status === "invalid_state"
                ? "Task is not in the required state for this action."
                : "Task not found.",
    })

    const tools = {
      get_profile_memory: tool({
        description:
          "Fetch current profile context and recalled memory so response is personalized.",
        inputSchema: z.object({}),
        outputSchema: z.object({
          profileContext: z.string(),
          recalledContext: z.string(),
        }),
        execute: async () => ({
          profileContext: profileLine(input.profile),
          recalledContext: memoryLine(input.recalledMemory),
        }),
      }),
      create_protocol: tool({
        description:
          "Create a structured 14-day protocol plan with objective, steps, and checkpoints.",
        inputSchema: z.object({
          domain: maxxDomainSchema.optional(),
        }),
        outputSchema: protocolPlanSchema,
        execute: async ({ domain }) => {
          const req: ChatRequest = {
            ...input.request,
            context: {
              ...input.request.context,
              wantsProtocol: true,
              domain: domain ?? input.request.context.domain,
            },
          }
          return this.generateProtocolWithAlias(alias, req)
        },
      }),
      create_maxx_tasks: tool({
        description:
          "Convert a protocol into a prioritized Maxx task list for execution.",
        inputSchema: z.object({
          protocol: protocolPlanSchema,
          domain: maxxDomainSchema.optional(),
        }),
        outputSchema: maxxTaskListSchema,
        execute: async ({ protocol, domain }) => ({
          tasks: protocol.steps.map((step, index) => ({
            title: step.title,
            subtitle: step.action,
            domain: domain ?? input.request.context.domain,
            estimate: step.frequency,
            priority: index + 1,
          })),
        }),
      }),
      pause_domain: tool({
        description:
          "Pause a Maxx domain by archiving active tasks and rejecting draft tasks for that domain.",
        inputSchema: z.object({
          domain: maxxDomainSchema.optional(),
        }),
        execute: async ({ domain }) => {
          const resolvedDomain =
            domain ?? primaryDomainForRequest(input.request) ?? input.request.context.domain
          if (!resolvedDomain) {
            return {
              domain: "mind",
              archivedActive: 0,
              rejectedDrafts: 0,
              note: "Domain required to pause protocol.",
            }
          }

          const snapshot = await this.memory.getTaskSnapshot(input.userId)
          const activeTasks = (snapshot.byDomain[resolvedDomain] ?? []).filter(
            (task) => task.state === "active",
          )
          const draftTasks = snapshot.drafts.filter(
            (task) => task.domain === resolvedDomain,
          )

          for (const task of activeTasks) {
            await this.memory.mutateTask({
              userId: input.userId,
              idempotencyKey: this.mutationKey(`pause-active-${resolvedDomain}`),
              action: "archive",
              taskId: task.id,
              actor: "lock",
            })
          }

          for (const task of draftTasks) {
            await this.memory.mutateTask({
              userId: input.userId,
              idempotencyKey: this.mutationKey(`pause-draft-${resolvedDomain}`),
              action: "reject_draft",
              taskId: task.id,
              actor: "lock",
            })
          }

          return {
            domain: resolvedDomain,
            archivedActive: activeTasks.length,
            rejectedDrafts: draftTasks.length,
            note:
              activeTasks.length === 0 && draftTasks.length === 0
                ? "Nothing to pause."
                : "Domain paused.",
          }
        },
      }),
      set_domain_goal: tool({
        description:
          "Update the domain objective context used by LOCK for future protocol detail.",
        inputSchema: z.object({
          objective: z.string().min(8),
          domain: maxxDomainSchema.optional(),
        }),
        execute: async ({ objective, domain }) => {
          const resolvedDomain =
            domain ?? primaryDomainForRequest(input.request) ?? input.request.context.domain
          if (!resolvedDomain) {
            return {
              note: "Domain required to update objective.",
            }
          }

          const profile = await this.memory.getProfile(input.userId)
          if (!profile) {
            return {
              note: "Profile missing. Complete onboarding first.",
            }
          }

          const payload = profile as Profile & Record<string, unknown>
          const existing =
            payload.maxxContextNotes && typeof payload.maxxContextNotes === "object"
              ? (payload.maxxContextNotes as Record<string, unknown>)
              : {}

          const nextNotes: Record<string, string> = {}
          for (const [key, raw] of Object.entries(existing)) {
            if (typeof raw === "string" && raw.trim().length > 0) {
              nextNotes[key] = raw.trim()
            }
          }
          nextNotes[resolvedDomain] = objective.trim()

          const updated = await this.memory.mergeProfile(input.userId, {
            maxxContextNotes: nextNotes,
          } as Partial<Profile>)

          return {
            domain: resolvedDomain,
            objective: objective.trim(),
            note: updated ? "Objective updated." : "Objective update failed.",
          }
        },
      }),
      list_tasks: tool({
        description:
          "List current active tasks, drafts, and latest completed task before making task decisions.",
        inputSchema: z.object({
          limit: z.number().int().min(1).max(20).optional(),
          includeDrafts: z.boolean().optional(),
        }),
        execute: async ({ limit, includeDrafts }) => {
          const snapshot = await this.memory.getTaskSnapshot(input.userId)
          const size = Math.min(Math.max(limit ?? 8, 1), 20)
          return {
            activeTasks: snapshot.homeQueue.activeTasks
              .slice(0, size)
              .map(summarizeTaskForTool),
            draftTasks:
              includeDrafts === false
                ? []
                : snapshot.drafts.slice(0, size).map(summarizeTaskForTool),
            latestCompleted: snapshot.homeQueue.latestCompleted
              ? summarizeTaskForTool(snapshot.homeQueue.latestCompleted)
              : undefined,
          }
        },
      }),
      create_task: tool({
        description:
          "Create a concrete execution task. Use this when user asks LOCK to add/create a task.",
        inputSchema: z.object({
          title: z.string().min(1),
          subtitle: z.string().min(1),
          domain: maxxDomainSchema.optional(),
          estimate: z.string().min(1).optional(),
          priority: z.number().int().min(1).max(1000).optional(),
          dueAt: z.string().datetime().optional(),
        }),
        execute: async ({ title, subtitle, domain, estimate, priority, dueAt }) => {
          const fallbackDomain =
            domain ?? primaryDomainForRequest(input.request) ?? input.request.context.domain ?? "mind"
          const result = await this.memory.mutateTask({
            userId: input.userId,
            idempotencyKey: this.mutationKey("create"),
            action: "create",
            domain: fallbackDomain,
            title,
            subtitle,
            estimate,
            priority,
            dueAt,
            source: "lock",
            actor: "lock",
          })

          return formatMutationResult(result)
        },
      }),
      complete_task: tool({
        description:
          "Mark an active task complete by taskId or by matching a query against active task titles.",
        inputSchema: z.object({
          taskId: z.string().uuid().optional(),
          query: z.string().min(2).optional(),
        }),
        execute: async ({ taskId, query }) => {
          const resolvedTaskId =
            taskId ??
            (query
              ? (await this.resolveTaskByQuery({
                  userId: input.userId,
                  query,
                  bucket: "active",
                }))?.id
              : undefined)

          if (!resolvedTaskId) {
            return {
              status: "not_found" as const,
              idempotent: false,
              note: "Task not found.",
            }
          }

          const result = await this.memory.mutateTask({
            userId: input.userId,
            idempotencyKey: this.mutationKey("complete"),
            action: "complete",
            taskId: resolvedTaskId,
            actor: "lock",
          })
          return formatMutationResult(result)
        },
      }),
      reopen_task: tool({
        description:
          "Reopen a completed task by taskId or by matching a query against completed tasks.",
        inputSchema: z.object({
          taskId: z.string().uuid().optional(),
          query: z.string().min(2).optional(),
        }),
        execute: async ({ taskId, query }) => {
          const resolvedTaskId =
            taskId ??
            (query
              ? (await this.resolveTaskByQuery({
                  userId: input.userId,
                  query,
                  bucket: "completed",
                }))?.id
              : undefined)

          if (!resolvedTaskId) {
            return {
              status: "not_found" as const,
              idempotent: false,
              note: "Task not found.",
            }
          }

          const result = await this.memory.mutateTask({
            userId: input.userId,
            idempotencyKey: this.mutationKey("reopen"),
            action: "reopen",
            taskId: resolvedTaskId,
            actor: "lock",
          })
          return formatMutationResult(result)
        },
      }),
      approve_draft_task: tool({
        description:
          "Approve a draft task and activate it. Use by taskId or draft query.",
        inputSchema: z.object({
          taskId: z.string().uuid().optional(),
          query: z.string().min(2).optional(),
        }),
        execute: async ({ taskId, query }) => {
          const resolvedTaskId =
            taskId ??
            (query
              ? (await this.resolveTaskByQuery({
                  userId: input.userId,
                  query,
                  bucket: "draft",
                }))?.id
              : undefined)

          if (!resolvedTaskId) {
            return {
              status: "not_found" as const,
              idempotent: false,
              note: "Task not found.",
            }
          }

          const result = await this.memory.mutateTask({
            userId: input.userId,
            idempotencyKey: this.mutationKey("approve"),
            action: "approve_draft",
            taskId: resolvedTaskId,
            actor: "lock",
          })
          return formatMutationResult(result)
        },
      }),
      reject_draft_task: tool({
        description:
          "Reject and archive a draft task. Use by taskId or draft query.",
        inputSchema: z.object({
          taskId: z.string().uuid().optional(),
          query: z.string().min(2).optional(),
        }),
        execute: async ({ taskId, query }) => {
          const resolvedTaskId =
            taskId ??
            (query
              ? (await this.resolveTaskByQuery({
                  userId: input.userId,
                  query,
                  bucket: "draft",
                }))?.id
              : undefined)

          if (!resolvedTaskId) {
            return {
              status: "not_found" as const,
              idempotent: false,
              note: "Task not found.",
            }
          }

          const result = await this.memory.mutateTask({
            userId: input.userId,
            idempotencyKey: this.mutationKey("reject"),
            action: "reject_draft",
            taskId: resolvedTaskId,
            actor: "lock",
          })
          return formatMutationResult(result)
        },
      }),
      archive_task: tool({
        description:
          "Archive a task by taskId or query. Use this only when user explicitly asks to archive.",
        inputSchema: z.object({
          taskId: z.string().uuid().optional(),
          query: z.string().min(2).optional(),
        }),
        execute: async ({ taskId, query }) => {
          const resolvedTaskId =
            taskId ??
            (query
              ? (await this.resolveTaskByQuery({
                  userId: input.userId,
                  query,
                  bucket: "active",
                }))?.id
              : undefined)

          if (!resolvedTaskId) {
            return {
              status: "not_found" as const,
              idempotent: false,
              note: "Task not found.",
            }
          }

          const result = await this.memory.mutateTask({
            userId: input.userId,
            idempotencyKey: this.mutationKey("archive"),
            action: "archive",
            taskId: resolvedTaskId,
            actor: "lock",
          })
          return formatMutationResult(result)
        },
      }),
    }

    return new ToolLoopAgent({
      model: resolution.model,
      instructions: AGENT_SYSTEM_PROMPT,
      tools,
      stopWhen: stepCountIs(aiConfig.lockAgentMaxSteps),
    })
  }

  private extractProtocolFromToolResults(results: unknown): ProtocolPlan | undefined {
    if (!Array.isArray(results)) return undefined

    for (const item of results) {
      if (!item || typeof item !== "object") continue
      const row = item as { toolName?: string; output?: unknown }
      if (row.toolName !== "create_protocol") continue
      const parsed = protocolPlanSchema.safeParse(row.output)
      if (parsed.success) return parsed.data
    }

    return undefined
  }

  private async generateAgentReply(
    alias: ModelName,
    input: CoachInput,
  ): Promise<AgentGeneratedReply> {
    const agent = this.createAgent(alias, input)
    if (!agent) return {}

    try {
      const result = await agent.generate({
        prompt: buildAgentPrompt(input),
        options: {},
      })

      const message = result.text.trim() || undefined
      const suggestedProtocol = this.extractProtocolFromToolResults(result.toolResults)

      return {
        message,
        suggestedProtocol,
      }
    } catch {
      return {}
    }
  }

  private withProtocolFallback(
    basePromise: Promise<ProtocolPlan | undefined>,
    alias: ModelName,
    request: ChatRequest,
  ): Promise<ProtocolPlan | undefined> {
    const needsProtocol = shouldCreateProtocol(request)
    return basePromise
      .then(async (protocol) => {
        if (protocol) return protocol
        if (!needsProtocol) return undefined
        return this.generateProtocolWithAlias(alias, request)
      })
      .catch(async () => {
        if (!needsProtocol) return undefined
        return this.generateProtocolWithAlias(alias, request)
      })
  }

  private async streamAgentReply(
    alias: ModelName,
    input: CoachInput,
  ): Promise<{
    textStream: AsyncIterable<string>
    suggestedProtocolPromise: Promise<ProtocolPlan | undefined>
  } | null> {
    const agent = this.createAgent(alias, input)
    if (!agent) return null

    try {
      const result = await agent.stream({
        prompt: buildAgentPrompt(input),
        options: {},
      })

      const protocolPromise = this.withProtocolFallback(
        Promise.resolve(result.toolResults).then((results) =>
          this.extractProtocolFromToolResults(results),
        ),
        alias,
        input.request,
      )

      return {
        textStream: result.textStream,
        suggestedProtocolPromise: protocolPromise,
      }
    } catch {
      return null
    }
  }

  async generateReply(input: {
    userId: string
    request: ChatRequest
    profile?: Profile
    recalledMemory: string[]
  }): Promise<CoachReply> {
    const preferredModel = chooseModelForChat(input.request)
    const fallbackModel = chooseFallbackModel(preferredModel)
    const canUseFallback = this.canUseDistinctFallback(preferredModel, fallbackModel)
    const realityCheck = await this.buildRealityCheck(input).catch(
      () => DEFAULT_REALITY_CHECK,
    )

    try {
      const preferredAgent = await this.generateAgentReply(preferredModel, input)
      let modelUsed: ModelName = preferredModel
      let message = preferredAgent.message
      let suggestedProtocol = preferredAgent.suggestedProtocol

      if (!message && canUseFallback) {
        const fallbackAgent = await this.generateAgentReply(fallbackModel, input)
        if (fallbackAgent.message) {
          message = fallbackAgent.message
          modelUsed = fallbackModel
        }
        if (!suggestedProtocol) {
          suggestedProtocol = fallbackAgent.suggestedProtocol
        }
      }

      if (!message) {
        const fallback = await this.generateMessageWithAlias(modelUsed, input)
        if (fallback) {
          message = fallback
        }
      }

      if (!message) {
        message = this.taskOperationFallbackNote(input)
      }

      if (!message) {
        message = heuristicMessage(input)
      }

      if (!suggestedProtocol && shouldCreateProtocol(input.request)) {
        suggestedProtocol = await this.generateProtocolWithAlias(modelUsed, input.request)
      }

      return {
        message,
        modelUsed,
        realityCheck,
        suggestedProtocol,
      }
    } catch {
      const taskFallbackMessage = this.taskOperationFallbackNote(input)
      return {
        message: taskFallbackMessage ?? heuristicMessage(input),
        modelUsed: fallbackModel,
        realityCheck,
        suggestedProtocol: shouldCreateProtocol(input.request)
          ? await this.generateProtocolWithAlias(fallbackModel, input.request)
          : undefined,
      }
    }
  }

  async streamReply(input: {
    userId: string
    request: ChatRequest
    profile?: Profile
    recalledMemory: string[]
  }): Promise<StreamReplyResult> {
    const preferredModel = chooseModelForChat(input.request)
    const fallbackModel = chooseFallbackModel(preferredModel)
    const canUseFallback = this.canUseDistinctFallback(preferredModel, fallbackModel)
    const realityCheck = await this.buildRealityCheck(input).catch(
      () => DEFAULT_REALITY_CHECK,
    )

    const preferredStream = await this.streamAgentReply(preferredModel, input)
    if (preferredStream) {
      return {
        mode: "stream",
        modelUsed: preferredModel,
        realityCheck,
        textStream: preferredStream.textStream,
        suggestedProtocolPromise: preferredStream.suggestedProtocolPromise,
      }
    }

    if (canUseFallback) {
      const fallbackStream = await this.streamAgentReply(fallbackModel, input)
      if (fallbackStream) {
        return {
          mode: "stream",
          modelUsed: fallbackModel,
          realityCheck,
          textStream: fallbackStream.textStream,
          suggestedProtocolPromise: fallbackStream.suggestedProtocolPromise,
        }
      }
    }

    return {
      mode: "fallback",
      modelUsed: fallbackModel,
      realityCheck,
      message:
        this.taskOperationFallbackNote(input) ??
        heuristicMessage(input),
      suggestedProtocolPromise: shouldCreateProtocol(input.request)
        ? this.generateProtocolWithAlias(fallbackModel, input.request)
        : Promise.resolve(undefined),
    }
  }
}
