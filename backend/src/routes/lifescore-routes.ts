import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import { services } from "../services/container"
import { computeLifeScore } from "../services/lifescore-service"

export const lifeScoreRoutes = new Hono()

lifeScoreRoutes.use("*", authMiddleware)

lifeScoreRoutes.get("/", (c) => {
  const userId = c.get("userId")

  const lifeScore = computeLifeScore(
    services.memory.getDomainScores(userId),
    services.memory.recentTrend(userId),
  )

  return c.json(lifeScore)
})
