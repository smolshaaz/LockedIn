import { Hono } from "hono"
import { authMiddleware } from "../middleware/auth"
import { env, isTestingBootstrapEnabled } from "../config/env"
import { getAIAvailability } from "../integrations/ai-models"
import type { Profile, ProtocolPlan } from "../schemas/contracts"
import { services } from "../services/container"

export const testingRoutes = new Hono()

testingRoutes.use("*", authMiddleware)

function isoWeekStart(offsetWeeks = 0): string {
  const now = new Date()
  const day = now.getUTCDay()
  const diffToMonday = (day + 6) % 7
  const monday = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() - diffToMonday + offsetWeeks * 7,
  ))
  return monday.toISOString().slice(0, 10)
}

function testingProfile(userId: string): Profile {
  return {
    userId,
    name: "Aaryan",
    age: 21,
    goals: [
      "GymMaxx momentum",
      "MindMaxx execution",
      "MoneyMaxx opportunities",
      "FaceMaxx consistency",
      "SocialMaxx confidence",
    ],
    constraints: [
      "College + project workload",
      "Inconsistent routine on high-stress days",
      "Phone distraction after 10pm",
    ],
    communicationStyle: "Firm",
    baseline: {
      gym: 61,
      face: 69,
      money: 66,
      mind: 72,
      social: 57,
    },
    role: "Student",
    primaryGoal: "Fix my life overall",
    requestedMaxxes: ["gym", "mind", "money", "face", "social"],
    onboardingCompleted: true,
    weeklyCheckinDay: "Sunday",
    weeklyCheckinTime: "19:00",
    timezoneId: "Asia/Kolkata",
    preferredWeightUnit: "kg",
    preferredHeightUnit: "cm",
    channelInAppEnabled: true,
    channelTelegramEnabled: false,
    channelDiscordEnabled: false,
    quietHoursEnabled: false,
    quietHoursStart: "23:00",
    quietHoursEnd: "07:00",
    googleConnected: false,
    telegramConnected: false,
    discordConnected: false,
  }
}

function testingPlans(): Array<{ domain: "gym" | "mind" | "money" | "face" | "social"; plan: ProtocolPlan }> {
  return [
    {
      domain: "gym",
      plan: {
        objective: "Increase weekly gym consistency and progressive overload",
        horizonDays: 14,
        steps: [
          {
            title: "Push day compounds",
            action: "Bench + incline + overhead press progression block",
            frequency: "Mon/Thu · 70m",
            reason: "Strength progression and chest/shoulder volume.",
          },
          {
            title: "Leg day anchor",
            action: "Squat + RDL + split squats + calves",
            frequency: "Tue/Fri · 75m",
            reason: "Lower body strength and hormonal response.",
          },
          {
            title: "Protein floor",
            action: "Hit minimum 130g protein and log daily",
            frequency: "Daily",
            reason: "Recovery and muscle gain consistency.",
          },
        ],
        checkpoints: [
          "4 sessions complete this week",
          "Bench +2.5kg if RPE allows",
          "No skipped post-workout meal",
        ],
      },
    },
    {
      domain: "mind",
      plan: {
        objective: "Stabilize deep work and protect sleep rhythm",
        horizonDays: 14,
        steps: [
          {
            title: "Morning deep work block",
            action: "90 minutes no-phone focus block before messages",
            frequency: "Daily",
            reason: "Highest leverage cognitive window.",
          },
          {
            title: "Evening shutdown",
            action: "Screen cutoff at 10:45pm + next-day plan on paper",
            frequency: "Nightly",
            reason: "Protect sleep quality and reduce decision fatigue.",
          },
          {
            title: "Distraction audit",
            action: "Log top 2 attention leaks after work block",
            frequency: "Daily · 3m",
            reason: "Rapid feedback loop on focus failures.",
          },
        ],
        checkpoints: [
          "5 deep-work wins this week",
          "Sleep before 11:30pm at least 5 nights",
          "Distraction trend decreases by Sunday",
        ],
      },
    },
    {
      domain: "money",
      plan: {
        objective: "Build internship/freelance pipeline with consistent outreach",
        horizonDays: 14,
        steps: [
          {
            title: "Targeted applications",
            action: "Submit 2 role-specific applications with tailored pitch",
            frequency: "Daily",
            reason: "Increase interview probability with quality targeting.",
          },
          {
            title: "Portfolio proof asset",
            action: "Ship 1 visible project update and post it publicly",
            frequency: "Weekly",
            reason: "Signal execution and improve profile conversion.",
          },
          {
            title: "Follow-up cycle",
            action: "Send 3 follow-up messages to pending prospects",
            frequency: "Daily · 20m",
            reason: "Most conversions happen on follow-up, not first touch.",
          },
        ],
        checkpoints: [
          "14+ applications submitted",
          "At least 1 strong callback",
          "Portfolio artifact shipped",
        ],
      },
    },
    {
      domain: "face",
      plan: {
        objective: "Lock skincare and presentation consistency",
        horizonDays: 14,
        steps: [
          {
            title: "AM routine",
            action: "Cleanser + moisturizer + SPF",
            frequency: "Daily morning",
            reason: "Core skin barrier and UV protection.",
          },
          {
            title: "PM routine",
            action: "Cleanser + treatment layer + moisturizer",
            frequency: "Daily night",
            reason: "Recovery and texture improvement.",
          },
          {
            title: "Hydration baseline",
            action: "3L water target and nightly compliance check",
            frequency: "Daily",
            reason: "Skin quality and recovery support.",
          },
        ],
        checkpoints: [
          "No skipped SPF days",
          "AM/PM consistency > 80%",
          "Visible reduction in dryness/irritation",
        ],
      },
    },
    {
      domain: "social",
      plan: {
        objective: "Reduce hesitation and increase social reps",
        horizonDays: 14,
        steps: [
          {
            title: "Daily approach rep",
            action: "Initiate one new conversation in a real setting",
            frequency: "Daily",
            reason: "Volume-driven confidence growth.",
          },
          {
            title: "Follow-up touchpoint",
            action: "Send one follow-up text/voice note to existing lead",
            frequency: "Daily",
            reason: "Build continuity and social momentum.",
          },
          {
            title: "Presence drill",
            action: "2-minute posture + eye-contact reset before events",
            frequency: "Daily",
            reason: "Improve first-impression frame and self-regulation.",
          },
        ],
        checkpoints: [
          "7 approach reps logged",
          "Reduced social hesitation score by week end",
          "At least 2 meaningful follow-up threads",
        ],
      },
    },
  ]
}

testingRoutes.post("/bootstrap", async (c) => {
  if (env.NODE_ENV === "production" || !isTestingBootstrapEnabled) {
    return c.json({ error: "Testing bootstrap is disabled." }, 404)
  }

  const userId = c.get("userId")
  const existing = await services.memory.getProfile(userId)

  if (existing?.onboardingCompleted) {
    const queue = await services.memory.getHomeTaskQueue(userId)
    if (queue.activeTasks.length >= 5) {
      return c.json({
        mode: "testing",
        profile: existing,
        seeded: false,
      })
    }
  }

  const profile = testingProfile(userId)
  await services.memory.setProfile(userId, profile)

  await services.memory.recordLifeScoreSnapshot(userId, isoWeekStart(0), 68)
  await services.memory.recordLifeScoreSnapshot(userId, isoWeekStart(-1), 65)
  await services.memory.recordLifeScoreSnapshot(userId, isoWeekStart(-2), 63)
  await services.memory.recordLifeScoreSnapshot(userId, isoWeekStart(-3), 61)

  const plans = testingPlans()

  for (const { domain, plan } of plans) {
    const sync = await services.memory.createTasksFromProtocol({
      userId,
      plan,
      domain,
    })

    for (const draft of sync.createdDrafts) {
      await services.memory.decideDraftTask({
        userId,
        taskId: draft.id,
        decision: "approve",
        actor: "system",
      })
    }
  }

  const gymTasks = await services.memory.getProtocolTasks(userId, "gym")
  if (gymTasks.length > 0) {
    await services.memory.recordTaskEvent({
      userId,
      taskId: gymTasks[0].id,
      action: "completed",
      actor: "system",
    })
  }

  const refreshed = await services.memory.getProfile(userId)
  return c.json({
    mode: "testing",
    profile: refreshed,
    seeded: true,
  })
})

testingRoutes.get("/ai-availability", (c) => {
  return c.json({
    mode: "testing",
    availability: getAIAvailability(),
  })
})
