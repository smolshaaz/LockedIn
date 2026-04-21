import { describe, expect, it } from "bun:test"
import {
  getAIAvailability,
  parseModelRef,
  resolveEmbeddingModel,
  resolveLanguageModel,
} from "../src/integrations/ai-models"

describe("ai-models integration", () => {
  it("parses provider/model references", () => {
    const parsed = parseModelRef("anthropic/claude-sonnet-4-5")
    expect(parsed.ok).toBe(true)
    if (parsed.ok) {
      expect(parsed.provider).toBe("anthropic")
      expect(parsed.modelId).toBe("claude-sonnet-4-5")
    }
  })

  it("parses google provider/model references", () => {
    const parsed = parseModelRef("google/gemini-2.5-flash")
    expect(parsed.ok).toBe(true)
    if (parsed.ok) {
      expect(parsed.provider).toBe("google")
      expect(parsed.modelId).toBe("gemini-2.5-flash")
    }
  })

  it("parses openrouter provider/model references", () => {
    const parsed = parseModelRef("openrouter/hunter-alpha")
    expect(parsed.ok).toBe(true)
    if (parsed.ok) {
      expect(parsed.provider).toBe("openrouter")
      expect(parsed.modelId).toBe("hunter-alpha")
    }
  })

  it("rejects invalid model references", () => {
    const parsed = parseModelRef("invalid-ref")
    expect(parsed.ok).toBe(false)
    if (!parsed.ok) {
      expect(parsed.reason).toBe("invalid_model_ref")
    }
  })

  it("resolves chat alias with safe fallback behavior", () => {
    const resolved = resolveLanguageModel("sonnet")
    if (resolved.ok) {
      expect(resolved.model).toBeDefined()
      expect(resolved.alias).toBe("sonnet")
    } else {
      expect(resolved.reason).toBeDefined()
      expect(resolved.detail.length).toBeGreaterThan(0)
    }
  })

  it("resolves embedding model with safe fallback behavior", () => {
    const resolved = resolveEmbeddingModel()
    if (resolved.ok) {
      expect(resolved.model).toBeDefined()
    } else {
      expect(resolved.reason).toBeDefined()
      expect(resolved.detail.length).toBeGreaterThan(0)
    }
  })

  it("exposes availability diagnostics", () => {
    const availability = getAIAvailability()
    expect(typeof availability.providers.anthropicConfigured).toBe("boolean")
    expect(typeof availability.providers.openAIConfigured).toBe("boolean")
    expect(typeof availability.providers.openRouterConfigured).toBe("boolean")
    expect(typeof availability.providers.googleConfigured).toBe("boolean")
    expect(typeof availability.chat.ok).toBe("boolean")
    expect(typeof availability.fast.ok).toBe("boolean")
    expect(typeof availability.embedding.ok).toBe("boolean")
  })
})
