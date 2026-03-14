import { LIFE_SCORE_WEIGHTS, MAXX_DOMAINS, type DomainScores } from "../types/domain"
import type { LifeScoreBreakdown } from "../schemas/contracts"

export type TrendPoint = {
  weekStart: string
  score: number
}

export function sanitizeScore(value: number): number {
  if (!Number.isFinite(value)) return 0
  return Math.min(100, Math.max(0, Math.round(value)))
}

export function computeLifeScore(
  domainScores: DomainScores,
  trend: TrendPoint[] = [],
): LifeScoreBreakdown {
  const contributions = MAXX_DOMAINS.reduce(
    (acc, domain) => {
      acc[domain] = Number((domainScores[domain] * LIFE_SCORE_WEIGHTS[domain]).toFixed(2))
      return acc
    },
    {} as Record<(typeof MAXX_DOMAINS)[number], number>,
  )

  const totalScore = sanitizeScore(
    MAXX_DOMAINS.reduce((sum, domain) => sum + contributions[domain], 0),
  )

  return {
    totalScore,
    domainScores,
    weights: LIFE_SCORE_WEIGHTS,
    contributions,
    trend: trend.map((point) => ({
      weekStart: point.weekStart,
      score: sanitizeScore(point.score),
    })),
  }
}
