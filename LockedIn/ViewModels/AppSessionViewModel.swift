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

        isLoading = true
        defer { isLoading = false }

        try? await Task.sleep(nanoseconds: 900_000_000)

        do {
            profile = try await api.loadProfile()
        } catch {
            profile = loadLocalProfile()
        }

        if profile != nil {
            UserDefaults.standard.set(true, forKey: welcomeKey)
            launchPhase = .ready
            return
        }

        if UserDefaults.standard.bool(forKey: welcomeKey) {
            launchPhase = .onboarding
        } else {
            launchPhase = .welcome
        }
    }

    func markWelcomeSeen() {
        UserDefaults.standard.set(true, forKey: welcomeKey)
        launchPhase = .onboarding
    }

    func completeQuickstart(using vm: OnboardingViewModel) async {
        isLoading = true
        defer { isLoading = false }

        let payload = vm.buildProfile(userId: defaultUserID)

        do {
            let created = try await api.completeOnboarding(profile: payload)
            profile = created
        } catch {
            // Frontend-first fallback for local dev when backend is unavailable.
            profile = payload
        }

        if let profile {
            saveLocalProfile(profile)
        }
        UserDefaults.standard.set(true, forKey: welcomeKey)
        launchPhase = .ready
    }

    func setProfile(_ profile: UserProfile) {
        self.profile = profile
        saveLocalProfile(profile)
        UserDefaults.standard.set(true, forKey: welcomeKey)
        launchPhase = .ready
    }

    func resetSession() {
        profile = nil
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: welcomeKey)
        UserDefaults.standard.removeObject(forKey: localProfileKey)
        launchPhase = .welcome
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
