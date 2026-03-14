import { z } from "zod"
import { MAXX_DOMAINS } from "../types/domain"

export const maxxDomainSchema = z.enum(MAXX_DOMAINS)

export const profileSchema = z.object({
  userId: z.string().min(1),
  name: z.string().min(1).max(120),
  age: z.number().int().min(13).max(100).optional(),
  goals: z.array(z.string().min(1)).min(1),
  constraints: z.array(z.string()).default([]),
  communicationStyle: z.enum(["blunt", "balanced"]).default("blunt"),
  baseline: z.record(maxxDomainSchema, z.number().min(0).max(100)),
})

export const updateProfileSchema = profileSchema
  .omit({ userId: true })
  .partial()
  .refine((value) => Object.keys(value).length > 0, {
    message: "At least one profile field must be provided",
  })

export const contextFlagsSchema = z.object({
  wantsProtocol: z.boolean().default(false),
  urgency: z.enum(["low", "normal", "high"]).default("normal"),
  domain: maxxDomainSchema.optional(),
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

export const coachReplySchema = z.object({
  message: z.string().min(1),
  modelUsed: z.enum(["sonnet", "haiku"]),
  realityCheck: z.string().min(1),
  suggestedProtocol: protocolPlanSchema.optional(),
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

export type Profile = z.infer<typeof profileSchema>
export type UpdateProfile = z.infer<typeof updateProfileSchema>
export type ChatRequest = z.infer<typeof chatRequestSchema>
export type CoachReply = z.infer<typeof coachReplySchema>
export type ProtocolPlan = z.infer<typeof protocolPlanSchema>
export type WeeklyCheckin = z.infer<typeof weeklyCheckinSchema>
export type DomainProgress = z.infer<typeof domainProgressSchema>
export type LifeScoreBreakdown = z.infer<typeof lifeScoreBreakdownSchema>
