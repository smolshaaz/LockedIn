import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import {
  maxxDomainSchema,
  taskDraftDecisionSchema,
  taskEventRequestSchema,
  taskMutationRequestSchema,
} from "../schemas/contracts"
import { services } from "../services/container"
import { badRequest, notFound } from "../utils/http"

export const taskRoutes = new Hono()

taskRoutes.use("*", authMiddleware)

taskRoutes.get("/", async (c) => {
  const userId = c.get("userId")
  const snapshot = await services.memory.getTaskSnapshot(userId)
  return c.json({ snapshot })
})

taskRoutes.get("/home", async (c) => {
  const userId = c.get("userId")
  const queue = await services.memory.getHomeTaskQueue(userId)
  return c.json({ queue })
})

taskRoutes.get("/drafts", async (c) => {
  const userId = c.get("userId")
  const tasks = await services.memory.getDraftTasks(userId)
  return c.json({ tasks })
})

taskRoutes.get("/protocol/:domain", async (c) => {
  const userId = c.get("userId")
  const parsed = maxxDomainSchema.safeParse(c.req.param("domain"))

  if (!parsed.success) {
    return badRequest(c, "Invalid domain")
  }

  const tasks = await services.memory.getProtocolTasks(userId, parsed.data)
  return c.json({
    domain: parsed.data,
    tasks,
  })
})

taskRoutes.post("/mutate", async (c) => {
  const userId = c.get("userId")
  const body = await c.req.json().catch(() => null)
  const parsed = taskMutationRequestSchema.safeParse(body)

  if (!parsed.success) {
    return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid task mutation")
  }

  const mutation = await services.memory.mutateTask({
    userId,
    ...parsed.data,
  })

  if (mutation.status === "not_found") {
    return notFound(c, "Task not found")
  }

  if (mutation.status === "invalid_state") {
    return badRequest(c, "Task is not in a valid state for this action")
  }

  return c.json({
    task: mutation.task ?? null,
    snapshot: mutation.snapshot,
    idempotent: mutation.idempotent,
    status: mutation.status,
  })
})

taskRoutes.post("/:taskId/events", async (c) => {
  const userId = c.get("userId")
  const taskId = c.req.param("taskId")
  const body = await c.req.json().catch(() => null)
  const parsed = taskEventRequestSchema.safeParse(body)

  if (!parsed.success) {
    return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid task event")
  }

  const updated = await services.memory.recordTaskEvent({
    userId,
    taskId,
    action: parsed.data.action,
    actor: "user",
  })

  if (!updated) {
    return notFound(c, "Task not found or not active")
  }

  return c.json({ task: updated })
})

taskRoutes.post("/drafts/:taskId/decision", async (c) => {
  const userId = c.get("userId")
  const taskId = c.req.param("taskId")
  const body = await c.req.json().catch(() => null)
  const parsed = taskDraftDecisionSchema.safeParse(body)

  if (!parsed.success) {
    return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid draft decision")
  }

  const updated = await services.memory.decideDraftTask({
    userId,
    taskId,
    decision: parsed.data.decision,
    actor: "user",
  })

  if (!updated) {
    return notFound(c, "Draft task not found")
  }

  return c.json({ task: updated })
})
