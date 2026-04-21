import { describe, expect, it } from "bun:test"
import { MemoryService } from "../src/services/memory-service"

describe("memory-service", () => {
  it("stores and recalls check-in facts", async () => {
    const memory = new MemoryService()

    await memory.ingestCheckin("u1", {
      weekStart: "2026-03-09",
      entries: [
        { domain: "gym", score: 78, notes: "Hit progressive overload" },
        { domain: "mind", score: 66, notes: "Sleep improved to 7h" },
      ],
    })

    const recall = await memory.recall("u1", "sleep", 5)
    expect(recall.length).toBeGreaterThan(0)
  })

  it("keeps thread state bounded", async () => {
    const memory = new MemoryService()

    for (let i = 0; i < 15; i++) {
      await memory.appendChatTurn(
        "u2",
        { threadId: "thread", message: `msg-${i}`, context: { wantsProtocol: false, urgency: "normal" } },
        `reply-${i}`,
      )
    }

    const recall = await memory.recall("u2", "msg", 50)
    expect(recall.length).toBeGreaterThan(0)
  })

  it("uses append-only task events and keeps home/protocol state in sync", async () => {
    const memory = new MemoryService()

    const sync = await memory.createTasksFromProtocol({
      userId: "u3",
      domain: "mind",
      plan: {
        objective: "Improve focus",
        horizonDays: 14,
        steps: [
          {
            title: "Baseline audit",
            action: "Write what is currently failing.",
            frequency: "Today",
            reason: "Need truthful baseline.",
          },
          {
            title: "Execution block",
            action: "Protect one non-negotiable deep work block.",
            frequency: "Daily",
            reason: "Consistency compounds.",
          },
          {
            title: "Weekly accountability",
            action: "Submit weekly check-in with metrics.",
            frequency: "Weekly",
            reason: "Measured behavior improves.",
          },
        ],
        checkpoints: ["Day 3", "Day 7", "Day 14"],
      },
    })

    expect(sync.createdDrafts.length).toBe(3)
    expect(sync.autoActivated.length).toBe(0)

    const firstDraft = sync.createdDrafts[0]
    const approved = await memory.decideDraftTask({
      userId: "u3",
      taskId: firstDraft.id,
      decision: "approve",
    })
    expect(approved?.state).toBe("active")

    const completed = await memory.recordTaskEvent({
      userId: "u3",
      taskId: firstDraft.id,
      action: "completed",
    })
    expect(completed?.isCompleted).toBe(true)

    const reopened = await memory.recordTaskEvent({
      userId: "u3",
      taskId: firstDraft.id,
      action: "reopened",
    })
    expect(reopened?.isCompleted).toBe(false)

    const events = await memory.getTaskEvents("u3", firstDraft.id)
    expect(events.some((event) => event.action === "completed")).toBe(true)
    expect(events.some((event) => event.action === "reopened")).toBe(true)
  })

  it("auto-activates low and medium risk tasks after trust threshold", async () => {
    const memory = new MemoryService()

    const createPlan = () => ({
      objective: "Improve focus",
      horizonDays: 14,
      steps: [
        {
          title: "Baseline audit",
          action: "Write what is currently failing.",
          frequency: "Today",
          reason: "Need truthful baseline.",
        },
        {
          title: "Execution block",
          action: "Protect one non-negotiable deep work block.",
          frequency: "Daily",
          reason: "Consistency compounds.",
        },
        {
          title: "Weekly accountability",
          action: "Submit weekly check-in with metrics.",
          frequency: "Weekly",
          reason: "Measured behavior improves.",
        },
      ],
      checkpoints: ["Day 3", "Day 7", "Day 14"],
    })

    const firstSync = await memory.createTasksFromProtocol({
      userId: "u4",
      domain: "mind",
      plan: createPlan(),
    })

    for (const draft of firstSync.createdDrafts) {
      await memory.decideDraftTask({
        userId: "u4",
        taskId: draft.id,
        decision: "approve",
      })
    }

    const secondSync = await memory.createTasksFromProtocol({
      userId: "u4",
      domain: "mind",
      plan: createPlan(),
    })

    expect(secondSync.trustScore).toBeGreaterThan(0.75)
    expect(secondSync.autoActivated.length).toBeGreaterThan(0)
  })
})
