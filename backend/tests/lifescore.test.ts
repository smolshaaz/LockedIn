import { describe, expect, it } from "bun:test"
import { computeLifeScore, sanitizeScore } from "../src/services/lifescore-service"

describe("lifescore-service", () => {
  it("clamps scores safely", () => {
    expect(sanitizeScore(130)).toBe(100)
    expect(sanitizeScore(-20)).toBe(0)
    expect(sanitizeScore(Number.NaN)).toBe(0)
  })

  it("returns deterministic weighted score and transparent contributions", () => {
    const result = computeLifeScore({
      gym: 80,
      face: 70,
      money: 60,
      mind: 90,
      social: 50,
    })

    expect(result.totalScore).toBe(72)
    expect(result.contributions.mind).toBe(20.7)
    expect(result.weights.gym).toBe(0.22)
  })
})
