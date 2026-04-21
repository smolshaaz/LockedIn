import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import { profileSchema, updateProfileSchema } from "../schemas/contracts"
import { services } from "../services/container"
import { badRequest } from "../utils/http"

export const profileRoutes = new Hono()

profileRoutes.use("*", authMiddleware)

profileRoutes.get("/", async (c) => {
  const userId = c.get("userId")
  const profile = await services.memory.getProfile(userId)

  if (!profile) {
    return c.json({ profile: null })
  }

  return c.json({ profile })
})

profileRoutes.get("/export", async (c) => {
  const userId = c.get("userId")
  const exportData = await services.memory.exportUserData(userId)
  return c.json({ exportData })
})

profileRoutes.patch("/", async (c) => {
  const userId = c.get("userId")
  const body = await c.req.json().catch(() => null)
  const parsed = updateProfileSchema.safeParse(body)

  if (!parsed.success) {
    return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid profile payload")
  }

  const updated = await services.memory.mergeProfile(userId, parsed.data)

  if (!updated) {
    return c.json({ error: "Profile not found. Complete onboarding first." }, 404)
  }

  return c.json({ profile: updated })
})

profileRoutes.post("/onboarding", async (c) => {
  const userId = c.get("userId")
  const body = await c.req.json().catch(() => null)
  const parsed = profileSchema.safeParse({
    ...body,
    userId,
  })

  if (!parsed.success) {
    return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid onboarding payload")
  }

  const profile = await services.memory.setProfile(userId, parsed.data)
  return c.json({ profile }, 201)
})

profileRoutes.delete("/", async (c) => {
  const userId = c.get("userId")
  try {
    await services.memory.deleteUserData(userId)
    return c.json({ success: true })
  } catch (error) {
    const detail = error instanceof Error ? error.message : "Failed to delete account data"
    return c.json({ error: detail }, 500)
  }
})
