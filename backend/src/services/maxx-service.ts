import type { CoachingTask, Profile, TaskQueue, TaskEvent } from "../schemas/contracts"
import type { MaxxDomain } from "../types/domain"
import { MemoryService } from "./memory-service"

type ProtocolStatusTone = "push" | "maintain" | "standard"

type MaxxPlanItem = {
  title: string
  cadence: string
}

type MaxxTrendRow = {
  title: string
  dots: boolean[]
}

type ScorePoint = {
  weekStart: string
  score: number
}

export type MaxxDetailResponse = {
  domain: MaxxDomain
  score: number
  scoreHistory: ScorePoint[]
  weeklyDelta: number
  statusTone: ProtocolStatusTone
  streakDays: number
  objective: string
  lockDiagnosis: string
  lockAction: string
  adjustmentNote: string
  plan: MaxxPlanItem[]
  tasks: CoachingTask[]
  last14Days: MaxxTrendRow[]
  homeQueue: TaskQueue
}

const DAY_MS = 24 * 60 * 60 * 1000

const DOMAIN_DEFAULT_OBJECTIVES: Record<MaxxDomain, string> = {
  gym: "Build execution consistency in your training split.",
  face: "Hold baseline skincare and recovery consistency.",
  money: "Increase opportunity pipeline with daily outreach.",
  mind: "Stabilize focus blocks and sleep rhythm.",
  social: "Increase social reps with low-friction consistency.",
}

const DOMAIN_KEYWORDS: Record<MaxxDomain, string[]> = {
  gym: ["gym", "training", "strength", "muscle", "workout"],
  face: ["face", "skin", "looks", "skincare", "grooming"],
  money: ["money", "career", "internship", "income", "business"],
  mind: ["mind", "focus", "sleep", "deep work", "discipline"],
  social: ["social", "confidence", "network", "conversation", "approach"],
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value))
}

function parseDate(value: string): Date | null {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) return null
  return parsed
}

function dayKey(date: Date): string {
  return date.toISOString().slice(0, 10)
}

function startOfUTCDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()))
}

function last14DayKeys(reference = new Date()): string[] {
  const today = startOfUTCDay(reference).getTime()
  const keys: string[] = []

  for (let i = 13; i >= 0; i -= 1) {
    const stamp = new Date(today - i * DAY_MS)
    keys.push(dayKey(stamp))
  }

  return keys
}

function completionCountByDay(events: TaskEvent[]) {
  const completed = new Map<string, number>()
  const reopened = new Map<string, number>()

  for (const event of events) {
    const parsed = parseDate(event.at)
    if (!parsed) continue
    const key = dayKey(parsed)

    if (event.action === "completed") {
      completed.set(key, (completed.get(key) ?? 0) + 1)
    }

    if (event.action === "reopened") {
      reopened.set(key, (reopened.get(key) ?? 0) + 1)
    }
  }

  return { completed, reopened }
}

function computeStreak(days: boolean[]): number {
  let streak = 0
  for (let index = days.length - 1; index >= 0; index -= 1) {
    if (!days[index]) break
    streak += 1
  }
  return streak
}

function inferStatusTone(input: {
  weeklyDelta: number
  completionDaysThisWeek: number
}): ProtocolStatusTone {
  if (input.weeklyDelta < 0 || input.completionDaysThisWeek <= 2) {
    return "push"
  }

  if (input.weeklyDelta >= 2 && input.completionDaysThisWeek >= 4) {
    return "maintain"
  }

  return "standard"
}

function objectiveFromProfile(profile: Profile | undefined, domain: MaxxDomain): string {
  if (!profile) return DOMAIN_DEFAULT_OBJECTIVES[domain]

  const payload = profile as Profile & { maxxContextNotes?: Record<string, unknown> }
  const contextNote = payload.maxxContextNotes?.[domain]
  if (typeof contextNote === "string" && contextNote.trim().length > 0) {
    return contextNote
  }

  const goalMatch = profile.goals.find((goal) => {
    const normalized = goal.toLowerCase()
    return DOMAIN_KEYWORDS[domain].some((keyword) => normalized.includes(keyword))
  })

  if (goalMatch) return goalMatch

  return DOMAIN_DEFAULT_OBJECTIVES[domain]
}

function defaultPlanFor(domain: MaxxDomain): MaxxPlanItem[] {
  return [
    { title: `${domain.toUpperCase()} baseline audit`, cadence: "This week" },
    { title: "One non-negotiable daily block", cadence: "Daily" },
    { title: "Weekly review + adjustment", cadence: "Weekly" },
  ]
}

function buildDiagnosis(input: {
  domain: MaxxDomain
  weeklyDelta: number
  completionDaysThisWeek: number
  openTasks: number
}): { lockDiagnosis: string; lockAction: string; adjustmentNote: string } {
  if (input.completionDaysThisWeek <= 2) {
    return {
      lockDiagnosis: "Execution is inconsistent. Too many empty days this week.",
      lockAction: `Lock one non-negotiable ${input.domain.toUpperCase()} action every day for the next 7 days.`,
      adjustmentNote: "Reduce scope this week. Keep only top-priority tasks active.",
    }
  }

  if (input.weeklyDelta > 0) {
    return {
      lockDiagnosis: "Trend is positive. Keep pressure, avoid unnecessary complexity.",
      lockAction: "Repeat the current cadence and protect recovery windows.",
      adjustmentNote: "Maintain plan structure. Only adjust if two consecutive misses happen.",
    }
  }

  return {
    lockDiagnosis: "Progress is stable but fragile. Execution quality needs tighter follow-through.",
    lockAction: "Finish the highest-priority open task before adding anything new.",
    adjustmentNote:
      input.openTasks > 0
        ? `You have ${input.openTasks} open task${input.openTasks === 1 ? "" : "s"}. Close top items first.`
        : "Current queue is clean. Keep it that way with daily closure.",
  }
}

function planFromTasks(tasks: CoachingTask[], domain: MaxxDomain): MaxxPlanItem[] {
  const plan = tasks
    .slice()
    .sort((left, right) => left.priority - right.priority)
    .slice(0, 6)
    .map((task) => ({
      title: task.title,
      cadence: task.estimate ?? "Daily",
    }))

  if (plan.length > 0) return plan
  return defaultPlanFor(domain)
}

function buildPatternRows(input: {
  dayKeys: string[]
  completedByDay: Map<string, number>
  reopenedByDay: Map<string, number>
}): MaxxTrendRow[] {
  const completionDots = input.dayKeys.map((key) => (input.completedByDay.get(key) ?? 0) > 0)
  const highOutputDots = input.dayKeys.map((key) => (input.completedByDay.get(key) ?? 0) >= 2)
  const recoveryDots = input.dayKeys.map((key) => (input.reopenedByDay.get(key) ?? 0) === 0)

  return [
    { title: "Completions", dots: completionDots },
    { title: "High output", dots: highOutputDots },
    { title: "Recovery", dots: recoveryDots },
  ]
}

export class MaxxService {
  constructor(private readonly memory: MemoryService) {}

  async getDomainDetail(userId: string, domain: MaxxDomain): Promise<MaxxDetailResponse> {
    const [profile, domainScores, scoreHistory, snapshot, events] = await Promise.all([
      this.memory.getProfile(userId),
      this.memory.getDomainScores(userId),
      this.memory.getDomainScoreHistory(userId, domain),
      this.memory.getTaskSnapshot(userId),
      this.memory.getTaskEvents(userId),
    ])
    const tasks = snapshot.byDomain[domain]
    const homeQueue = snapshot.homeQueue

    const domainTaskIDs = new Set(tasks.map((task) => task.id))
    const domainEvents = events.filter((event) => domainTaskIDs.has(event.taskId))
    const { completed, reopened } = completionCountByDay(domainEvents)
    const keys = last14DayKeys()
    const completionDots = keys.map((key) => (completed.get(key) ?? 0) > 0)
    const streakDays = computeStreak(completionDots)

    const previousWeekKeys = keys.slice(0, 7)
    const currentWeekKeys = keys.slice(7)
    const previousWeekCompleted = previousWeekKeys.reduce(
      (sum, key) => sum + (completed.get(key) ?? 0),
      0,
    )
    const currentWeekCompleted = currentWeekKeys.reduce(
      (sum, key) => sum + (completed.get(key) ?? 0),
      0,
    )

    const completionDaysThisWeek = currentWeekKeys.filter(
      (key) => (completed.get(key) ?? 0) > 0,
    ).length

    const weeklyDelta = clamp((currentWeekCompleted - previousWeekCompleted) * 2, -12, 12)
    const openTasks = tasks.filter((task) => !task.isCompleted).length
    const statusTone = inferStatusTone({
      weeklyDelta,
      completionDaysThisWeek,
    })

    const diagnosis = buildDiagnosis({
      domain,
      weeklyDelta,
      completionDaysThisWeek,
      openTasks,
    })

    return {
      domain,
      score: clamp(Math.round(domainScores[domain] ?? 50), 0, 100),
      scoreHistory: scoreHistory.map((point) => ({
        weekStart: point.weekStart,
        score: clamp(Math.round(point.score), 0, 100),
      })),
      weeklyDelta,
      statusTone,
      streakDays,
      objective: objectiveFromProfile(profile, domain),
      lockDiagnosis: diagnosis.lockDiagnosis,
      lockAction: diagnosis.lockAction,
      adjustmentNote: diagnosis.adjustmentNote,
      plan: planFromTasks(tasks, domain),
      tasks,
      last14Days: buildPatternRows({
        dayKeys: keys,
        completedByDay: completed,
        reopenedByDay: reopened,
      }),
      homeQueue,
    }
  }
}
