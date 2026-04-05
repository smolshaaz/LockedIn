import Foundation
import Combine

@MainActor
final class AppSessionViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var launchPhase: AppLaunchPhase = .splash

    let api = LockedInAPIService()

    private var hasBootstrapped = false
    private let welcomeKey = "lockedin.hasSeenWelcome"
    private let localProfileKey = "lockedin.localProfile"
    private let onboardingCompletedKey = "hasCompletedOnboarding"
    private let defaultUserID = "ios-dev-user"

    var isOnboarded: Bool {
        profile != nil
    }

    var displayName: String {
        profile?.name.isEmpty == false ? profile?.name ?? "Builder" : "Builder"
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        if ProcessInfo.processInfo.arguments.contains("--uitesting-ready") {
            profile = UserProfile(
                userId: defaultUserID,
                name: "Aryan",
                age: nil,
                goals: ["Lock execution consistency"],
                constraints: [],
                communicationStyle: "Direct",
                baseline: ["mind": 70]
            )
            launchPhase = .ready
            return
        }

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        guard hasCompletedOnboarding else {
            launchPhase = .onboarding
            return
        }

        isLoading = true
        defer { isLoading = false }

        try? await Task.sleep(nanoseconds: 900_000_000)

        do {
            profile = try await api.loadProfile()
        } catch {
            profile = loadLocalProfile()
        }

        if profile == nil {
            profile = loadLocalProfile()
        }

        launchPhase = .ready
    }

    func markWelcomeSeen() {
        UserDefaults.standard.set(true, forKey: welcomeKey)
        launchPhase = .onboarding
    }

    func completeOnboarding(with profile: UserProfile) {
        self.profile = profile
        saveLocalProfile(profile)
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        UserDefaults.standard.set(true, forKey: welcomeKey)
        launchPhase = .ready
    }

    func completeQuickstart(using vm: OnboardingViewModel) async {
        isLoading = true
        defer { isLoading = false }

        completeOnboarding(with: vm.buildProfile(userId: defaultUserID))
    }

    func setProfile(_ profile: UserProfile) {
        self.profile = profile
        saveLocalProfile(profile)
        UserDefaults.standard.set(true, forKey: welcomeKey)
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        launchPhase = .ready
    }

    func resetSession() {
        profile = nil
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: welcomeKey)
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        UserDefaults.standard.removeObject(forKey: localProfileKey)
        launchPhase = .onboarding
        hasBootstrapped = true
    }

    private func saveLocalProfile(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: localProfileKey)
    }

    private func loadLocalProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: localProfileKey) else {
            return nil
        }

        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
}
