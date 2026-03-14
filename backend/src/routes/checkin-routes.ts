import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import { weeklyCheckinSchema } from "../schemas/contracts"
import { diffCheckin } from "../services/checkin-service"
import { services } from "../services/container"
import { computeLifeScore } from "../services/lifescore-service"
import { badRequest } from "../utils/http"

export const checkinRoutes = new Hono()

checkinRoutes.use("*", authMiddleware)

checkinRoutes.post("/weekly", async (c) => {
  const userId = c.get("userId")
  const body = await c.req.json().catch(() => null)
  const parsed = weeklyCheckinSchema.safeParse(body)

  if (!parsed.success) {
    return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid check-in payload")
  }

  const previous = { ...services.memory.getDomainScores(userId) }
  services.memory.ingestCheckin(userId, parsed.data)
  const progress = diffCheckin(previous, parsed.data)

  const lifeScore = computeLifeScore(
    services.memory.getDomainScores(userId),
    services.memory.recentTrend(userId),
  )

  return c.json({
    progress,
    lifeScore,
  })
})
