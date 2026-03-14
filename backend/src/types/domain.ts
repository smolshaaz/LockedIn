export const MAXX_DOMAINS = [
  "gym",
  "face",
  "money",
  "mind",
  "social",
] as const

export type MaxxDomain = (typeof MAXX_DOMAINS)[number]

export type DomainScores = Record<MaxxDomain, number>

export const LIFE_SCORE_WEIGHTS: Record<MaxxDomain, number> = {
  gym: 0.22,
  face: 0.18,
  money: 0.22,
  mind: 0.23,
  social: 0.15,
}
