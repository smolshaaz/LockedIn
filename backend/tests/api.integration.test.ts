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
    const checkinBody = (await checkin.json()) as {
      lifeScore: {
        totalScore: number
        trend: Array<{ weekStart: string }>
      }
    }
    expect(checkinBody.lifeScore.totalScore).toBeGreaterThan(0)
    expect(checkinBody.lifeScore.trend.some((point) => point.weekStart === "2026-03-09")).toBe(
      true,
    )

    const lifeScore = await app.request("/v1/lifescore", {
      method: "GET",
      headers,
    })

    expect(lifeScore.status).toBe(200)
  })

  it("uses domain context note objective in maxx detail after profile patch", async () => {
    const headers = {
      "Content-Type": "application/json",
      "X-User-Id": "maxx-objective-user",
    }

    const onboarding = await app.request("/v1/profile/onboarding", {
      method: "POST",
      headers,
      body: JSON.stringify({
        name: "Jordan",
        goals: ["Improve focus and execution in mind domain"],
        constraints: ["Packed class schedule"],
        communicationStyle: "firm",
        baseline: {
          gym: 50,
          face: 50,
          money: 50,
          mind: 50,
          social: 50,
        },
      }),
    })
    expect(onboarding.status).toBe(201)

    const patch = await app.request("/v1/profile", {
      method: "PATCH",
      headers,
      body: JSON.stringify({
        maxxContextNotes: {
          mind: "Ship one 90-minute deep work sprint before noon every day.",
        },
      }),
    })
    expect(patch.status).toBe(200)

    const detail = await app.request("/v1/maxx/mind", {
      method: "GET",
      headers,
    })
    expect(detail.status).toBe(200)

    const detailBody = (await detail.json()) as {
      detail: {
        objective: string
      }
    }

    expect(detailBody.detail.objective).toBe(
      "Ship one 90-minute deep work sprint before noon every day.",
    )
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

  it("keeps unified task state synced between drafts, protocol, and home projections", async () => {
    const headers = {
      "Content-Type": "application/json",
      "X-User-Id": "task-user",
    }

    const chat = await app.request("/v1/chat", {
      method: "POST",
      headers,
      body: JSON.stringify({
        threadId: "main",
        message: "Build me a weekly protocol for focus",
        context: {
          wantsProtocol: true,
          urgency: "normal",
          domain: "mind",
        },
      }),
    })

    expect(chat.status).toBe(200)
    const chatBody = (await chat.json()) as {
      taskSync?: {
        createdDrafts: Array<{ id: string }>
      }
    }

    const firstDraftId = chatBody.taskSync?.createdDrafts[0]?.id
    expect(typeof firstDraftId).toBe("string")
    if (!firstDraftId) {
      throw new Error("Expected at least one draft task from protocol sync")
    }

    const drafts = await app.request("/v1/tasks/drafts", {
      method: "GET",
      headers,
    })

    expect(drafts.status).toBe(200)

    const approve = await app.request(`/v1/tasks/drafts/${firstDraftId}/decision`, {
      method: "POST",
      headers,
      body: JSON.stringify({ decision: "approve" }),
    })

    expect(approve.status).toBe(200)

    const protocol = await app.request("/v1/tasks/protocol/mind", {
      method: "GET",
      headers,
    })

    expect(protocol.status).toBe(200)
    const protocolBody = (await protocol.json()) as {
      tasks: Array<{ id: string }>
    }
    expect(protocolBody.tasks.some((task) => task.id === firstDraftId)).toBe(true)

    const complete = await app.request(`/v1/tasks/${firstDraftId}/events`, {
      method: "POST",
      headers,
      body: JSON.stringify({ action: "completed" }),
    })

    expect(complete.status).toBe(200)

    const home = await app.request("/v1/tasks/home", {
      method: "GET",
      headers,
    })

    expect(home.status).toBe(200)
    const homeBody = (await home.json()) as {
      queue: {
        latestCompleted?: { id: string }
        activeTasks: Array<{ id: string }>
      }
    }
    expect(homeBody.queue.latestCompleted?.id).toBe(firstDraftId)
    expect(homeBody.queue.activeTasks.some((task) => task.id === firstDraftId)).toBe(false)
  })

  it("streams chat responses through the SSE endpoint", async () => {
    const response = await app.request("/v1/chat/stream", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-User-Id": "stream-user",
      },
      body: JSON.stringify({
        threadId: "main",
        message: "Give me one direct action for today",
        context: {
          wantsProtocol: false,
          urgency: "normal",
        },
      }),
    })

    expect(response.status).toBe(200)
    expect(response.headers.get("content-type")).toContain("text/event-stream")

    const body = await response.text()
    expect(body.includes("event: token")).toBe(true)
    expect(body.includes("event: done")).toBe(true)
  })

  it("supports unified task mutate endpoint with idempotency", async () => {
    const headers = {
      "Content-Type": "application/json",
      "X-User-Id": "mutate-user",
    }

    const createKey = "mutate-create-key-0001"
    const create = await app.request("/v1/tasks/mutate", {
      method: "POST",
      headers,
      body: JSON.stringify({
        idempotencyKey: createKey,
        action: "create",
        domain: "mind",
        title: "Deep work block",
        subtitle: "90 minutes no notifications",
        estimate: "90m",
        priority: 1,
        source: "manual",
        actor: "user",
      }),
    })

    expect(create.status).toBe(200)
    const createdBody = (await create.json()) as {
      idempotent: boolean
      status: string
      task?: { id: string }
    }

    expect(createdBody.idempotent).toBe(false)
    expect(createdBody.status).toBe("created")
    expect(typeof createdBody.task?.id).toBe("string")
    if (!createdBody.task?.id) {
      throw new Error("Expected task id from create mutation")
    }

    const createReplay = await app.request("/v1/tasks/mutate", {
      method: "POST",
      headers,
      body: JSON.stringify({
        idempotencyKey: createKey,
        action: "create",
        domain: "mind",
        title: "Deep work block",
        subtitle: "90 minutes no notifications",
      }),
    })

    expect(createReplay.status).toBe(200)
    const createReplayBody = (await createReplay.json()) as {
      idempotent: boolean
      task?: { id: string }
    }
    expect(createReplayBody.idempotent).toBe(true)
    expect(createReplayBody.task?.id).toBe(createdBody.task.id)

    const completeKey = "mutate-complete-key-0001"
    const complete = await app.request("/v1/tasks/mutate", {
      method: "POST",
      headers,
      body: JSON.stringify({
        idempotencyKey: completeKey,
        action: "complete",
        taskId: createdBody.task.id,
        actor: "user",
      }),
    })

    expect(complete.status).toBe(200)
    const completedBody = (await complete.json()) as {
      idempotent: boolean
      status: string
      task?: { isCompleted: boolean }
    }
    expect(completedBody.idempotent).toBe(false)
    expect(completedBody.status).toBe("ok")
    expect(completedBody.task?.isCompleted).toBe(true)

    const completeReplay = await app.request("/v1/tasks/mutate", {
      method: "POST",
      headers,
      body: JSON.stringify({
        idempotencyKey: completeKey,
        action: "complete",
        taskId: createdBody.task.id,
        actor: "user",
      }),
    })

    expect(completeReplay.status).toBe(200)
    const completeReplayBody = (await completeReplay.json()) as {
      idempotent: boolean
      task?: { isCompleted: boolean }
    }
    expect(completeReplayBody.idempotent).toBe(true)
    expect(completeReplayBody.task?.isCompleted).toBe(true)
  })
})
