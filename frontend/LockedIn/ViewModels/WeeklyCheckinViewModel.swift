import Foundation
import Combine

@MainActor
final class WeeklyCheckinViewModel: ObservableObject {
    @Published var domainScores: [MaxxDomain: Double] = [
        .gym: 50,
        .face: 50,
        .money: 50,
        .mind: 50,
        .social: 50,
    ]
    @Published var domainNotes: [MaxxDomain: String] = [
        .gym: "",
        .face: "",
        .money: "",
        .mind: "",
        .social: "",
    ]
    @Published var progress: [DomainProgress] = []
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let api: LockedInAPIService

    init(api: LockedInAPIService) {
        self.api = api
    }

    func submit() async -> LifeScoreBreakdown? {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let entries = MaxxDomain.allCases.map { domain in
                CheckinEntry(
                    domain: domain,
                    score: domainScores[domain] ?? 50,
                    notes: (domainNotes[domain]?.isEmpty == false) ? (domainNotes[domain] ?? "") : "No note provided"
                )
            }

            let request = WeeklyCheckinRequest(
                weekStart: Self.weekStartISODate(),
                entries: entries
            )

            let response = try await api.submitWeeklyCheckin(request)
            progress = response.progress
            return response.lifeScore
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private static func weekStartISODate() -> String {
        let calendar = Calendar(identifier: .iso8601)
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: weekStart)
    }
}
