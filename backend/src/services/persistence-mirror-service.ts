import { MAXX_DOMAINS, type DomainScores, type MaxxDomain } from "../types/domain"
import type { Profile, TaskEvent, WeeklyCheckin } from "../schemas/contracts"
import { getSupabaseAdminClient } from "../integrations/supabase-client"

function extractOnboardingPayload(profile: Profile): Record<string, unknown> {
  const {
    userId: _userId,
    name: _name,
    age: _age,
    goals: _goals,
    constraints: _constraints,
    communicationStyle: _communicationStyle,
    baseline: _baseline,
    ...rest
  } = profile as Profile & Record<string, unknown>

  return rest
}

export type PersistedTask = {
  id: string
  domain?: string
  title: string
  subtitle: string
  estimate?: string
  priority: number
  risk: "low" | "medium" | "high"
  state: "draft" | "active" | "archived"
  source: "lock" | "manual"
  createdAt: string
  dueAt?: string
  isCompleted: boolean
  completedAt?: string
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

function resolveTaskDomain(task: PersistedTask): MaxxDomain {
  if (typeof task.domain === "string") {
    const normalized = task.domain.trim().toLowerCase()
    if (MAXX_DOMAINS.includes(normalized as MaxxDomain)) {
      return normalized as MaxxDomain
    }
  }

  return inferDomainFromText(`${task.title} ${task.subtitle}`) ?? "mind"
}

export class PersistenceMirrorService {
  private async run(label: string, work: () => Promise<unknown>) {
    const client = getSupabaseAdminClient()
    if (!client) return

    await work().catch((error) => {
      const detail = error instanceof Error ? error.message : String(error)
      console.error(`[persistence] ${label} failed: ${detail}`)
    })
  }

  async mirrorProfile(profile: Profile) {
    await this.run("mirrorProfile", async () => {
      const client = getSupabaseAdminClient()
      if (!client) return

      const { error } = await client.from("profiles").upsert(
        {
          user_id: profile.userId,
          name: profile.name,
          age: profile.age ?? null,
          goals: profile.goals,
          constraints: profile.constraints,
          communication_style: profile.communicationStyle,
          baseline_scores: profile.baseline,
          onboarding_payload: extractOnboardingPayload(profile),
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      )

      if (error) throw error
    })
  }

  async mirrorDomainScores(userId: string, scores: DomainScores) {
    await this.run("mirrorDomainScores", async () => {
      const client = getSupabaseAdminClient()
      if (!client) return

      const { error } = await client.from("domain_scores_current").upsert(
        {
          user_id: userId,
          gym: scores.gym,
          face: scores.face,
          money: scores.money,
          mind: scores.mind,
          social: scores.social,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      )

      if (error) throw error
    })
  }

  async mirrorWeeklyCheckin(userId: string, checkin: WeeklyCheckin, summary: string) {
    await this.run("mirrorWeeklyCheckin", async () => {
      const client = getSupabaseAdminClient()
      if (!client) return

      const { error } = await client.from("weekly_checkins").insert({
        user_id: userId,
        week_start: checkin.weekStart,
        entries: checkin.entries,
        summary,
      })

      if (error) throw error
    })
  }

  async mirrorLifeScoreSnapshot(userId: string, weekStart: string, totalScore: number) {
    await this.run("mirrorLifeScoreSnapshot", async () => {
      const client = getSupabaseAdminClient()
      if (!client) return

      const { error } = await client.from("lifescore_snapshots").upsert(
        {
          user_id: userId,
          week_start: weekStart,
          total_score: Number(totalScore.toFixed(2)),
        },
        { onConflict: "user_id,week_start" },
      )

      if (error) throw error
    })
  }

  async mirrorTask(userId: string, task: PersistedTask) {
    await this.run("mirrorTask", async () => {
      const client = getSupabaseAdminClient()
      if (!client) return
      const domain = resolveTaskDomain(task)

      const { error } = await client.from("coaching_tasks").upsert(
        {
          id: task.id,
          user_id: userId,
          domain,
          title: task.title,
          subtitle: task.subtitle,
          estimate: task.estimate ?? null,
          priority: task.priority,
          risk: task.risk,
          state: task.state,
          source: task.source,
          created_at: task.createdAt,
          due_at: task.dueAt ?? null,
          is_completed: task.isCompleted,
          completed_at: task.completedAt ?? null,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "id" },
      )

      if (error) throw error
    })
  }

  async mirrorTaskEvent(userId: string, event: TaskEvent) {
    await this.run("mirrorTaskEvent", async () => {
      const client = getSupabaseAdminClient()
      if (!client) return

      const { error } = await client.from("task_events").insert({
        id: event.id,
        task_id: event.taskId,
        user_id: userId,
        action: event.action,
        actor: event.actor,
        at: event.at,
      })

      if (error) throw error
    })
  }

  async mirrorEpisodicMemory(input: {
    userId: string
    summary: string
    tags: string[]
    embedding: number[]
    createdAt: string
  }) {
    await this.run("mirrorEpisodicMemory", async () => {
      const client = getSupabaseAdminClient()
      if (!client) return

      const { error } = await client.from("episodic_memories").insert({
        user_id: input.userId,
        summary: input.summary,
        tags: input.tags,
        embedding: input.embedding,
        created_at: input.createdAt,
      })

      if (error) throw error
    })
  }
}
