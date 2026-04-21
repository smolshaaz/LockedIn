import type { ChatRequest } from "../schemas/contracts"

export type ModelName = "sonnet" | "haiku"

export function chooseModelForTask(task: "chat" | "checkin" | "summary"): ModelName {
  if (task === "checkin" || task === "summary") {
    return "haiku"
  }
  return "sonnet"
}

export function chooseModelForChat(req: ChatRequest): ModelName {
  const message = req.message.toLowerCase()
  const domainCount =
    req.context.domains?.length ?? (req.context.domain ? 1 : 0)
  const hasHighUrgencyByDomain = Object.values(req.context.urgencyByDomain ?? {}).some(
    (value) => value === "high",
  )
  const needsDeepWork =
    req.context.wantsProtocol ||
    domainCount > 1 ||
    hasHighUrgencyByDomain ||
    message.includes("plan") ||
    message.includes("roadmap") ||
    message.includes("strategy")

  return needsDeepWork ? "sonnet" : "haiku"
}

export function chooseFallbackModel(model: ModelName): ModelName {
  return model === "sonnet" ? "haiku" : "sonnet"
}
