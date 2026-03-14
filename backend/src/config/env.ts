import { z } from "zod"

const envSchema = z.object({
  NODE_ENV: z.string().default("development"),
  REDIS_URL: z.string().optional(),
  SUPABASE_URL: z.string().url().optional(),
  SUPABASE_ANON_KEY: z.string().optional(),
  MODEL_TIMEOUT_MS: z.coerce.number().int().positive().default(12000),
  AUTH_MODE: z.enum(["required", "optional"]).default("optional"),
})

export const env = envSchema.parse(process.env)

export const isAuthOptional = env.AUTH_MODE === "optional"
