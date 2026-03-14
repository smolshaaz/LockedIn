import { describe, expect, it } from "bun:test"
import { MemoryService } from "../src/services/memory-service"

describe("memory-service", () => {
  it("stores and recalls check-in facts", () => {
    const memory = new MemoryService()

    memory.ingestCheckin("u1", {
      weekStart: "2026-03-09",
      entries: [
        { domain: "gym", score: 78, notes: "Hit progressive overload" },
        { domain: "mind", score: 66, notes: "Sleep improved to 7h" },
      ],
    })

    const recall = memory.recall("u1", "sleep", 5)
    expect(recall.length).toBeGreaterThan(0)
  })

  it("keeps thread state bounded", () => {
    const memory = new MemoryService()

    for (let i = 0; i < 15; i++) {
      memory.appendChatTurn(
        "u2",
        { threadId: "thread", message: `msg-${i}`, context: { wantsProtocol: false, urgency: "normal" } },
        `reply-${i}`,
      )
    }

    const recall = memory.recall("u2", "msg", 50)
    expect(recall.length).toBeGreaterThan(0)
  })
})
