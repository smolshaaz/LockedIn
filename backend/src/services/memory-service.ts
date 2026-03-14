import type {
  ChatRequest,
  Profile,
  WeeklyCheckin,
} from "../schemas/contracts"
import type { DomainScores } from "../types/domain"

type ChatTurn = {
  role: "user" | "assistant"
  content: string
  at: string
}

type UserMemory = {
  profile?: Profile
  domainScores: DomainScores
  weeklySummaries: Array<{ weekStart: string; summary: string }>
  threadTurns: Record<string, ChatTurn[]>
  vectorFacts: string[]
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

export class MemoryService {
  private readonly store = new Map<string, UserMemory>()

  private ensureUser(userId: string): UserMemory {
    if (!this.store.has(userId)) {
      this.store.set(userId, {
        domainScores: defaultScores(),
        weeklySummaries: [],
        threadTurns: {},
        vectorFacts: [],
      })
    }

    return this.store.get(userId) as UserMemory
  }

  getProfile(userId: string): Profile | undefined {
    return this.ensureUser(userId).profile
  }

  setProfile(userId: string, profile: Profile): Profile {
    const memory = this.ensureUser(userId)
    memory.profile = profile
    memory.domainScores = profile.baseline
    return profile
  }

  mergeProfile(userId: string, patch: Partial<Profile>): Profile | undefined {
    const memory = this.ensureUser(userId)
    if (!memory.profile) return undefined

    const updated = {
      ...memory.profile,
      ...patch,
      baseline: {
        ...memory.profile.baseline,
        ...patch.baseline,
      },
    }

    memory.profile = updated
    memory.domainScores = updated.baseline
    return updated
  }

  getDomainScores(userId: string): DomainScores {
    return this.ensureUser(userId).domainScores
  }

  ingestCheckin(userId: string, checkin: WeeklyCheckin) {
    const memory = this.ensureUser(userId)
    for (const entry of checkin.entries) {
      memory.domainScores[entry.domain] = entry.score
      memory.vectorFacts.push(`${entry.domain}:${entry.notes}`)
    }

    const summary = checkin.entries
      .map((entry) => `${entry.domain.toUpperCase()} ${entry.score}: ${entry.notes}`)
      .join(" | ")

    memory.weeklySummaries.unshift({
      weekStart: checkin.weekStart,
      summary,
    })

    memory.weeklySummaries = memory.weeklySummaries.slice(0, 12)

    return {
      updatedScores: memory.domainScores,
      summary,
    }
  }

  appendChatTurn(userId: string, request: ChatRequest, replyMessage: string) {
    const memory = this.ensureUser(userId)
    const turns = memory.threadTurns[request.threadId] ?? []

    turns.push({ role: "user", content: request.message, at: new Date().toISOString() })
    turns.push({ role: "assistant", content: replyMessage, at: new Date().toISOString() })

    memory.threadTurns[request.threadId] = turns.slice(-20)
    memory.vectorFacts.push(request.message)
    memory.vectorFacts = memory.vectorFacts.slice(-200)
  }

  recall(userId: string, query: string, limit = 3): string[] {
    const memory = this.ensureUser(userId)
    const q = query.toLowerCase()

    const matched = memory.vectorFacts.filter((fact) =>
      fact.toLowerCase().split(" ").some((token) => q.includes(token) || token.includes(q)),
    )

    return matched.slice(-limit)
  }

  recentTrend(userId: string) {
    const memory = this.ensureUser(userId)
    return memory.weeklySummaries.map((summary) => ({
      weekStart: summary.weekStart,
      score: Object.values(memory.domainScores).reduce((a, b) => a + b, 0) / 5,
    }))
  }
}
