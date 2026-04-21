import { describe, expect, it } from "bun:test"
import {
  domainsForRequest,
  extractMentionedDomains,
  normalizeChatRequest,
  urgencyForDomain,
} from "../src/services/chat-context"

describe("chat-context", () => {
  it("extracts multiple @mentioned domains from a single message", () => {
    const domains = extractMentionedDomains(
      "Today: @MindMaxx high, @MoneyMaxx normal, and @gym.",
    )

    expect(domains).toEqual(["mind", "money", "gym"])
  })

  it("normalizes request with merged domains and per-domain urgency", () => {
    const request = normalizeChatRequest({
      threadId: "main",
      message: "Focus @mind:high and @social low",
      context: {
        wantsProtocol: false,
        urgency: "normal",
      },
    })

    expect(domainsForRequest(request)).toEqual(["mind", "social"])
    expect(request.context.domain).toBe("mind")
    expect(urgencyForDomain(request, "mind")).toBe("high")
    expect(urgencyForDomain(request, "social")).toBe("low")
    expect(urgencyForDomain(request, "money")).toBe("normal")
  })
})
