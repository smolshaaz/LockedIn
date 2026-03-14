import type { DomainProgress, WeeklyCheckin } from "../schemas/contracts"
import type { DomainScores } from "../types/domain"

export function diffCheckin(previous: DomainScores, checkin: WeeklyCheckin): DomainProgress[] {
  return checkin.entries.map((entry) => {
    const prior = previous[entry.domain]
    const next = entry.score

    return {
      domain: entry.domain,
      previousScore: prior,
      newScore: next,
      delta: Number((next - prior).toFixed(2)),
      note: entry.notes,
    }
  })
}
