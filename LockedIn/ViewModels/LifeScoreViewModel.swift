import Foundation
import Combine

@MainActor
final class LifeScoreViewModel: ObservableObject {
    @Published var lifeScore: LifeScoreBreakdown?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: LockedInAPIService
    private var lastFailureAt: Date?

    init(api: LockedInAPIService) {
        self.api = api
    }

    func refresh() async {
        if let lastFailureAt,
           Date().timeIntervalSince(lastFailureAt) < 8,
           lifeScore != nil {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            lifeScore = try await api.fetchLifeScore()
            errorMessage = nil
            lastFailureAt = nil
        } catch {
            lastFailureAt = Date()
            if lifeScore == nil {
                lifeScore = localFallbackLifeScore()
            }
            errorMessage = "Backend unavailable. Showing local LifeScore preview."
        }
    }

    func setLifeScore(_ newScore: LifeScoreBreakdown) {
        lifeScore = newScore
    }

    private func localFallbackLifeScore() -> LifeScoreBreakdown {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let points = (0..<4).compactMap { index -> TrendPoint? in
            guard let date = Calendar.current.date(byAdding: .weekOfYear, value: -index, to: Date()) else { return nil }
            return TrendPoint(weekStart: formatter.string(from: date), score: Double(64 + (index * 2)))
        }

        return LifeScoreBreakdown(
            totalScore: 67,
            domainScores: [
                MaxxDomain.gym.rawValue: 61,
                MaxxDomain.mind.rawValue: 72,
                MaxxDomain.money.rawValue: 68,
                MaxxDomain.face.rawValue: 70,
                MaxxDomain.social.rawValue: 55
            ],
            weights: [
                MaxxDomain.gym.rawValue: 0.24,
                MaxxDomain.mind.rawValue: 0.26,
                MaxxDomain.money.rawValue: 0.2,
                MaxxDomain.face.rawValue: 0.15,
                MaxxDomain.social.rawValue: 0.15
            ],
            contributions: [
                MaxxDomain.gym.rawValue: 14.6,
                MaxxDomain.mind.rawValue: 18.7,
                MaxxDomain.money.rawValue: 13.6,
                MaxxDomain.face.rawValue: 10.5,
                MaxxDomain.social.rawValue: 8.2
            ],
            trend: points
        )
    }
}
