import type { MiddlewareHandler } from "hono"
import { isAuthOptional } from "../config/env"
import { unauthorized } from "../utils/http"

declare module "hono" {
  interface ContextVariableMap {
    userId: string
  }
}

export const authMiddleware: MiddlewareHandler = async (c, next) => {
  const header = c.req.header("authorization")
  const fallbackUser = c.req.header("x-user-id")

  if (isAuthOptional) {
    c.set("userId", fallbackUser ?? "dev-user")
    await next()
    return
  }

  if (!header && !fallbackUser) {
    return unauthorized(c)
  }

  if (header?.startsWith("Bearer ")) {
    const token = header.replace("Bearer ", "").trim()
    if (token.length < 8) {
      return unauthorized(c)
    }
    c.set("userId", `supabase:${token.slice(-8)}`)
  } else if (fallbackUser) {
    c.set("userId", fallbackUser)
  } else {
    return unauthorized(c)
  }

  await next()
}
