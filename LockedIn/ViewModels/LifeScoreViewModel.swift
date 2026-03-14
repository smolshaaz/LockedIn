import Foundation
import Combine

@MainActor
final class LifeScoreViewModel: ObservableObject {
    @Published var lifeScore: LifeScoreBreakdown?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: LockedInAPIService

    init(api: LockedInAPIService) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            lifeScore = try await api.fetchLifeScore()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setLifeScore(_ newScore: LifeScoreBreakdown) {
        lifeScore = newScore
    }
}
