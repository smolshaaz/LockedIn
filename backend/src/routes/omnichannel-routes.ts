import { Hono } from "hono"
import {
  getOmnichannelStatus,
  handleOmnichannelWebhook,
} from "../services/omnichannel-chat-service"

export const omnichannelRoutes = new Hono()

omnichannelRoutes.get("/health", (c) => {
  return c.json(getOmnichannelStatus())
})

omnichannelRoutes.post("/telegram", async (c) => {
  return handleOmnichannelWebhook("telegram", c.req.raw)
})

omnichannelRoutes.post("/discord", async (c) => {
  return handleOmnichannelWebhook("discord", c.req.raw)
})
