import { describe, expect, it } from "bun:test"
import app from "../src/index"

describe("automation routes", () => {
  it("returns automation health metadata", async () => {
    const response = await app.request("/v1/automation/health")
    expect(response.status).toBe(200)
    const json = await response.json()
    expect(Array.isArray(json.availableKinds)).toBe(true)
  })

  it("runs automation pipeline with default kinds", async () => {
    const response = await app.request("/v1/automation/run", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({}),
    })

    expect(response.status).toBe(200)
    const json = await response.json()
    expect(typeof json.contactsFound).toBe("number")
    expect(typeof json.sent.checkin).toBe("number")
    expect(typeof json.sent.reminder).toBe("number")
    expect(typeof json.sent.streak).toBe("number")
  })
})
