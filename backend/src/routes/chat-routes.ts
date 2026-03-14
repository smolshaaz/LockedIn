import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import { chatRequestSchema } from "../schemas/contracts"
import { services } from "../services/container"
import { badRequest } from "../utils/http"

export const chatRoutes = new Hono()

chatRoutes.use("*", authMiddleware)

chatRoutes.post("/", async (c) => {
  const userId = c.get("userId")
  const body = await c.req.json().catch(() => null)
  const parsed = chatRequestSchema.safeParse(body)

  if (!parsed.success) {
    return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid chat payload")
  }

  const profile = services.memory.getProfile(userId)
  const recalled = services.memory.recall(userId, parsed.data.message)
  const reply = await services.coach.generateReply({
    request: parsed.data,
    profile,
    recalledMemory: recalled,
  })

  services.memory.appendChatTurn(userId, parsed.data, reply.message)

  return c.json(reply)
})
