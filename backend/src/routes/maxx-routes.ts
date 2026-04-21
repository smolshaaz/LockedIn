import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import { maxxDomainSchema } from "../schemas/contracts"
import { services } from "../services/container"
import { badRequest } from "../utils/http"

export const maxxRoutes = new Hono()

maxxRoutes.use("*", authMiddleware)

maxxRoutes.get("/:domain", async (c) => {
  const userId = c.get("userId")
  const parsed = maxxDomainSchema.safeParse(c.req.param("domain"))

  if (!parsed.success) {
    return badRequest(c, "Invalid domain")
  }

  const detail = await services.maxx.getDomainDetail(userId, parsed.data)
  return c.json({ detail })
})
