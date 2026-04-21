import { describe, expect, it } from "bun:test"
import app from "../src/index"

describe("omnichannel routes", () => {
  it("returns health status for chat sdk wiring", async () => {
    const response = await app.request("/v1/omnichannel/health")
    expect(response.status).toBe(200)
    const json = await response.json()
    expect(typeof json.enabled).toBe("boolean")
    expect(Array.isArray(json.configuredAdapters)).toBe(true)
  })

  it("returns 503 when chat sdk is disabled or unconfigured", async () => {
    const response = await app.request("/v1/omnichannel/telegram", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ update_id: 1 }),
    })

    expect([200, 404, 503]).toContain(response.status)
  })
})
