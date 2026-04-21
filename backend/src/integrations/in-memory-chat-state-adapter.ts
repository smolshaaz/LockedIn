import type { Lock, QueueEntry, StateAdapter } from "chat"

type TimedValue<T> = {
  value: T
  expiresAt?: number
}

function now() {
  return Date.now()
}

function ttlToExpiry(ttlMs?: number) {
  if (!ttlMs || ttlMs <= 0) return undefined
  return now() + ttlMs
}

function isExpired(expiresAt?: number) {
  return typeof expiresAt === "number" && expiresAt <= now()
}

export class InMemoryChatStateAdapter implements StateAdapter {
  private readonly values = new Map<string, TimedValue<unknown>>()
  private readonly lists = new Map<string, TimedValue<unknown[]>>()
  private readonly subscriptions = new Set<string>()
  private readonly locks = new Map<string, Lock>()
  private readonly queues = new Map<string, QueueEntry[]>()

  async connect(): Promise<void> {
    return
  }

  async disconnect(): Promise<void> {
    return
  }

  async subscribe(threadId: string): Promise<void> {
    this.subscriptions.add(threadId)
  }

  async unsubscribe(threadId: string): Promise<void> {
    this.subscriptions.delete(threadId)
  }

  async isSubscribed(threadId: string): Promise<boolean> {
    return this.subscriptions.has(threadId)
  }

  async acquireLock(threadId: string, ttlMs: number): Promise<Lock | null> {
    const existing = this.locks.get(threadId)
    if (existing && !isExpired(existing.expiresAt)) {
      return null
    }

    const lock: Lock = {
      threadId,
      token: crypto.randomUUID(),
      expiresAt: now() + ttlMs,
    }
    this.locks.set(threadId, lock)
    return lock
  }

  async forceReleaseLock(threadId: string): Promise<void> {
    this.locks.delete(threadId)
  }

  async releaseLock(lock: Lock): Promise<void> {
    const existing = this.locks.get(lock.threadId)
    if (!existing) return
    if (existing.token !== lock.token) return
    this.locks.delete(lock.threadId)
  }

  async extendLock(lock: Lock, ttlMs: number): Promise<boolean> {
    const existing = this.locks.get(lock.threadId)
    if (!existing) return false
    if (existing.token !== lock.token) return false
    if (isExpired(existing.expiresAt)) {
      this.locks.delete(lock.threadId)
      return false
    }

    this.locks.set(lock.threadId, {
      ...existing,
      expiresAt: now() + ttlMs,
    })
    return true
  }

  async get<T = unknown>(key: string): Promise<T | null> {
    const entry = this.values.get(key)
    if (!entry) return null
    if (isExpired(entry.expiresAt)) {
      this.values.delete(key)
      return null
    }
    return entry.value as T
  }

  async set<T = unknown>(key: string, value: T, ttlMs?: number): Promise<void> {
    this.values.set(key, {
      value,
      expiresAt: ttlToExpiry(ttlMs),
    })
  }

  async setIfNotExists(key: string, value: unknown, ttlMs?: number): Promise<boolean> {
    const existing = await this.get(key)
    if (existing !== null) return false
    await this.set(key, value, ttlMs)
    return true
  }

  async delete(key: string): Promise<void> {
    this.values.delete(key)
    this.lists.delete(key)
  }

  async appendToList(
    key: string,
    value: unknown,
    options?: { maxLength?: number; ttlMs?: number },
  ): Promise<void> {
    const existing = this.lists.get(key)
    const isExistingExpired = existing ? isExpired(existing.expiresAt) : false
    const list = isExistingExpired ? [] : [...(existing?.value ?? [])]
    list.push(value)

    const maxLength = options?.maxLength
    const trimmed =
      maxLength && maxLength > 0 && list.length > maxLength
        ? list.slice(list.length - maxLength)
        : list

    this.lists.set(key, {
      value: trimmed,
      expiresAt: ttlToExpiry(options?.ttlMs),
    })
  }

  async getList<T = unknown>(key: string): Promise<T[]> {
    const entry = this.lists.get(key)
    if (!entry) return []
    if (isExpired(entry.expiresAt)) {
      this.lists.delete(key)
      return []
    }
    return [...entry.value] as T[]
  }

  async enqueue(threadId: string, entry: QueueEntry, maxSize: number): Promise<number> {
    const queue = this.prunedQueue(threadId)
    queue.push(entry)

    if (maxSize > 0 && queue.length > maxSize) {
      queue.splice(0, queue.length - maxSize)
    }

    this.queues.set(threadId, queue)
    return queue.length
  }

  async dequeue(threadId: string): Promise<QueueEntry | null> {
    const queue = this.prunedQueue(threadId)
    const item = queue.shift() ?? null
    this.queues.set(threadId, queue)
    return item
  }

  async queueDepth(threadId: string): Promise<number> {
    const queue = this.prunedQueue(threadId)
    this.queues.set(threadId, queue)
    return queue.length
  }

  private prunedQueue(threadId: string): QueueEntry[] {
    const queue = this.queues.get(threadId) ?? []
    const ts = now()
    return queue.filter((item) => item.expiresAt > ts)
  }
}
