import "dotenv/config"
import { z } from "zod"

const envSchema = z.object({
  NODE_ENV: z.string().default("development"),
  ANTHROPIC_API_KEY: z.string().optional(),
  OPENAI_API_KEY: z.string().optional(),
  OPENAI_BASE_URL: z.string().url().optional(),
  OPENAI_REFERER: z.string().optional(),
  OPENAI_TITLE: z.string().optional(),
  GOOGLE_GENERATIVE_AI_API_KEY: z.string().optional(),
  LOCK_CHAT_MODEL: z.string().default("google/gemini-2.5-flash"),
  LOCK_FAST_MODEL: z.string().default("google/gemini-2.5-flash"),
  LOCK_EMBEDDING_MODEL: z.string().default("google/gemini-embedding-001"),
  LOCK_AGENT_MAX_STEPS: z.coerce.number().int().positive().default(2),
  CHAT_SDK_ENABLED: z.string().default("false"),
  CHAT_SDK_LOG_LEVEL: z
    .enum(["debug", "info", "warn", "error", "silent"])
    .default("info"),
  CHAT_BOT_USERNAME: z.string().default("lockedin_bot"),
  CHAT_STATE_REDIS_URL: z.string().optional(),
  TELEGRAM_BOT_TOKEN: z.string().optional(),
  TELEGRAM_BOT_USERNAME: z.string().optional(),
  TELEGRAM_WEBHOOK_SECRET_TOKEN: z.string().optional(),
  DISCORD_BOT_TOKEN: z.string().optional(),
  DISCORD_APPLICATION_ID: z.string().optional(),
  DISCORD_PUBLIC_KEY: z.string().optional(),
  DISCORD_BOT_USERNAME: z.string().optional(),
  AUTOMATION_SECRET: z.string().optional(),
  AUTOMATION_CHECKIN_INTERVAL_DAYS: z.coerce.number().int().positive().default(7),
  AUTOMATION_REMINDER_COOLDOWN_HOURS: z.coerce.number().int().positive().default(24),
  AUTOMATION_STREAK_NUDGE_COOLDOWN_HOURS: z.coerce.number().int().positive().default(24),
  ENABLE_TESTING_BOOTSTRAP: z.string().default("false"),
  SUPABASE_URL: z.string().url().optional(),
  SUPABASE_ANON_KEY: z.string().optional(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().optional(),
  UPSTASH_REDIS_REST_URL: z.string().url().optional(),
  UPSTASH_REDIS_REST_TOKEN: z.string().optional(),
  THREAD_STATE_TTL_SECONDS: z.coerce.number().int().positive().default(60 * 60 * 24 * 7),
  EMBEDDING_DIMENSIONS: z.coerce.number().int().positive().default(1536),
  PERSISTENCE_MODE: z.enum(["memory", "mirror"]).default("memory"),
  MODEL_TIMEOUT_MS: z.coerce.number().int().positive().default(12000),
  AUTH_MODE: z.enum(["required", "optional"]).default("optional"),
})

export const env = envSchema.parse(process.env)

export const isAuthOptional = env.AUTH_MODE === "optional"
export const isPersistenceMirror = env.PERSISTENCE_MODE === "mirror"
const placeholderFragments = [
  "your-",
  "example",
  "replace-me",
  "changeme",
  "<",
  ">",
]

function looksConfigured(value?: string) {
  if (!value) return false
  const normalized = value.trim().toLowerCase()
  if (!normalized) return false
  return !placeholderFragments.some((fragment) => normalized.includes(fragment))
}

function asBoolean(value: string): boolean {
  const normalized = value.trim().toLowerCase()
  return (
    normalized === "1" ||
    normalized === "true" ||
    normalized === "yes" ||
    normalized === "on"
  )
}

const isTestEnv = env.NODE_ENV === "test"

export const hasAnthropicKey = !isTestEnv && looksConfigured(env.ANTHROPIC_API_KEY)
export const hasOpenAIKey = !isTestEnv && looksConfigured(env.OPENAI_API_KEY)
export const hasGoogleKey = !isTestEnv && looksConfigured(env.GOOGLE_GENERATIVE_AI_API_KEY)
export const isChatSdkEnabled = asBoolean(env.CHAT_SDK_ENABLED)
export const hasChatStateRedisConfig = looksConfigured(env.CHAT_STATE_REDIS_URL)
export const hasTelegramConfig = looksConfigured(env.TELEGRAM_BOT_TOKEN)
export const hasDiscordConfig =
  looksConfigured(env.DISCORD_BOT_TOKEN) &&
  looksConfigured(env.DISCORD_APPLICATION_ID) &&
  looksConfigured(env.DISCORD_PUBLIC_KEY)
export const hasAutomationSecret = looksConfigured(env.AUTOMATION_SECRET)
export const isTestingBootstrapEnabled =
  asBoolean(env.ENABLE_TESTING_BOOTSTRAP) || env.NODE_ENV === "test"

export const aiConfig = {
  lockChatModel: env.LOCK_CHAT_MODEL,
  lockFastModel: env.LOCK_FAST_MODEL,
  lockEmbeddingModel: env.LOCK_EMBEDDING_MODEL,
  lockAgentMaxSteps: env.LOCK_AGENT_MAX_STEPS,
}

export const chatSdkConfig = {
  enabled: isChatSdkEnabled,
  logLevel: env.CHAT_SDK_LOG_LEVEL,
  botUserName: env.CHAT_BOT_USERNAME,
  stateRedisUrl: env.CHAT_STATE_REDIS_URL,
  telegram: {
    botToken: env.TELEGRAM_BOT_TOKEN,
    botUserName: env.TELEGRAM_BOT_USERNAME,
    webhookSecretToken: env.TELEGRAM_WEBHOOK_SECRET_TOKEN,
  },
  discord: {
    botToken: env.DISCORD_BOT_TOKEN,
    applicationId: env.DISCORD_APPLICATION_ID,
    publicKey: env.DISCORD_PUBLIC_KEY,
    botUserName: env.DISCORD_BOT_USERNAME,
  },
}

export const automationConfig = {
  secret: env.AUTOMATION_SECRET,
  checkinIntervalDays: env.AUTOMATION_CHECKIN_INTERVAL_DAYS,
  reminderCooldownHours: env.AUTOMATION_REMINDER_COOLDOWN_HOURS,
  streakNudgeCooldownHours: env.AUTOMATION_STREAK_NUDGE_COOLDOWN_HOURS,
}

export const hasSupabaseConfig =
  !isTestEnv && looksConfigured(env.SUPABASE_URL) && looksConfigured(env.SUPABASE_SERVICE_ROLE_KEY)
export const hasUpstashConfig =
  !isTestEnv &&
  looksConfigured(env.UPSTASH_REDIS_REST_URL) &&
  looksConfigured(env.UPSTASH_REDIS_REST_TOKEN)
