import Foundation
import Combine

@MainActor
final class LifeScoreViewModel: ObservableObject {
    @Published var lifeScore: LifeScoreBreakdown?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: LockedInAPIService
    private var lastFailureAt: Date?
    private var lastSuccessfulFetchAt: Date?

    private let cacheKey = "lockedin.lifescore.cache.v1"
    private let cacheFetchedAtKey = "lockedin.lifescore.cacheFetchedAt.v1"
    private let cacheRefreshInterval: TimeInterval = 60 * 60 * 6

    init(api: LockedInAPIService) {
        self.api = api
        self.lifeScore = loadCachedLifeScore()
        if let fetchedAt = UserDefaults.standard.object(forKey: cacheFetchedAtKey) as? Date {
            self.lastSuccessfulFetchAt = fetchedAt
        }
    }

    var weeklyDelta: Int {
        guard let lifeScore, lifeScore.trend.count >= 2 else { return 0 }
        let ordered = lifeScore.trend.sorted { $0.weekStart > $1.weekStart }
        let current = ordered[0].score
        let previous = ordered[1].score
        return Int((current - previous).rounded())
    }

    func refresh(force: Bool = false) async {
        if !force, shouldKeepCachedScore() {
            return
        }

        if let lastFailureAt,
           Date().timeIntervalSince(lastFailureAt) < 8,
           lifeScore != nil {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            lifeScore = try await api.fetchLifeScore()
            persistLifeScore(lifeScore)
            errorMessage = nil
            lastFailureAt = nil
            lastSuccessfulFetchAt = Date()
            UserDefaults.standard.set(lastSuccessfulFetchAt, forKey: cacheFetchedAtKey)
        } catch {
            lastFailureAt = Date()
            if lifeScore == nil {
                lifeScore = loadCachedLifeScore() ?? localFallbackLifeScore()
            }
            errorMessage = "Backend unavailable. Showing cached LifeScore."
        }
    }

    func setLifeScore(_ newScore: LifeScoreBreakdown) {
        lifeScore = newScore
        persistLifeScore(newScore)
        lastSuccessfulFetchAt = Date()
        UserDefaults.standard.set(lastSuccessfulFetchAt, forKey: cacheFetchedAtKey)
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

    private func shouldKeepCachedScore() -> Bool {
        guard let lifeScore else { return false }
        guard isCurrentWeek(score: lifeScore) else { return false }
        guard let lastSuccessfulFetchAt else { return false }
        return Date().timeIntervalSince(lastSuccessfulFetchAt) < cacheRefreshInterval
    }

    private func isCurrentWeek(score: LifeScoreBreakdown) -> Bool {
        guard let latest = score.trend.sorted(by: { $0.weekStart > $1.weekStart }).first else {
            return false
        }
        guard let latestDate = parseWeekStart(latest.weekStart) else { return false }

        let calendar = Calendar(identifier: .iso8601)
        let latestComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: latestDate)
        let nowComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return latestComponents.yearForWeekOfYear == nowComponents.yearForWeekOfYear &&
               latestComponents.weekOfYear == nowComponents.weekOfYear
    }

    private func persistLifeScore(_ value: LifeScoreBreakdown?) {
        guard let value else { return }
        guard let encoded = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

    private func loadCachedLifeScore() -> LifeScoreBreakdown? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(LifeScoreBreakdown.self, from: data)
    }

    private func parseWeekStart(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
