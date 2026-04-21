import { embed } from "ai"
import type {
  ChatRequest,
  CoachingTask,
  Profile,
  ProtocolPlan,
  TaskEvent,
  TaskEventAction,
  TaskMutationAction,
  TaskQueue,
  TaskSnapshot,
  TaskRisk,
  TaskState,
  WeeklyCheckin,
} from "../schemas/contracts"
import { env } from "../config/env"
import { resolveEmbeddingModel } from "../integrations/ai-models"
import { getSupabaseAdminClient } from "../integrations/supabase-client"
import { MAXX_DOMAINS, type DomainScores, type MaxxDomain } from "../types/domain"
import {
  PersistenceMirrorService,
  type PersistedTask,
} from "./persistence-mirror-service"
import { domainsForRequest } from "./chat-context"

type ChatTurn = {
  role: "user" | "assistant"
  content: string
  at: string
}

type EpisodicMemory = {
  id: string
  summary: string
  tags: string[]
  embedding: number[]
  createdAt: string
}

type StoredTask = Omit<CoachingTask, "isCompleted" | "completedAt">

type UserMemory = {
  profile?: Profile
  domainScores: DomainScores
  weeklySummaries: Array<{ weekStart: string; summary: string }>
  checkins: WeeklyCheckin[]
  lifeScoreSnapshots: Array<{ weekStart: string; score: number }>
  threadTurns: Record<string, ChatTurn[]>
  threadState: Record<string, { lastMessageAt: string; messageCount: number }>
  episodicMemories: EpisodicMemory[]
  tasks: Record<string, StoredTask>
  taskEvents: TaskEvent[]
  trustSignals: {
    approved: number
    rejected: number
  }
}

type TaskMutationStatus = "created" | "ok" | "not_found" | "invalid_state" | "noop"

type TaskMutationResult = {
  status: TaskMutationStatus
  idempotent: boolean
  task?: CoachingTask
  snapshot: TaskSnapshot
}

type StoredTaskMutationResult = {
  status: TaskMutationStatus
  task?: CoachingTask
}

const MAX_THREAD_TURNS = 40
const MAX_EPISODIC_MEMORY = 300
const MAX_WEEKLY_SUMMARIES = 20
const MAX_LIFESCORE_SNAPSHOTS = 52
const MAX_TASK_MUTATION_CACHE = 5000

function nowISO() {
  return new Date().toISOString()
}

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value
  if (typeof value === "string") {
    const parsed = Number(value)
    if (Number.isFinite(parsed)) return parsed
  }
  return fallback
}

function defaultScores(): DomainScores {
  return {
    gym: 50,
    face: 50,
    money: 50,
    mind: 50,
    social: 50,
  }
}

function tokenize(input: string): string[] {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((token) => token.length > 1)
}

function inferTaskRisk(step: ProtocolPlan["steps"][number]): TaskRisk {
  const text = `${step.title} ${step.action} ${step.reason}`.toLowerCase()

  if (text.includes("non-negotiable") || text.includes("hard") || text.includes("deadline")) {
    return "medium"
  }

  if (text.includes("weekly") || text.includes("audit") || text.includes("review")) {
    return "low"
  }

  return "low"
}

function inferDomainFromText(text: string): MaxxDomain | undefined {
  const normalized = text.toLowerCase()

  if (/gym|workout|bench|squat|protein|training|cardio/.test(normalized)) return "gym"
  if (/skin|face|spf|jaw|groom|acne|hydration/.test(normalized)) return "face"
  if (/money|income|job|internship|application|pipeline|portfolio/.test(normalized)) return "money"
  if (/social|confidence|approach|conversation|network|follow-up/.test(normalized)) return "social"
  if (/mind|focus|sleep|deep work|discipline|attention|mental/.test(normalized)) return "mind"
  return undefined
}

function inferDomainFromPlan(plan: ProtocolPlan): MaxxDomain {
  const corpus = [
    plan.objective,
    ...plan.steps.map((step) => `${step.title} ${step.action} ${step.reason}`),
    ...plan.checkpoints,
  ].join(" ")

  return inferDomainFromText(corpus) ?? "mind"
}

function normalizeTaskDomain(
  rawDomain: unknown,
  title: string,
  subtitle: string,
): MaxxDomain | undefined {
  if (typeof rawDomain === "string") {
    const normalized = rawDomain.trim().toLowerCase()
    if (MAXX_DOMAINS.includes(normalized as MaxxDomain)) {
      return normalized as MaxxDomain
    }
  }

  return inferDomainFromText(`${title} ${subtitle}`)
}

function deterministicEmbeddingFor(text: string, size = env.EMBEDDING_DIMENSIONS): number[] {
  const buckets = new Array(size).fill(0)
  for (let i = 0; i < text.length; i++) {
    buckets[i % size] += text.charCodeAt(i)
  }

  const magnitude = Math.sqrt(buckets.reduce((sum, value) => sum + value * value, 0)) || 1
  return buckets.map((value) => Number((value / magnitude).toFixed(6)))
}

function normalizeEmbedding(vector: number[], size = env.EMBEDDING_DIMENSIONS): number[] {
  if (vector.length === size) {
    return vector.map((value) => Number(value.toFixed(6)))
  }

  if (vector.length > size) {
    return vector.slice(0, size).map((value) => Number(value.toFixed(6)))
  }

  const padded = [...vector]
  while (padded.length < size) {
    padded.push(0)
  }
  return padded.map((value) => Number(value.toFixed(6)))
}

async function embeddingFor(text: string, size = env.EMBEDDING_DIMENSIONS): Promise<number[]> {
  const resolved = resolveEmbeddingModel()
  if (!resolved.ok) {
    return deterministicEmbeddingFor(text, size)
  }

  try {
    const result = await embed({
      model: resolved.model,
      value: text,
    })
    return normalizeEmbedding(result.embedding, size)
  } catch (error) {
    console.error(
      `[memory] embedding failed: ${error instanceof Error ? error.message : "unknown error"}`,
    )
    return deterministicEmbeddingFor(text, size)
  }
}

function cosineSimilarity(a: number[], b: number[]): number {
  const limit = Math.min(a.length, b.length)
  if (limit === 0) return 0

  let dot = 0
  let magA = 0
  let magB = 0

  for (let i = 0; i < limit; i++) {
    dot += a[i] * b[i]
    magA += a[i] * a[i]
    magB += b[i] * b[i]
  }

  const denom = Math.sqrt(magA) * Math.sqrt(magB)
  if (!Number.isFinite(denom) || denom === 0) return 0
  return dot / denom
}

function fromDbScores(row: Record<string, unknown> | null | undefined): DomainScores {
  if (!row) return defaultScores()
  return {
    gym: asNumber(row.gym, 50),
    face: asNumber(row.face, 50),
    money: asNumber(row.money, 50),
    mind: asNumber(row.mind, 50),
    social: asNumber(row.social, 50),
  }
}

function normalizeCommunicationStyle(value: unknown): "Blunt" | "Firm" | "Measured" {
  if (typeof value !== "string") return "Firm"
  const normalized = value.trim().toLowerCase()
  if (normalized === "blunt") return "Blunt"
  if (normalized === "measured") return "Measured"
  if (normalized === "firm") return "Firm"
  if (normalized === "balanced") return "Firm"
  return "Firm"
}

export class MemoryService {
  private readonly store = new Map<string, UserMemory>()
  private readonly persistence = new PersistenceMirrorService()
  private readonly taskMutationCache = new Map<string, StoredTaskMutationResult>()

  private ensureUser(userId: string): UserMemory {
    if (!this.store.has(userId)) {
      this.store.set(userId, {
        domainScores: defaultScores(),
        weeklySummaries: [],
        checkins: [],
        lifeScoreSnapshots: [],
        threadTurns: {},
        threadState: {},
        episodicMemories: [],
        tasks: {},
        taskEvents: [],
        trustSignals: {
          approved: 0,
          rejected: 0,
        },
      })
    }

    return this.store.get(userId) as UserMemory
  }

  private client() {
    return getSupabaseAdminClient()
  }

  private mutationCacheKey(userId: string, idempotencyKey: string): string {
    return `${userId}:${idempotencyKey}`
  }

  private rememberTaskMutation(cacheKey: string, result: StoredTaskMutationResult) {
    this.taskMutationCache.set(cacheKey, result)

    if (this.taskMutationCache.size <= MAX_TASK_MUTATION_CACHE) {
      return
    }

    const oldestKey = this.taskMutationCache.keys().next().value
    if (oldestKey) {
      this.taskMutationCache.delete(oldestKey)
    }
  }

  private bumpTrustSignal(memory: UserMemory, action: TaskMutationAction) {
    if (action === "approve_draft") {
      memory.trustSignals.approved += 1
    } else if (action === "reject_draft") {
      memory.trustSignals.rejected += 1
    }
  }

  private taskCompletionState(memory: UserMemory, taskId: string) {
    let isCompleted = false
    let completedAt: string | undefined

    for (const event of memory.taskEvents) {
      if (event.taskId !== taskId) continue
      if (event.action === "completed") {
        isCompleted = true
        completedAt = event.at
      }
      if (event.action === "reopened") {
        isCompleted = false
        completedAt = undefined
      }
    }

    return { isCompleted, completedAt }
  }

  private projectTask(memory: UserMemory, task: StoredTask): CoachingTask {
    const completion = this.taskCompletionState(memory, task.id)
    return {
      ...task,
      ...completion,
    }
  }

  private toPersistedTask(task: CoachingTask): PersistedTask {
    return {
      id: task.id,
      domain: task.domain,
      title: task.title,
      subtitle: task.subtitle,
      estimate: task.estimate,
      priority: task.priority,
      risk: task.risk,
      state: task.state,
      source: task.source,
      createdAt: task.createdAt,
      dueAt: task.dueAt,
      isCompleted: task.isCompleted,
      completedAt: task.completedAt,
    }
  }

  private fromDbTask(row: Record<string, unknown>): CoachingTask {
    const title = String(row.title)
    const subtitle = String(row.subtitle)
    const domain = normalizeTaskDomain(row.domain, title, subtitle)

    return {
      id: String(row.id),
      domain,
      title,
      subtitle,
      estimate: row.estimate ? String(row.estimate) : undefined,
      priority: asNumber(row.priority, 100),
      risk: (String(row.risk) as TaskRisk) ?? "low",
      state: (String(row.state) as TaskState) ?? "draft",
      source: (String(row.source) as "lock" | "manual") ?? "lock",
      createdAt: String(row.created_at ?? nowISO()),
      dueAt: row.due_at ? String(row.due_at) : undefined,
      isCompleted: Boolean(row.is_completed),
      completedAt: row.completed_at ? String(row.completed_at) : undefined,
    }
  }

  private hydrateTaskToLocal(memory: UserMemory, task: CoachingTask) {
    memory.tasks[task.id] = {
      id: task.id,
      domain: task.domain,
      title: task.title,
      subtitle: task.subtitle,
      estimate: task.estimate,
      priority: task.priority,
      risk: task.risk,
      state: task.state,
      source: task.source,
      createdAt: task.createdAt,
      dueAt: task.dueAt,
    }
  }

  private async appendTaskEvent(
    userId: string,
    memory: UserMemory,
    input: Omit<TaskEvent, "id" | "at">,
  ): Promise<TaskEvent> {
    const event: TaskEvent = {
      id: crypto.randomUUID(),
      at: nowISO(),
      ...input,
    }
    memory.taskEvents.push(event)
    await this.persistence.mirrorTaskEvent(userId, event)
    return event
  }

  private async mirrorTaskState(userId: string, memory: UserMemory, task: StoredTask) {
    const projected = this.projectTask(memory, task)
    await this.persistence.mirrorTask(userId, this.toPersistedTask(projected))
  }

  private async trustScoreFromDb(userId: string): Promise<number | null> {
    const client = this.client()
    if (!client) return null

    const { data, error } = await client
      .from("task_events")
      .select("action")
      .eq("user_id", userId)
      .in("action", ["approved", "rejected"])

    if (error) {
      console.error(`[memory] trust score query failed: ${error.message}`)
      return null
    }

    const approved = (data ?? []).filter((row) => row.action === "approved").length
    const rejected = (data ?? []).filter((row) => row.action === "rejected").length
    const total = approved + rejected
    if (total < 3) return 0
    return Number((approved / total).toFixed(2))
  }

  private trustScoreFromMemory(memory: UserMemory): number {
    const { approved, rejected } = memory.trustSignals
    const total = approved + rejected
    if (total < 3) return 0
    return Number((approved / total).toFixed(2))
  }

  private shouldAutoActivate(trustScore: number, risk: TaskRisk): boolean {
    if (risk === "high") return false
    if (risk === "medium") return trustScore >= 0.9
    return trustScore >= 0.75
  }

  private async archiveExistingLockTasks(
    userId: string,
    memory: UserMemory,
    domain?: MaxxDomain,
  ): Promise<void> {
    const client = this.client()

    if (client) {
      let query = client
        .from("coaching_tasks")
        .select("*")
        .eq("user_id", userId)
        .eq("source", "lock")
        .neq("state", "archived")

      if (domain) {
        query = query.eq("domain", domain)
      }

      const { data, error } = await query
      if (error) {
        console.error(`[memory] fetch tasks for archive failed: ${error.message}`)
      } else {
        for (const row of data ?? []) {
          const task = this.fromDbTask(row as unknown as Record<string, unknown>)
          this.hydrateTaskToLocal(memory, task)
          memory.tasks[task.id].state = "archived"
          await this.appendTaskEvent(userId, memory, {
            taskId: task.id,
            action: "archived",
            actor: "system",
          })
          await this.mirrorTaskState(userId, memory, memory.tasks[task.id])
        }
      }
    }

    for (const task of Object.values(memory.tasks)) {
      if (task.source !== "lock") continue
      if (task.state === "archived") continue
      if (domain && task.domain !== domain) continue

      task.state = "archived"
      await this.appendTaskEvent(userId, memory, {
        taskId: task.id,
        action: "archived",
        actor: "system",
      })
      await this.mirrorTaskState(userId, memory, task)
    }
  }

  async getProfile(userId: string): Promise<Profile | undefined> {
    const memory = this.ensureUser(userId)
    const client = this.client()
    if (client) {
      const { data, error } = await client
        .from("profiles")
        .select("*")
        .eq("user_id", userId)
        .maybeSingle()

      if (error) {
        console.error(`[memory] profile read failed: ${error.message}`)
      } else if (data) {
        const baselineRaw = (data.baseline_scores ?? {}) as Record<string, unknown>
        const onboardingPayload =
          data.onboarding_payload && typeof data.onboarding_payload === "object"
            ? (data.onboarding_payload as Record<string, unknown>)
            : {}
        const baseline: DomainScores = {
          gym: asNumber(baselineRaw.gym, 50),
          face: asNumber(baselineRaw.face, 50),
          money: asNumber(baselineRaw.money, 50),
          mind: asNumber(baselineRaw.mind, 50),
          social: asNumber(baselineRaw.social, 50),
        }

        const profile: Profile = {
          ...onboardingPayload,
          userId: data.user_id,
          name: data.name,
          age: data.age ?? undefined,
          goals: Array.isArray(data.goals) ? data.goals : [],
          constraints: Array.isArray(data.constraints) ? data.constraints : [],
          communicationStyle: normalizeCommunicationStyle(data.communication_style),
          baseline,
        }

        memory.profile = profile
        memory.domainScores = baseline
        return profile
      }
    }

    return memory.profile
  }

  async setProfile(userId: string, profile: Profile): Promise<Profile> {
    const memory = this.ensureUser(userId)
    memory.profile = profile
    memory.domainScores = profile.baseline
    await this.persistence.mirrorProfile(profile)
    await this.persistence.mirrorDomainScores(userId, memory.domainScores)
    return profile
  }

  async mergeProfile(userId: string, patch: Partial<Profile>): Promise<Profile | undefined> {
    const existing = await this.getProfile(userId)
    if (!existing) return undefined

    const updated: Profile = {
      ...existing,
      ...patch,
      baseline: {
        ...existing.baseline,
        ...patch.baseline,
      },
      userId,
    }

    await this.setProfile(userId, updated)
    return updated
  }

  async exportUserData(userId: string) {
    const memory = this.ensureUser(userId)
    const profile = await this.getProfile(userId)
    const domainScores = await this.getDomainScores(userId)
    const client = this.client()

    if (client) {
      const [checkinsResult, snapshotsResult, tasksResult, eventsResult] = await Promise.all([
        client
          .from("weekly_checkins")
          .select("week_start,entries")
          .eq("user_id", userId)
          .order("week_start", { ascending: false }),
        client
          .from("lifescore_snapshots")
          .select("week_start,total_score")
          .eq("user_id", userId)
          .order("week_start", { ascending: false }),
        client
          .from("coaching_tasks")
          .select("*")
          .eq("user_id", userId)
          .order("created_at", { ascending: false }),
        client
          .from("task_events")
          .select("*")
          .eq("user_id", userId)
          .order("at", { ascending: false }),
      ])

      const weeklyCheckins = !checkinsResult.error
        ? (checkinsResult.data ?? []).map((row) => ({
            weekStart: String(row.week_start),
            entries: Array.isArray(row.entries) ? row.entries : [],
          }))
        : memory.checkins

      const lifeScoreSnapshots = !snapshotsResult.error
        ? (snapshotsResult.data ?? []).map((row) => ({
            weekStart: String(row.week_start),
            score: asNumber(row.total_score),
          }))
        : memory.lifeScoreSnapshots

      const coachingTasks = !tasksResult.error
        ? (tasksResult.data ?? []).map((row) =>
            this.fromDbTask(row as unknown as Record<string, unknown>),
          )
        : Object.values(memory.tasks).map((task) => this.projectTask(memory, task))

      const taskEvents = !eventsResult.error
        ? (eventsResult.data ?? []).map((row) => ({
            id: String(row.id),
            taskId: String(row.task_id),
            action: String(row.action) as TaskEventAction,
            actor: String(row.actor) as "user" | "lock" | "system",
            at: String(row.at),
          }))
        : memory.taskEvents

      return {
        exportedAt: nowISO(),
        userId,
        profile: profile ?? null,
        domainScores,
        weeklyCheckins,
        lifeScoreSnapshots,
        coachingTasks,
        taskEvents,
        threadState: memory.threadState,
      }
    }

    return {
      exportedAt: nowISO(),
      userId,
      profile: profile ?? null,
      domainScores,
      weeklyCheckins: memory.checkins,
      lifeScoreSnapshots: memory.lifeScoreSnapshots,
      coachingTasks: Object.values(memory.tasks).map((task) => this.projectTask(memory, task)),
      taskEvents: memory.taskEvents,
      threadState: memory.threadState,
    }
  }

  async deleteUserData(userId: string) {
    const client = this.client()
    if (client) {
      const deleteFrom = async (table: string) => {
        const { error } = await client.from(table).delete().eq("user_id", userId)
        if (error) throw new Error(`${table}: ${error.message}`)
      }

      await deleteFrom("task_events")
      await deleteFrom("coaching_tasks")
      await deleteFrom("episodic_memories")
      await deleteFrom("weekly_checkins")
      await deleteFrom("lifescore_snapshots")
      await deleteFrom("domain_scores_current")
      await deleteFrom("profiles")
    }

    this.store.delete(userId)
  }

  async getDomainScores(userId: string): Promise<DomainScores> {
    const memory = this.ensureUser(userId)
    const client = this.client()
    if (client) {
      const { data, error } = await client
        .from("domain_scores_current")
        .select("gym,face,money,mind,social")
        .eq("user_id", userId)
        .maybeSingle()

      if (error) {
        console.error(`[memory] domain scores read failed: ${error.message}`)
      } else if (data) {
        const scores = fromDbScores(data as unknown as Record<string, unknown>)
        memory.domainScores = scores
        return scores
      }
    }

    return memory.domainScores
  }

  async ingestCheckin(userId: string, checkin: WeeklyCheckin) {
    const memory = this.ensureUser(userId)
    memory.checkins.unshift(checkin)
    memory.checkins = memory.checkins.slice(0, MAX_WEEKLY_SUMMARIES)

    for (const entry of checkin.entries) {
      memory.domainScores[entry.domain] = entry.score
    }

    const summary = checkin.entries
      .map((entry) => `${entry.domain.toUpperCase()} ${entry.score}: ${entry.notes}`)
      .join(" | ")

    memory.weeklySummaries.unshift({
      weekStart: checkin.weekStart,
      summary,
    })
    memory.weeklySummaries = memory.weeklySummaries.slice(0, MAX_WEEKLY_SUMMARIES)

    await this.persistence.mirrorWeeklyCheckin(userId, checkin, summary)
    await this.persistence.mirrorDomainScores(userId, memory.domainScores)
    await this.storeEpisodicSummary(
      userId,
      `Weekly check-in ${checkin.weekStart}. ${summary}`,
      checkin.entries.map((entry) => entry.domain),
    )

    return {
      updatedScores: memory.domainScores,
      summary,
    }
  }

  async recordLifeScoreSnapshot(userId: string, weekStart: string, score: number) {
    const memory = this.ensureUser(userId)
    const existingIndex = memory.lifeScoreSnapshots.findIndex((item) => item.weekStart === weekStart)
    const value = Number(score.toFixed(2))

    if (existingIndex >= 0) {
      memory.lifeScoreSnapshots[existingIndex] = { weekStart, score: value }
    } else {
      memory.lifeScoreSnapshots.unshift({ weekStart, score: value })
    }

    memory.lifeScoreSnapshots.sort((a, b) => (a.weekStart > b.weekStart ? -1 : 1))
    memory.lifeScoreSnapshots = memory.lifeScoreSnapshots.slice(0, MAX_LIFESCORE_SNAPSHOTS)
    await this.persistence.mirrorLifeScoreSnapshot(userId, weekStart, value)
  }

  async recentTrend(userId: string) {
    const memory = this.ensureUser(userId)
    const client = this.client()
    if (client) {
      const { data, error } = await client
        .from("lifescore_snapshots")
        .select("week_start,total_score")
        .eq("user_id", userId)
        .order("week_start", { ascending: false })
        .limit(MAX_LIFESCORE_SNAPSHOTS)

      if (error) {
        console.error(`[memory] trend read failed: ${error.message}`)
      } else if (data && data.length > 0) {
        return data.map((snapshot) => ({
          weekStart: String(snapshot.week_start),
          score: asNumber(snapshot.total_score),
        }))
      }
    }

    return memory.lifeScoreSnapshots.map((snapshot) => ({
      weekStart: snapshot.weekStart,
      score: snapshot.score,
    }))
  }

  async getDomainScoreHistory(
    userId: string,
    domain: MaxxDomain,
    limit = 12,
  ): Promise<Array<{ weekStart: string; score: number }>> {
    const memory = this.ensureUser(userId)
    const safeLimit = Math.min(Math.max(limit, 1), 52)
    const client = this.client()

    if (client) {
      const { data, error } = await client
        .from("weekly_checkins")
        .select("week_start,entries")
        .eq("user_id", userId)
        .order("week_start", { ascending: false })
        .limit(safeLimit)

      if (!error && data) {
        const points = (data ?? [])
          .map((row) => {
            const entries = Array.isArray(row.entries) ? row.entries : []
            const match = entries.find((entry) => {
              if (!entry || typeof entry !== "object") return false
              const candidate = entry as Record<string, unknown>
              return candidate.domain === domain
            }) as Record<string, unknown> | undefined

            if (!match) return null
            return {
              weekStart: String(row.week_start),
              score: asNumber(match.score, 0),
            }
          })
          .filter((point): point is { weekStart: string; score: number } => point !== null)
          .sort((left, right) => left.weekStart.localeCompare(right.weekStart))

        return points
      }
    }

    return memory.checkins
      .slice(0, safeLimit)
      .map((checkin) => {
        const entry = checkin.entries.find((item) => item.domain === domain)
        if (!entry) return null
        return {
          weekStart: checkin.weekStart,
          score: entry.score,
        }
      })
      .filter((point): point is { weekStart: string; score: number } => point !== null)
      .sort((left, right) => left.weekStart.localeCompare(right.weekStart))
  }

  async appendChatTurn(userId: string, request: ChatRequest, replyMessage: string) {
    const memory = this.ensureUser(userId)
    const turns = memory.threadTurns[request.threadId] ?? []

    const now = nowISO()
    turns.push({ role: "user", content: request.message, at: now })
    turns.push({ role: "assistant", content: replyMessage, at: nowISO() })
    memory.threadTurns[request.threadId] = turns.slice(-MAX_THREAD_TURNS)

    memory.threadState[request.threadId] = {
      lastMessageAt: nowISO(),
      messageCount: (memory.threadState[request.threadId]?.messageCount ?? 0) + 1,
    }

    const tags = ["chat", request.threadId]
    for (const domain of domainsForRequest(request)) {
      tags.push(domain)
    }

    await this.storeEpisodicSummary(
      userId,
      `User: ${request.message} | LOCK: ${replyMessage}`,
      tags,
    )
  }

  async storeEpisodicSummary(userId: string, summary: string, tags: string[] = []) {
    const memory = this.ensureUser(userId)
    const trimmed = summary.trim()
    if (!trimmed) return

    const record: EpisodicMemory = {
      id: crypto.randomUUID(),
      summary: trimmed,
      tags,
      embedding: await embeddingFor(trimmed),
      createdAt: nowISO(),
    }

    memory.episodicMemories.push(record)
    memory.episodicMemories = memory.episodicMemories.slice(-MAX_EPISODIC_MEMORY)

    await this.persistence.mirrorEpisodicMemory({
      userId,
      summary: record.summary,
      tags: record.tags,
      embedding: record.embedding,
      createdAt: record.createdAt,
    })
  }

  private localRecall(
    memory: UserMemory,
    query: string,
    queryEmbedding: number[],
    limit: number,
  ): string[] {
    const ranked = memory.episodicMemories
      .map((item) => {
        const memoryTokens = new Set(tokenize(`${item.summary} ${item.tags.join(" ")}`))
        const queryTokens = tokenize(query)
        let overlap = 0
        for (const token of queryTokens) {
          if (memoryTokens.has(token)) overlap += 1
        }
        const lexicalScore = queryTokens.length === 0 ? 0 : overlap / queryTokens.length
        const vectorScore = cosineSimilarity(item.embedding, queryEmbedding)
        return {
          summary: item.summary,
          score: lexicalScore * 0.65 + vectorScore * 0.35,
          createdAt: item.createdAt,
        }
      })
      .filter((item) => item.score > 0.1)
      .sort((left, right) => {
        if (right.score !== left.score) return right.score - left.score
        return right.createdAt.localeCompare(left.createdAt)
      })
      .slice(0, limit)

    return ranked.map((item) => item.summary)
  }

  async recall(userId: string, query: string, limit = 3): Promise<string[]> {
    const memory = this.ensureUser(userId)
    if (!query.trim()) return []
    const queryEmbedding = await embeddingFor(query)

    const client = this.client()
    if (client) {
      const { data, error } = await client.rpc("match_episodic_memories", {
        p_user_id: userId,
        p_query_embedding: queryEmbedding,
        p_match_count: limit,
        p_min_similarity: 0.15,
      })

      if (error) {
        console.error(`[memory] vector recall failed: ${error.message}`)
      } else if (Array.isArray(data) && data.length > 0) {
        return data.map((item) => String(item.summary))
      }
    }

    return this.localRecall(memory, query, queryEmbedding, limit)
  }

  async createTasksFromProtocol(input: {
    userId: string
    plan: ProtocolPlan
    domain?: MaxxDomain
  }) {
    const memory = this.ensureUser(input.userId)
    const effectiveDomain = input.domain ?? inferDomainFromPlan(input.plan)
    await this.archiveExistingLockTasks(input.userId, memory, effectiveDomain)
    const trustScore = (await this.trustScoreFromDb(input.userId)) ?? this.trustScoreFromMemory(memory)

    const createdDrafts: CoachingTask[] = []
    const autoActivated: CoachingTask[] = []

    for (const [index, step] of input.plan.steps.entries()) {
      const risk = inferTaskRisk(step)
      const state: TaskState = this.shouldAutoActivate(trustScore, risk) ? "active" : "draft"

      const task: StoredTask = {
        id: crypto.randomUUID(),
        domain: effectiveDomain,
        title: step.title,
        subtitle: step.action,
        estimate: step.frequency,
        priority: index + 1,
        risk,
        state,
        source: "lock",
        createdAt: nowISO(),
      }

      memory.tasks[task.id] = task

      await this.appendTaskEvent(input.userId, memory, {
        taskId: task.id,
        action: "created",
        actor: "lock",
      })

      if (state === "active") {
        await this.appendTaskEvent(input.userId, memory, {
          taskId: task.id,
          action: "activated",
          actor: "lock",
        })
      }

      await this.mirrorTaskState(input.userId, memory, task)

      const projected = this.projectTask(memory, task)
      if (state === "active") {
        autoActivated.push(projected)
      } else {
        createdDrafts.push(projected)
      }
    }

    return {
      createdDrafts,
      autoActivated,
      trustScore,
    }
  }

  private emptyDomainBuckets(): Record<MaxxDomain, CoachingTask[]> {
    return MAXX_DOMAINS.reduce(
      (acc, domain) => {
        acc[domain] = []
        return acc
      },
      {} as Record<MaxxDomain, CoachingTask[]>,
    )
  }

  private sortTasks(tasks: CoachingTask[]): CoachingTask[] {
    return tasks.slice().sort((left, right) => {
      if (left.priority !== right.priority) return left.priority - right.priority
      return left.createdAt.localeCompare(right.createdAt)
    })
  }

  private buildTaskSnapshot(tasks: CoachingTask[]): TaskSnapshot {
    const normalizedTasks = tasks.map((task) => {
      if (task.domain) return task
      const inferred = inferDomainFromText(`${task.title} ${task.subtitle}`)
      if (!inferred) return task
      return {
        ...task,
        domain: inferred,
      }
    })

    const sorted = this.sortTasks(normalizedTasks)
    const byDomain = this.emptyDomainBuckets()
    const unassigned: CoachingTask[] = []

    const allActive = sorted.filter((task) => task.state === "active")
    const drafts = sorted.filter((task) => task.state === "draft")

    for (const task of allActive) {
      if (task.domain) {
        byDomain[task.domain].push(task)
      } else {
        unassigned.push(task)
      }
    }

    const activeTasks = allActive.filter((task) => !task.isCompleted)
    const latestCompleted = sorted
      .filter((task) => task.state !== "archived")
      .filter((task) => task.isCompleted && task.completedAt)
      .sort((left, right) =>
        (right.completedAt as string).localeCompare(left.completedAt as string),
      )[0]

    return {
      homeQueue: {
        latestCompleted,
        activeTasks,
      },
      byDomain,
      allActive,
      drafts,
      unassigned,
    }
  }

  async getTaskSnapshot(userId: string): Promise<TaskSnapshot> {
    const memory = this.ensureUser(userId)
    const client = this.client()

    if (client) {
      const { data, error } = await client
        .from("coaching_tasks")
        .select("*")
        .eq("user_id", userId)
        .neq("state", "archived")
        .order("priority", { ascending: true })
        .order("created_at", { ascending: true })

      if (!error) {
        const tasks = (data ?? []).map((row) =>
          this.fromDbTask(row as unknown as Record<string, unknown>),
        )
        tasks.forEach((task) => this.hydrateTaskToLocal(memory, task))
        return this.buildTaskSnapshot(tasks)
      }
    }

    const tasks = Object.values(memory.tasks)
      .filter((task) => task.state !== "archived")
      .map((task) => this.projectTask(memory, task))

    return this.buildTaskSnapshot(tasks)
  }

  async getHomeTaskQueue(userId: string): Promise<TaskQueue> {
    const snapshot = await this.getTaskSnapshot(userId)
    return snapshot.homeQueue
  }

  async getProtocolTasks(userId: string, domain: MaxxDomain): Promise<CoachingTask[]> {
    const snapshot = await this.getTaskSnapshot(userId)
    return snapshot.byDomain[domain]
  }

  async getDraftTasks(userId: string): Promise<CoachingTask[]> {
    const snapshot = await this.getTaskSnapshot(userId)
    return snapshot.drafts
  }

  async mutateTask(input: {
    userId: string
    idempotencyKey: string
    action: TaskMutationAction
    taskId?: string
    domain?: MaxxDomain
    title?: string
    subtitle?: string
    estimate?: string
    priority?: number
    dueAt?: string
    source?: "lock" | "manual"
    actor?: "user" | "lock" | "system"
  }): Promise<TaskMutationResult> {
    const cacheKey = this.mutationCacheKey(input.userId, input.idempotencyKey)
    const cached = this.taskMutationCache.get(cacheKey)

    if (cached) {
      return {
        ...cached,
        idempotent: true,
        snapshot: await this.getTaskSnapshot(input.userId),
      }
    }

    const memory = this.ensureUser(input.userId)
    const client = this.client()

    if (client) {
      const { data, error } = await client.rpc("apply_task_mutation", {
        p_user_id: input.userId,
        p_idempotency_key: input.idempotencyKey,
        p_action: input.action,
        p_task_id: input.taskId ?? null,
        p_domain: input.domain ?? null,
        p_title: input.title ?? null,
        p_subtitle: input.subtitle ?? null,
        p_estimate: input.estimate ?? null,
        p_priority: input.priority ?? null,
        p_due_at: input.dueAt ?? null,
        p_source: input.source ?? null,
        p_actor: input.actor ?? null,
      })

      if (!error && data && typeof data === "object") {
        const payload = data as Record<string, unknown>
        const status = (typeof payload.status === "string"
          ? payload.status
          : "ok") as TaskMutationStatus

        let task: CoachingTask | undefined
        const rawTask = payload.task
        if (rawTask && typeof rawTask === "object") {
          task = this.fromDbTask(rawTask as Record<string, unknown>)
          this.hydrateTaskToLocal(memory, task)
        }

        if (!Boolean(payload.idempotent) && status === "ok") {
          this.bumpTrustSignal(memory, input.action)
        }

        const stored: StoredTaskMutationResult = { status, task }
        this.rememberTaskMutation(cacheKey, stored)
        return {
          ...stored,
          idempotent: Boolean(payload.idempotent),
          snapshot: await this.getTaskSnapshot(input.userId),
        }
      }

      if (error && !error.message.toLowerCase().includes("apply_task_mutation")) {
        console.error(`[memory] task mutation rpc failed: ${error.message}`)
      }
    }

    let status: TaskMutationStatus = "ok"
    let task: StoredTask | undefined
    const actor = input.actor ?? "user"

    if (input.action === "create") {
      const domain = input.domain ?? "mind"
      const title = input.title?.trim() ?? "Untitled task"
      const subtitle = input.subtitle?.trim() ?? "No details provided"

      task = {
        id: crypto.randomUUID(),
        domain,
        title,
        subtitle,
        estimate: input.estimate,
        priority: input.priority ?? 100,
        risk: "low",
        state: "active",
        source: input.source ?? "manual",
        createdAt: nowISO(),
        dueAt: input.dueAt,
      }

      memory.tasks[task.id] = task
      await this.appendTaskEvent(input.userId, memory, {
        taskId: task.id,
        action: "created",
        actor,
      })
      await this.mirrorTaskState(input.userId, memory, task)
      status = "created"
    } else {
      if (!input.taskId) {
        status = "not_found"
      } else {
        if (client) {
          const { data } = await client
            .from("coaching_tasks")
            .select("*")
            .eq("id", input.taskId)
            .eq("user_id", input.userId)
            .maybeSingle()

          if (data) {
            const hydrated = this.fromDbTask(data as unknown as Record<string, unknown>)
            this.hydrateTaskToLocal(memory, hydrated)
          }
        }

        task = memory.tasks[input.taskId]
        if (!task) {
          status = "not_found"
        } else if (input.action === "complete") {
          if (task.state !== "active") {
            status = "invalid_state"
          } else if (this.taskCompletionState(memory, task.id).isCompleted) {
            status = "noop"
          } else {
            await this.appendTaskEvent(input.userId, memory, {
              taskId: task.id,
              action: "completed",
              actor,
            })
            await this.mirrorTaskState(input.userId, memory, task)
          }
        } else if (input.action === "reopen") {
          if (task.state !== "active") {
            status = "invalid_state"
          } else if (!this.taskCompletionState(memory, task.id).isCompleted) {
            status = "noop"
          } else {
            await this.appendTaskEvent(input.userId, memory, {
              taskId: task.id,
              action: "reopened",
              actor,
            })
            await this.mirrorTaskState(input.userId, memory, task)
          }
        } else if (input.action === "approve_draft") {
          if (task.state !== "draft") {
            status = "invalid_state"
          } else {
            this.bumpTrustSignal(memory, input.action)
            await this.appendTaskEvent(input.userId, memory, {
              taskId: task.id,
              action: "approved",
              actor,
            })
            task.state = "active"
            await this.appendTaskEvent(input.userId, memory, {
              taskId: task.id,
              action: "activated",
              actor: "system",
            })
            await this.mirrorTaskState(input.userId, memory, task)
          }
        } else if (input.action === "reject_draft") {
          if (task.state !== "draft") {
            status = "invalid_state"
          } else {
            this.bumpTrustSignal(memory, input.action)
            await this.appendTaskEvent(input.userId, memory, {
              taskId: task.id,
              action: "rejected",
              actor,
            })
            task.state = "archived"
            await this.appendTaskEvent(input.userId, memory, {
              taskId: task.id,
              action: "archived",
              actor: "system",
            })
            await this.mirrorTaskState(input.userId, memory, task)
          }
        } else if (input.action === "archive") {
          if (task.state === "archived") {
            status = "noop"
          } else {
            task.state = "archived"
            await this.appendTaskEvent(input.userId, memory, {
              taskId: task.id,
              action: "archived",
              actor,
            })
            await this.mirrorTaskState(input.userId, memory, task)
          }
        }
      }
    }

    const projected = task ? this.projectTask(memory, task) : undefined
    const stored: StoredTaskMutationResult = {
      status,
      task: projected,
    }

    this.rememberTaskMutation(cacheKey, stored)

    return {
      ...stored,
      idempotent: false,
      snapshot: await this.getTaskSnapshot(input.userId),
    }
  }

  async recordTaskEvent(input: {
    userId: string
    taskId: string
    action: Extract<TaskEventAction, "completed" | "reopened">
    actor?: "user" | "lock" | "system"
  }): Promise<CoachingTask | undefined> {
    const result = await this.mutateTask({
      userId: input.userId,
      idempotencyKey: crypto.randomUUID(),
      action: input.action === "completed" ? "complete" : "reopen",
      taskId: input.taskId,
      actor: input.actor,
    })

    if (result.status === "not_found" || result.status === "invalid_state") {
      return undefined
    }

    return result.task
  }

  async decideDraftTask(input: {
    userId: string
    taskId: string
    decision: "approve" | "reject"
    actor?: "user" | "lock" | "system"
  }): Promise<CoachingTask | undefined> {
    const result = await this.mutateTask({
      userId: input.userId,
      idempotencyKey: crypto.randomUUID(),
      action: input.decision === "approve" ? "approve_draft" : "reject_draft",
      taskId: input.taskId,
      actor: input.actor,
    })

    if (result.status === "not_found" || result.status === "invalid_state") {
      return undefined
    }

    return result.task
  }

  async getTaskEvents(userId: string, taskId?: string): Promise<TaskEvent[]> {
    const memory = this.ensureUser(userId)
    const client = this.client()

    if (client) {
      let query = client
        .from("task_events")
        .select("*")
        .eq("user_id", userId)
        .order("at", { ascending: false })

      if (taskId) {
        query = query.eq("task_id", taskId)
      }

      const { data, error } = await query
      if (!error && data) {
        const mapped = data.map((event) => ({
          id: String(event.id),
          taskId: String(event.task_id),
          action: event.action as TaskEventAction,
          actor: event.actor as "user" | "lock" | "system",
          at: String(event.at),
        }))
        memory.taskEvents = mapped
        return mapped
      }
    }

    if (!taskId) return [...memory.taskEvents]
    return memory.taskEvents.filter((event) => event.taskId === taskId)
  }
}
