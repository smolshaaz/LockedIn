import { createAnthropic } from "@ai-sdk/anthropic"
import { createGoogleGenerativeAI } from "@ai-sdk/google"
import { createOpenAI } from "@ai-sdk/openai"
import type { EmbeddingModel, LanguageModel } from "ai"
import {
  aiConfig,
  env,
  hasAnthropicKey,
  hasGoogleKey,
  hasOpenAIKey,
} from "../config/env"
import type { ModelName } from "../services/model-router-service"

export type SupportedProvider = "anthropic" | "openai" | "google" | "openrouter"

export type ResolveReason =
  | "missing_key"
  | "invalid_model_ref"
  | "unsupported_provider"
  | "provider_unavailable"

type ResolveError = {
  ok: false
  reason: ResolveReason
  detail: string
}

type ParsedModelRef =
  | {
      ok: true
      provider: SupportedProvider
      modelId: string
    }
  | ResolveError

export type LanguageModelResolution =
  | {
      ok: true
      alias: ModelName
      provider: SupportedProvider
      modelId: string
      model: LanguageModel
    }
  | (ResolveError & { alias: ModelName })

export type EmbeddingModelResolution =
  | {
      ok: true
      provider: SupportedProvider
      modelId: string
      model: EmbeddingModel
    }
  | ResolveError

type Availability = {
  ok: boolean
  provider?: SupportedProvider
  modelId?: string
  reason?: ResolveReason
  detail?: string
}

const anthropicClient = hasAnthropicKey
  ? createAnthropic({ apiKey: env.ANTHROPIC_API_KEY as string })
  : null
const openaiClient = hasOpenAIKey
  ? createOpenAI({
      apiKey: env.OPENAI_API_KEY as string,
      baseURL: env.OPENAI_BASE_URL,
      headers: {
        ...(env.OPENAI_REFERER ? { "HTTP-Referer": env.OPENAI_REFERER } : {}),
        ...(env.OPENAI_TITLE ? { "X-Title": env.OPENAI_TITLE } : {}),
      },
    })
  : null
const openRouterClient = hasOpenAIKey
  ? createOpenAI({
      apiKey: env.OPENAI_API_KEY as string,
      baseURL: env.OPENAI_BASE_URL || "https://openrouter.ai/api/v1",
      headers: {
        ...(env.OPENAI_REFERER ? { "HTTP-Referer": env.OPENAI_REFERER } : {}),
        ...(env.OPENAI_TITLE ? { "X-Title": env.OPENAI_TITLE } : {}),
      },
    })
  : null
const googleClient = hasGoogleKey
  ? createGoogleGenerativeAI({
      apiKey: env.GOOGLE_GENERATIVE_AI_API_KEY as string,
    })
  : null

export function parseModelRef(raw: string): ParsedModelRef {
  const value = raw.trim()
  if (!value) {
    return {
      ok: false,
      reason: "invalid_model_ref",
      detail: "Model reference is empty. Expected format: provider/model-id",
    }
  }

  const slash = value.indexOf("/")
  if (slash <= 0 || slash >= value.length - 1) {
    return {
      ok: false,
      reason: "invalid_model_ref",
      detail: `Model reference "${value}" must be provider/model-id`,
    }
  }

  const provider = value.slice(0, slash).toLowerCase()
  const modelId = value.slice(slash + 1).trim()
  if (!modelId) {
    return {
      ok: false,
      reason: "invalid_model_ref",
      detail: `Model reference "${value}" is missing model id`,
    }
  }

  if (
    provider !== "anthropic" &&
    provider !== "openai" &&
    provider !== "google" &&
    provider !== "openrouter"
  ) {
    return {
      ok: false,
      reason: "unsupported_provider",
      detail: `Provider "${provider}" is not supported`,
    }
  }

  return {
    ok: true,
    provider,
    modelId,
  }
}

function modelRefForAlias(alias: ModelName): string {
  if (alias === "sonnet") return aiConfig.lockChatModel
  return aiConfig.lockFastModel
}

function languageModelFromProvider(
  provider: SupportedProvider,
  modelId: string,
): LanguageModel {
  if (provider === "anthropic") {
    return (anthropicClient as NonNullable<typeof anthropicClient>)(modelId)
  }
  if (provider === "google") {
    return (googleClient as NonNullable<typeof googleClient>)(modelId)
  }
  if (provider === "openrouter") {
    return (openRouterClient as NonNullable<typeof openRouterClient>)(modelId)
  }
  return (openaiClient as NonNullable<typeof openaiClient>)(modelId)
}

export function resolveLanguageModel(alias: ModelName): LanguageModelResolution {
  const modelRef = modelRefForAlias(alias)
  const parsed = parseModelRef(modelRef)
  if (!parsed.ok) {
    return { ...parsed, alias }
  }

  if (parsed.provider === "anthropic" && !anthropicClient) {
    return {
      ok: false,
      alias,
      reason: "missing_key",
      detail: "Anthropic model requested but ANTHROPIC_API_KEY is missing",
    }
  }

  if (parsed.provider === "openai" && !openaiClient) {
    return {
      ok: false,
      alias,
      reason: "missing_key",
      detail: "OpenAI model requested but OPENAI_API_KEY is missing",
    }
  }

  if (parsed.provider === "openrouter" && !openRouterClient) {
    return {
      ok: false,
      alias,
      reason: "missing_key",
      detail: "OpenRouter model requested but OPENAI_API_KEY is missing",
    }
  }

  if (parsed.provider === "google" && !googleClient) {
    return {
      ok: false,
      alias,
      reason: "missing_key",
      detail: "Google model requested but GOOGLE_GENERATIVE_AI_API_KEY is missing",
    }
  }

  try {
    return {
      ok: true,
      alias,
      provider: parsed.provider,
      modelId: parsed.modelId,
      model: languageModelFromProvider(parsed.provider, parsed.modelId),
    }
  } catch (error) {
    return {
      ok: false,
      alias,
      reason: "provider_unavailable",
      detail: error instanceof Error ? error.message : "Model provider unavailable",
    }
  }
}

export function resolveEmbeddingModel(): EmbeddingModelResolution {
  const parsed = parseModelRef(aiConfig.lockEmbeddingModel)
  if (!parsed.ok) return parsed

  if (parsed.provider === "anthropic") {
    return {
      ok: false,
      reason: "unsupported_provider",
      detail: "Anthropic does not expose embeddings in this integration. Use openai/<embedding-model> or openrouter/<embedding-model>",
    }
  }

  if (parsed.provider === "google") {
    if (!googleClient) {
      return {
        ok: false,
        reason: "missing_key",
        detail: "Embedding model requires GOOGLE_GENERATIVE_AI_API_KEY",
      }
    }

    try {
      return {
        ok: true,
        provider: parsed.provider,
        modelId: parsed.modelId,
        model: googleClient.embedding(parsed.modelId),
      }
    } catch (error) {
      return {
        ok: false,
        reason: "provider_unavailable",
        detail: error instanceof Error ? error.message : "Embedding provider unavailable",
      }
    }
  }

  if (parsed.provider === "openrouter") {
    if (!openRouterClient) {
      return {
        ok: false,
        reason: "missing_key",
        detail: "Embedding model requires OPENAI_API_KEY for OpenRouter",
      }
    }

    try {
      return {
        ok: true,
        provider: parsed.provider,
        modelId: parsed.modelId,
        model: openRouterClient.embedding(parsed.modelId),
      }
    } catch (error) {
      return {
        ok: false,
        reason: "provider_unavailable",
        detail: error instanceof Error ? error.message : "Embedding provider unavailable",
      }
    }
  }

  if (!openaiClient) {
    return {
      ok: false,
      reason: "missing_key",
      detail: "Embedding model requires OPENAI_API_KEY",
    }
  }

  try {
    return {
      ok: true,
      provider: parsed.provider,
      modelId: parsed.modelId,
      model: openaiClient.embedding(parsed.modelId),
    }
  } catch (error) {
    return {
      ok: false,
      reason: "provider_unavailable",
      detail: error instanceof Error ? error.message : "Embedding provider unavailable",
    }
  }
}

function toAvailability(
  resolution: LanguageModelResolution | EmbeddingModelResolution,
): Availability {
  if (!resolution.ok) {
    return {
      ok: false,
      reason: resolution.reason,
      detail: resolution.detail,
    }
  }

  return {
    ok: true,
    provider: resolution.provider,
    modelId: resolution.modelId,
  }
}

export function getAIAvailability() {
  return {
    providers: {
      anthropicConfigured: hasAnthropicKey,
      openAIConfigured: hasOpenAIKey,
      openRouterConfigured: hasOpenAIKey,
      googleConfigured: hasGoogleKey,
    },
    chat: toAvailability(resolveLanguageModel("sonnet")),
    fast: toAvailability(resolveLanguageModel("haiku")),
    embedding: toAvailability(resolveEmbeddingModel()),
  }
}
