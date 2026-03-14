import { describe, expect, it } from "bun:test"
import app from "../src/index"

describe("api integration", () => {
  it("supports onboarding, weekly check-in, and lifescore retrieval", async () => {
    const headers = {
      "Content-Type": "application/json",
      "X-User-Id": "integration-user",
    }

    const onboarding = await app.request("/v1/profile/onboarding", {
      method: "POST",
      headers,
      body: JSON.stringify({
        name: "Alex",
        goals: ["Build discipline"],
        constraints: ["College schedule"],
        communicationStyle: "blunt",
        baseline: {
          gym: 55,
          face: 50,
          money: 45,
          mind: 60,
          social: 52,
        },
      }),
    })

    expect(onboarding.status).toBe(201)

    const checkin = await app.request("/v1/checkins/weekly", {
      method: "POST",
      headers,
      body: JSON.stringify({
        weekStart: "2026-03-09",
        entries: [
          { domain: "gym", score: 62, notes: "3 lifting sessions" },
          { domain: "mind", score: 67, notes: "Sleep improved" },
        ],
      }),
    })

    expect(checkin.status).toBe(200)
    const checkinBody = (await checkin.json()) as { lifeScore: { totalScore: number } }
    expect(checkinBody.lifeScore.totalScore).toBeGreaterThan(0)

    const lifeScore = await app.request("/v1/lifescore", {
      method: "GET",
      headers,
    })

    expect(lifeScore.status).toBe(200)
  })

  it("returns structured coach reply", async () => {
    const response = await app.request("/v1/chat", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-User-Id": "chat-user",
      },
      body: JSON.stringify({
        threadId: "main",
        message: "I need a 14-day roadmap for focus",
        context: {
          wantsProtocol: true,
          urgency: "normal",
          domain: "mind",
        },
      }),
    })

    expect(response.status).toBe(200)
    const body = (await response.json()) as {
      message: string
      suggestedProtocol?: { horizonDays: number }
    }

    expect(body.message.length).toBeGreaterThan(10)
    expect(body.suggestedProtocol?.horizonDays).toBe(14)
  })
})
