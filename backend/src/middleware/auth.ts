import type { MiddlewareHandler } from "hono"
import { isAuthOptional } from "../config/env"
import { services } from "../services/container"
import { unauthorized } from "../utils/http"

declare module "hono" {
  interface ContextVariableMap {
    userId: string
  }
}

export const authMiddleware: MiddlewareHandler = async (c, next) => {
  const header = c.req.header("authorization")
  const fallbackUser = c.req.header("x-user-id")
  const resolvedFromBearer = await services.auth.verifyToken(header)

  if (isAuthOptional) {
    c.set("userId", fallbackUser ?? resolvedFromBearer ?? "dev-user")
    await next()
    return
  }

  if (!resolvedFromBearer) {
    return unauthorized(c)
  }

  c.set("userId", resolvedFromBearer)

  await next()
}
