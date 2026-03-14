import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var goalsText = ""
    @Published var constraintsText = ""
    @Published var coachingTone = "Direct"
    @Published var dailyReminderEnabled = true
    @Published var weeklyReflectionReminderEnabled = true
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let api: LockedInAPIService

    init(api: LockedInAPIService) {
        self.api = api
    }

    func apply(profile: UserProfile) {
        name = profile.name
        goalsText = profile.goals.joined(separator: ", ")
        constraintsText = profile.constraints.joined(separator: ", ")
    }

    func save() async -> UserProfile? {
        isSaving = true
        defer { isSaving = false }

        let goals = goalsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let constraints = constraintsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            return try await api.updateProfile(name: name, goals: goals, constraints: constraints)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
