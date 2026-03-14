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
  const needsDeepWork =
    req.context.wantsProtocol ||
    message.includes("plan") ||
    message.includes("roadmap") ||
    message.includes("strategy")

  return needsDeepWork ? "sonnet" : "haiku"
}

export function chooseFallbackModel(model: ModelName): ModelName {
  return model === "sonnet" ? "haiku" : "sonnet"
}
