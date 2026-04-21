import type { Context } from "hono"

export function badRequest(c: Context, message: string) {
  return c.json({ error: message }, 400)
}

export function unauthorized(c: Context) {
  return c.json({ error: "Unauthorized" }, 401)
}

export function notFound(c: Context, message = "Not found") {
  return c.json({ error: message }, 404)
}
