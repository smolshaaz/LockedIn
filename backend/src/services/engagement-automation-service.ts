import { automationConfig } from "../config/env"
import { MAXX_DOMAINS, type DomainScores, type MaxxDomain } from "../types/domain"
import { services } from "./container"
import {
  listOmnichannelContacts,
  reserveOmnichannelAutomationSend,
  sendOmnichannelMessageToContact,
  type OmnichannelContact,
} from "./omnichannel-chat-service"

type AutomationKind = "checkin" | "reminder" | "streak"

const ALL_AUTOMATION_KINDS: AutomationKind[] = ["checkin", "reminder", "streak"]

type AutomationRunReport = {
  requestedKinds: AutomationKind[]
  contactsFound: number
  sent: Record<AutomationKind, number>
  skipped: Record<AutomationKind, number>
  errors: Array<{
    contactKey: string
    kind: AutomationKind
    error: string
  }>
}

function now() {
  return new Date()
}

function dayBucket(date: Date): string {
  return date.toISOString().slice(0, 10)
}

function weekBucket(date: Date): string {
  const copy = new Date(date)
  const day = copy.getUTCDay()
  const diffToMonday = (day + 6) % 7
  copy.setUTCDate(copy.getUTCDate() - diffToMonday)
  return copy.toISOString().slice(0, 10)
}

function parseWeekStart(weekStart?: string): Date | null {
  if (!weekStart) return null
  const parsed = new Date(`${weekStart}T00:00:00.000Z`)
  if (Number.isNaN(parsed.getTime())) return null
  return parsed
}

function hoursSince(iso?: string): number | null {
  if (!iso) return null
  const parsed = new Date(iso)
  if (Number.isNaN(parsed.getTime())) return null
  return (Date.now() - parsed.getTime()) / (1000 * 60 * 60)
}

function needsWeeklyCheckin(latestWeekStart?: string): boolean {
  const latest = parseWeekStart(latestWeekStart)
  if (!latest) return true
  const elapsedDays = (Date.now() - latest.getTime()) / (1000 * 60 * 60 * 24)
  return elapsedDays >= automationConfig.checkinIntervalDays
}

function hasDownTrend(trend: Array<{ score: number }>): boolean {
  if (trend.length < 3) return false
  return trend[0].score < trend[1].score && trend[1].score < trend[2].score
}

function lowestScoreDomain(scores: DomainScores): MaxxDomain {
  let selected: MaxxDomain = "mind"
  let selectedScore = Number.POSITIVE_INFINITY

  for (const domain of MAXX_DOMAINS) {
    const score = scores[domain]
    if (score < selectedScore) {
      selected = domain
      selectedScore = score
    }
  }

  return selected
}

function dailyTaskTemplate(domain: MaxxDomain): {
  title: string
  subtitle: string
  estimate: string
} {
  if (domain === "gym") {
    return {
      title: "Lock workout slot",
      subtitle: "Book a 30-45 minute training slot and complete your first set.",
      estimate: "Today · 45m",
    }
  }

  if (domain === "face") {
    return {
      title: "Skin baseline reset",
      subtitle: "Run AM/PM essentials and log one visible skin signal.",
      estimate: "Today · 15m",
    }
  }

  if (domain === "money") {
    return {
      title: "Opportunity push",
      subtitle: "Send two targeted applications or follow-ups before day end.",
      estimate: "Today · 30m",
    }
  }

  if (domain === "social") {
    return {
      title: "Social rep",
      subtitle: "Initiate one new conversation and send one follow-up message.",
      estimate: "Today · 20m",
    }
  }

  return {
    title: "Focus anchor block",
    subtitle: "Complete one uninterrupted deep-work block before notifications.",
    estimate: "Today · 50m",
  }
}

function endOfUtcDayIso(reference: Date): string {
  const stamp = new Date(Date.UTC(
    reference.getUTCFullYear(),
    reference.getUTCMonth(),
    reference.getUTCDate(),
    23,
    59,
    59,
    0,
  ))
  return stamp.toISOString()
}

async function ensureDailyLockTask(contact: OmnichannelContact): Promise<boolean> {
  const queue = await services.memory.getHomeTaskQueue(contact.lockUserId)
  if (queue.activeTasks.length > 0) {
    return false
  }

  const date = now()
  const scores = await services.memory.getDomainScores(contact.lockUserId)
  const domain = lowestScoreDomain(scores)
  const template = dailyTaskTemplate(domain)

  const result = await services.memory.mutateTask({
    userId: contact.lockUserId,
    idempotencyKey: `lock-daily-seed:${dayBucket(date)}:${domain}`,
    action: "create",
    domain,
    title: template.title,
    subtitle: template.subtitle,
    estimate: template.estimate,
    priority: 1,
    dueAt: endOfUtcDayIso(date),
    source: "lock",
    actor: "lock",
  })

  return result.status === "created"
}

async function sendIfReserved(input: {
  contact: OmnichannelContact
  kind: AutomationKind
  bucket: string
  ttlMs: number
  message: string
}): Promise<{ sent: boolean; error?: string }> {
  const reserved = await reserveOmnichannelAutomationSend({
    kind: input.kind,
    contactKey: input.contact.key,
    bucket: input.bucket,
    ttlMs: input.ttlMs,
  })

  if (!reserved) {
    return { sent: false }
  }

  const result = await sendOmnichannelMessageToContact(input.contact, input.message)
  if (!result.ok) {
    return {
      sent: false,
      error: result.error,
    }
  }

  return { sent: true }
}

async function runCheckin(contact: OmnichannelContact) {
  const trend = await services.memory.recentTrend(contact.lockUserId)
  const latestWeekStart = trend[0]?.weekStart

  if (!needsWeeklyCheckin(latestWeekStart)) {
    return { sent: false }
  }

  const profile = await services.memory.getProfile(contact.lockUserId)
  const name = profile?.name ?? contact.fullName ?? "you"
  const message = [
    `Weekly check-in time, ${name}.`,
    "Reply with this format:",
    "gym: score/notes",
    "mind: score/notes",
    "social: score/notes",
    "money: score/notes",
    "face: score/notes",
  ].join("\n")

  return sendIfReserved({
    contact,
    kind: "checkin",
    bucket: weekBucket(now()),
    ttlMs: automationConfig.checkinIntervalDays * 24 * 60 * 60 * 1000,
    message,
  })
}

async function runReminder(contact: OmnichannelContact) {
  const seeded = await ensureDailyLockTask(contact)
  const queue = await services.memory.getHomeTaskQueue(contact.lockUserId)
  const active = queue.activeTasks
  if (!active.length) {
    return { sent: false }
  }

  const top = active.slice(0, 2)
  const lines = top.map((task, index) => `${index + 1}. ${task.title} — ${task.subtitle}`)
  const message = [
    "Protocol reminder:",
    seeded ? "LOCK set today's starter task to keep momentum." : null,
    ...lines,
    "Send me what you completed today.",
  ]
    .filter((line): line is string => Boolean(line))
    .join("\n")

  return sendIfReserved({
    contact,
    kind: "reminder",
    bucket: dayBucket(now()),
    ttlMs: automationConfig.reminderCooldownHours * 60 * 60 * 1000,
    message,
  })
}

async function runStreakNudge(contact: OmnichannelContact) {
  const [trend, queue] = await Promise.all([
    services.memory.recentTrend(contact.lockUserId),
    services.memory.getHomeTaskQueue(contact.lockUserId),
  ])

  const latestCompletedHours = hoursSince(queue.latestCompleted?.completedAt)
  const completionStale = latestCompletedHours === null || latestCompletedHours > 72
  const downTrend = hasDownTrend(trend)
  const atRisk = downTrend || completionStale

  if (!atRisk) {
    return { sent: false }
  }

  const reason = downTrend
    ? "Your LifeScore trend is slipping for multiple weeks."
    : "No completed task signal in the last 72h."
  const message = [
    "Streak nudge:",
    reason,
    "Do one small win in the next 60 minutes and report it here.",
  ].join("\n")

  return sendIfReserved({
    contact,
    kind: "streak",
    bucket: dayBucket(now()),
    ttlMs: automationConfig.streakNudgeCooldownHours * 60 * 60 * 1000,
    message,
  })
}

export async function runEngagementAutomation(
  requestedKinds?: AutomationKind[],
): Promise<AutomationRunReport> {
  const kinds = requestedKinds?.length
    ? requestedKinds
    : [...ALL_AUTOMATION_KINDS]
  const contacts = await listOmnichannelContacts()

  const report: AutomationRunReport = {
    requestedKinds: kinds,
    contactsFound: contacts.length,
    sent: {
      checkin: 0,
      reminder: 0,
      streak: 0,
    },
    skipped: {
      checkin: 0,
      reminder: 0,
      streak: 0,
    },
    errors: [],
  }

  for (const contact of contacts) {
    for (const kind of kinds) {
      try {
        const result =
          kind === "checkin"
            ? await runCheckin(contact)
            : kind === "reminder"
              ? await runReminder(contact)
              : await runStreakNudge(contact)

        if (result.sent) {
          report.sent[kind] += 1
        } else {
          report.skipped[kind] += 1
          if (result.error) {
            report.errors.push({
              contactKey: contact.key,
              kind,
              error: result.error,
            })
          }
        }
      } catch (error) {
        report.skipped[kind] += 1
        report.errors.push({
          contactKey: contact.key,
          kind,
          error: error instanceof Error ? error.message : "unknown automation error",
        })
      }
    }
  }

  return report
}

export const engagementAutomationKinds = ALL_AUTOMATION_KINDS
