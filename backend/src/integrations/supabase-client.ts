import { createClient, type SupabaseClient } from "@supabase/supabase-js"
import { env, hasSupabaseConfig, isPersistenceMirror } from "../config/env"

let adminClient: SupabaseClient | null = null
let warned = false

export function getSupabaseAdminClient(): SupabaseClient | null {
  if (adminClient) {
    return adminClient
  }

  if (!isPersistenceMirror || !hasSupabaseConfig) {
    if (!warned && isPersistenceMirror) {
      warned = true
      console.warn(
        "[persistence] Supabase client not initialized. Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.",
      )
    }
    return null
  }

  adminClient = createClient(env.SUPABASE_URL as string, env.SUPABASE_SERVICE_ROLE_KEY as string, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  })

  return adminClient
}
