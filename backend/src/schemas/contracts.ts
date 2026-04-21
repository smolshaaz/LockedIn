import { z } from "zod"
import { MAXX_DOMAINS } from "../types/domain"

export const maxxDomainSchema = z.enum(MAXX_DOMAINS)

const communicationStyleSchema = z.preprocess((value) => {
  if (typeof value !== "string") return value
  const normalized = value.trim().toLowerCase()
  if (normalized === "blunt") return "Blunt"
  if (normalized === "firm") return "Firm"
  if (normalized === "measured") return "Measured"
  if (normalized === "balanced") return "Firm"
  return value
}, z.enum(["Blunt", "Firm", "Measured"]))

const weeklyCheckinDaySchema = z.enum([
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
])

const hhmmTimeSchema = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)
const weightUnitSchema = z.enum(["kg", "lbs"])
const heightUnitSchema = z.enum(["cm", "ft-in"])

export const profileSchema = z.object({
  userId: z.string().min(1),
  name: z.string().min(1).max(120),
  age: z.number().int().min(13).max(100).optional(),
  goals: z.array(z.string().min(1)).min(1),
  constraints: z.array(z.string()).default([]),
  communicationStyle: communicationStyleSchema.default("Firm"),
  baseline: z.record(maxxDomainSchema, z.number().min(0).max(100)),
  weeklyCheckinDay: weeklyCheckinDaySchema.optional(),
  weeklyCheckinTime: hhmmTimeSchema.optional(),
  timezoneId: z.string().min(1).optional(),
  preferredWeightUnit: weightUnitSchema.optional(),
  preferredHeightUnit: heightUnitSchema.optional(),
  channelInAppEnabled: z.boolean().optional(),
  channelTelegramEnabled: z.boolean().optional(),
  channelDiscordEnabled: z.boolean().optional(),
  quietHoursEnabled: z.boolean().optional(),
  quietHoursStart: hhmmTimeSchema.optional(),
  quietHoursEnd: hhmmTimeSchema.optional(),
  googleConnected: z.boolean().optional(),
  telegramConnected: z.boolean().optional(),
  discordConnected: z.boolean().optional(),
}).passthrough()

export const updateProfileSchema = profileSchema
  .omit({ userId: true })
  .partial()
  .refine((value) => Object.keys(value).length > 0, {
    message: "At least one profile field must be provided",
  })

export const urgencySchema = z.enum(["low", "normal", "high"])

const urgencyByDomainSchema = z
  .object({
    gym: urgencySchema.optional(),
    face: urgencySchema.optional(),
    money: urgencySchema.optional(),
    mind: urgencySchema.optional(),
    social: urgencySchema.optional(),
  })
  .partial()

export const contextFlagsSchema = z.object({
  wantsProtocol: z.boolean().default(false),
  urgency: urgencySchema.default("normal"),
  domain: maxxDomainSchema.optional(),
  domains: z.array(maxxDomainSchema).min(1).max(MAXX_DOMAINS.length).optional(),
  urgencyByDomain: urgencyByDomainSchema.optional(),
})

export const protocolStepSchema = z.object({
  title: z.string().min(1),
  action: z.string().min(1),
  frequency: z.string().min(1),
  reason: z.string().min(1),
})

export const protocolPlanSchema = z.object({
  objective: z.string().min(1),
  horizonDays: z.number().int().min(1).max(90),
  steps: z.array(protocolStepSchema).min(1),
  checkpoints: z.array(z.string().min(1)).min(1),
})

export const taskRiskSchema = z.enum(["low", "medium", "high"])
export const taskStateSchema = z.enum(["draft", "active", "archived"])
export const taskEventActionSchema = z.enum([
  "created",
  "approved",
  "rejected",
  "activated",
  "archived",
  "completed",
  "reopened",
])

export const coachingTaskSchema = z.object({
  id: z.string().min(1),
  domain: maxxDomainSchema.optional(),
  title: z.string().min(1),
  subtitle: z.string().min(1),
  estimate: z.string().min(1).optional(),
  priority: z.number().int().min(0).max(10_000),
  risk: taskRiskSchema,
  state: taskStateSchema,
  source: z.enum(["lock", "manual"]),
  createdAt: z.string().datetime(),
  dueAt: z.string().datetime().optional(),
  isCompleted: z.boolean(),
  completedAt: z.string().datetime().optional(),
})

export const taskEventSchema = z.object({
  id: z.string().min(1),
  taskId: z.string().min(1),
  action: taskEventActionSchema,
  actor: z.enum(["user", "lock", "system"]),
  at: z.string().datetime(),
})

export const taskQueueSchema = z.object({
  latestCompleted: coachingTaskSchema.optional(),
  activeTasks: z.array(coachingTaskSchema),
})

export const taskDomainBucketsSchema = z.object({
  gym: z.array(coachingTaskSchema),
  face: z.array(coachingTaskSchema),
  money: z.array(coachingTaskSchema),
  mind: z.array(coachingTaskSchema),
  social: z.array(coachingTaskSchema),
})

export const taskSnapshotSchema = z.object({
  homeQueue: taskQueueSchema,
  byDomain: taskDomainBucketsSchema,
  allActive: z.array(coachingTaskSchema),
  drafts: z.array(coachingTaskSchema),
  unassigned: z.array(coachingTaskSchema),
})

export const taskSyncSchema = z.object({
  createdDrafts: z.array(coachingTaskSchema),
  autoActivated: z.array(coachingTaskSchema),
  trustScore: z.number().min(0).max(1),
})

export const coachReplySchema = z.object({
  message: z.string().min(1),
  modelUsed: z.enum(["sonnet", "haiku"]),
  realityCheck: z.string().min(1),
  suggestedProtocol: protocolPlanSchema.optional(),
  taskSync: taskSyncSchema.optional(),
})

export const chatRequestSchema = z.object({
  threadId: z.string().min(1),
  message: z.string().min(1),
  context: contextFlagsSchema.default({ wantsProtocol: false, urgency: "normal" }),
})

export const domainProgressSchema = z.object({
  domain: maxxDomainSchema,
  previousScore: z.number().min(0).max(100),
  newScore: z.number().min(0).max(100),
  delta: z.number(),
  note: z.string().min(1),
})

export const weeklyCheckinSchema = z.object({
  weekStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  entries: z
    .array(
      z.object({
        domain: maxxDomainSchema,
        score: z.number().min(0).max(100),
        notes: z.string().min(1),
      }),
    )
    .min(1),
})

export const lifeScoreBreakdownSchema = z.object({
  totalScore: z.number().min(0).max(100),
  domainScores: z.record(maxxDomainSchema, z.number().min(0).max(100)),
  weights: z.record(maxxDomainSchema, z.number().min(0).max(1)),
  contributions: z.record(maxxDomainSchema, z.number().min(0).max(100)),
  trend: z.array(
    z.object({
      weekStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      score: z.number().min(0).max(100),
    }),
  ),
})

export const taskEventRequestSchema = z.object({
  action: z.enum(["completed", "reopened"]),
})

export const taskDraftDecisionSchema = z.object({
  decision: z.enum(["approve", "reject"]),
})

export const taskMutationActionSchema = z.enum([
  "create",
  "complete",
  "reopen",
  "approve_draft",
  "reject_draft",
  "archive",
])

export const taskMutationRequestSchema = z
  .object({
    idempotencyKey: z.string().min(8).max(128),
    action: taskMutationActionSchema,
    taskId: z.string().uuid().optional(),
    domain: maxxDomainSchema.optional(),
    title: z.string().min(1).max(160).optional(),
    subtitle: z.string().min(1).max(280).optional(),
    estimate: z.string().min(1).max(80).optional(),
    priority: z.number().int().min(0).max(10_000).optional(),
    dueAt: z.string().datetime().optional(),
    source: z.enum(["lock", "manual"]).optional(),
    actor: z.enum(["user", "lock", "system"]).optional(),
  })
  .superRefine((value, ctx) => {
    const needsTaskId = value.action !== "create"

    if (needsTaskId && !value.taskId) {
      ctx.addIssue({
        code: "custom",
        path: ["taskId"],
        message: "taskId is required for this action",
      })
    }

    if (value.action === "create") {
      if (!value.title) {
        ctx.addIssue({
          code: "custom",
          path: ["title"],
          message: "title is required for create",
        })
      }

      if (!value.subtitle) {
        ctx.addIssue({
          code: "custom",
          path: ["subtitle"],
          message: "subtitle is required for create",
        })
      }

      if (!value.domain) {
        ctx.addIssue({
          code: "custom",
          path: ["domain"],
          message: "domain is required for create",
        })
      }
    }
  })

export type Profile = z.infer<typeof profileSchema>
export type UpdateProfile = z.infer<typeof updateProfileSchema>
export type ChatRequest = z.infer<typeof chatRequestSchema>
export type CoachReply = z.infer<typeof coachReplySchema>
export type ProtocolPlan = z.infer<typeof protocolPlanSchema>
export type WeeklyCheckin = z.infer<typeof weeklyCheckinSchema>
export type DomainProgress = z.infer<typeof domainProgressSchema>
export type LifeScoreBreakdown = z.infer<typeof lifeScoreBreakdownSchema>
export type CoachingTask = z.infer<typeof coachingTaskSchema>
export type TaskRisk = z.infer<typeof taskRiskSchema>
export type TaskState = z.infer<typeof taskStateSchema>
export type TaskEvent = z.infer<typeof taskEventSchema>
export type TaskEventAction = z.infer<typeof taskEventActionSchema>
export type TaskQueue = z.infer<typeof taskQueueSchema>
export type TaskSnapshot = z.infer<typeof taskSnapshotSchema>
export type TaskSync = z.infer<typeof taskSyncSchema>
export type TaskMutationRequest = z.infer<typeof taskMutationRequestSchema>
export type TaskMutationAction = z.infer<typeof taskMutationActionSchema>
