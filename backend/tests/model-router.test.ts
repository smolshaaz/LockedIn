import { describe, expect, it } from "bun:test"
import {
  chooseFallbackModel,
  chooseModelForChat,
  chooseModelForTask,
} from "../src/services/model-router-service"

describe("model-router-service", () => {
  it("routes by task deterministically", () => {
    expect(chooseModelForTask("chat")).toBe("sonnet")
    expect(chooseModelForTask("checkin")).toBe("haiku")
  })

  it("routes deep chat requests to sonnet", () => {
    expect(
      chooseModelForChat({
        threadId: "t1",
        message: "give me a strategy and roadmap",
        context: { wantsProtocol: false, urgency: "normal" },
      }),
    ).toBe("sonnet")
  })

  it("supports fallback", () => {
    expect(chooseFallbackModel("sonnet")).toBe("haiku")
    expect(chooseFallbackModel("haiku")).toBe("sonnet")
  })
})
