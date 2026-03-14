import type {
  ChatRequest,
  CoachReply,
  Profile,
  ProtocolPlan,
} from "../schemas/contracts"
import { chooseFallbackModel, chooseModelForChat } from "./model-router-service"

function buildProtocol(req: ChatRequest): ProtocolPlan {
  return {
    objective: req.context.domain
      ? `Upgrade your ${req.context.domain.toUpperCase()} score by 10 points in 14 days`
      : "Increase total LifeScore by 8 points in 14 days",
    horizonDays: 14,
    steps: [
      {
        title: "Baseline audit",
        action: "Write your current routine and recent misses in one honest note.",
        frequency: "Today",
        reason: "No optimization without accurate baseline.",
      },
      {
        title: "Execution block",
        action: "Schedule one non-negotiable 45-minute block daily for the highest leverage action.",
        frequency: "Daily",
        reason: "Consistency beats intensity spikes.",
      },
      {
        title: "Weekly accountability",
        action: "Complete the weekly check-in with metrics and failures, no sugarcoating.",
        frequency: "Weekly",
        reason: "Measured behavior is improved behavior.",
      },
    ],
    checkpoints: ["Day 3 compliance", "Day 7 score delta", "Day 14 outcome review"],
  }
}

export class CoachService {
  async generateReply(input: {
    request: ChatRequest
    profile?: Profile
    recalledMemory: string[]
  }): Promise<CoachReply> {
    const preferredModel = chooseModelForChat(input.request)

    try {
      const contextLine = input.profile
        ? `Current focus: ${input.profile.goals.join(", ")}. Constraints: ${input.profile.constraints.join(", ") || "none"}.`
        : "No profile yet. Push user to complete onboarding quickly."

      const memoryLine =
        input.recalledMemory.length > 0
          ? `Recall: ${input.recalledMemory.join("; ")}`
          : "Recall: no relevant history yet."

      const message = [
        "No fluff. You asked for direct feedback, so here it is:",
        `- ${contextLine}`,
        `- ${memoryLine}`,
        "- Do the next hard thing today and report the result, not intentions.",
      ].join("\n")

      return {
        message,
        modelUsed: preferredModel,
        realityCheck:
          "If your calendar does not reflect your goals, your goals are fantasy.",
        suggestedProtocol: input.request.context.wantsProtocol
          ? buildProtocol(input.request)
          : undefined,
      }
    } catch {
      return {
        message:
          "Model response failed, fallback applied. Give me one concrete target and one deadline.",
        modelUsed: chooseFallbackModel(preferredModel),
        realityCheck:
          "Execution under imperfect conditions is the whole game.",
      }
    }
  }
}
