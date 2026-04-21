import { Redis } from "@upstash/redis"
import { env, hasUpstashConfig, isPersistenceMirror } from "../config/env"

let redisClient: Redis | null = null
let warned = false

export function getRedisClient(): Redis | null {
  if (redisClient) {
    return redisClient
  }

  if (!isPersistenceMirror || !hasUpstashConfig) {
    if (!warned && isPersistenceMirror) {
      warned = true
      console.warn(
        "[persistence] Upstash Redis client not initialized. Missing UPSTASH_REDIS_REST_URL or UPSTASH_REDIS_REST_TOKEN.",
      )
    }
    return null
  }

  redisClient = new Redis({
    url: env.UPSTASH_REDIS_REST_URL as string,
    token: env.UPSTASH_REDIS_REST_TOKEN as string,
  })

  return redisClient
}
