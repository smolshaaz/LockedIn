import { Hono } from "hono"
import { z } from "zod"
import { automationConfig, hasAutomationSecret } from "../config/env"
import {
  engagementAutomationKinds,
  runEngagementAutomation,
} from "../services/engagement-automation-service"
import { unauthorized } from "../utils/http"

const automationRunSchema = z.object({
  kinds: z.array(z.enum(engagementAutomationKinds)).min(1).optional(),
})

export const automationRoutes = new Hono()

automationRoutes.post("/run", async (c) => {
  if (hasAutomationSecret) {
    const incoming = c.req.header("x-automation-secret")
    if (!incoming || incoming !== automationConfig.secret) {
      return unauthorized(c)
    }
  }

  const body = await c.req.json().catch(() => ({}))
  const parsed = automationRunSchema.safeParse(body)
  if (!parsed.success) {
    return c.json(
      {
        error: parsed.error.issues[0]?.message ?? "Invalid automation payload",
      },
      400,
    )
  }

  const report = await runEngagementAutomation(parsed.data.kinds)
  return c.json(report)
})

automationRoutes.get("/health", (c) => {
  return c.json({
    hasSecret: hasAutomationSecret,
    availableKinds: engagementAutomationKinds,
  })
})
