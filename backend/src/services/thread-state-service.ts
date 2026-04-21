import { env } from "../config/env"
import { getRedisClient } from "../integrations/redis-client"

type ThreadState = {
  lastMessageAt: string
  messageCount: number
}

export class ThreadStateService {
  private readonly fallback = new Map<string, ThreadState>()

  private key(userId: string, threadId: string) {
    return `thread:${userId}:${threadId}`
  }

  getLocal(userId: string, threadId: string): ThreadState | undefined {
    return this.fallback.get(this.key(userId, threadId))
  }

  bump(userId: string, threadId: string, at = new Date().toISOString()) {
    const key = this.key(userId, threadId)
    const previous = this.fallback.get(key)

    const next: ThreadState = {
      lastMessageAt: at,
      messageCount: (previous?.messageCount ?? 0) + 1,
    }

    this.fallback.set(key, next)

    const redis = getRedisClient()
    if (!redis) return

    void redis
      .set(key, next, {
        ex: env.THREAD_STATE_TTL_SECONDS,
      })
      .catch((error) => {
        const detail = error instanceof Error ? error.message : String(error)
        console.error(`[thread-state] redis set failed: ${detail}`)
      })
  }

  async hydrate(userId: string, threadId: string): Promise<ThreadState | null> {
    const key = this.key(userId, threadId)
    if (this.fallback.has(key)) {
      return this.fallback.get(key) ?? null
    }

    const redis = getRedisClient()
    if (!redis) return null

    try {
      const remote = await redis.get<ThreadState>(key)
      if (remote) {
        this.fallback.set(key, remote)
        return remote
      }
      return null
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error)
      console.error(`[thread-state] redis get failed: ${detail}`)
      return null
    }
  }
}
