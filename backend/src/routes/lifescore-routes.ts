import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import { services } from "../services/container"
import { computeLifeScore } from "../services/lifescore-service"

export const lifeScoreRoutes = new Hono()

lifeScoreRoutes.use("*", authMiddleware)

lifeScoreRoutes.get("/", async (c) => {
  const userId = c.get("userId")

  const lifeScore = computeLifeScore(
    await services.memory.getDomainScores(userId),
    await services.memory.recentTrend(userId),
  )

  return c.json(lifeScore)
})
