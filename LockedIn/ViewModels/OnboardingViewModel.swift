import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step = 1
    @Published var name = ""
    @Published var primaryObjective = ""
    @Published var preferredIntensity: CoachingIntensity = .hard
    @Published var baselineScore: Double = 58
    @Published var nonNegotiableCommitment = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    var canContinueStepOne: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !primaryObjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canFinishStepTwo: Bool {
        !nonNegotiableCommitment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func buildProfile(userId: String) -> UserProfile {
        let baselineValue = baselineScore.rounded()
        let baselinePayload = Dictionary(uniqueKeysWithValues: MaxxDomain.allCases.map { ($0.rawValue, baselineValue) })

        return UserProfile(
            userId: userId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: nil,
            goals: [primaryObjective.trimmingCharacters(in: .whitespacesAndNewlines)],
            constraints: [
                "Intensity: \(preferredIntensity.rawValue)",
                "Commitment: \(nonNegotiableCommitment.trimmingCharacters(in: .whitespacesAndNewlines))"
            ],
            communicationStyle: "blunt",
            baseline: baselinePayload
        )
    }
}
