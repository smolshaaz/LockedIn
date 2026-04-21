import Foundation
import Combine

@MainActor
final class AppSessionViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var launchPhase: AppLaunchPhase = .splash
    @Published private(set) var shouldStartOnboardingAtAuthGate = false

    let api = LockedInAPIService()

    private var hasBootstrapped = false
    private let welcomeKey = "lockedin.hasSeenWelcome"
    private let localProfileKey = "lockedin.localProfile"
    private let onboardingCompletedKey = "hasCompletedOnboarding"
    private let testingModeKey = "lockedin.testingMode.enabled.v1"
    private let defaultUserID = "ios-dev-user"
    private let syncQueue = ProfileSyncQueue.shared

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

        if isTestingModeEnabled {
            await bootstrapTestingMode()
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
            if let profile {
                saveLocalProfile(profile)
            }
        } catch {
            profile = loadLocalProfile()
        }

        if profile == nil {
            profile = loadLocalProfile()
        }

        await flushPendingSyncIfNeeded()

        launchPhase = .ready
    }

    func markWelcomeSeen() {
        UserDefaults.standard.set(true, forKey: welcomeKey)
        launchPhase = .onboarding
    }

    func completeOnboarding(with profile: UserProfile) {
        self.profile = profile
        saveLocalProfile(profile)
        Task {
            syncQueue.enqueueOnboarding(profile)
            await flushPendingSyncIfNeeded()
        }
        markOnboardingCompletedAndEnterApp()
    }

    func syncOnboardingProfile(_ profile: UserProfile) async throws -> UserProfile {
        syncQueue.enqueueOnboarding(profile)
        saveLocalProfile(profile)

        let persisted = try await api.completeOnboarding(profile: profile)
        syncQueue.clearOnboarding()
        self.profile = persisted
        saveLocalProfile(persisted)

        await flushPendingSyncIfNeeded()
        return persisted
    }

    func markOnboardingCompletedAndEnterApp() {
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

    func signOutToAuthGate() {
        profile = nil
        errorMessage = nil
        shouldStartOnboardingAtAuthGate = true
        UserDefaults.standard.set(true, forKey: welcomeKey)
        UserDefaults.standard.set(false, forKey: onboardingCompletedKey)
        UserDefaults.standard.removeObject(forKey: localProfileKey)
        launchPhase = .onboarding
        hasBootstrapped = true
        Task {
            syncQueue.clearAll()
        }
    }

    func consumeOnboardingAuthGateRedirect() -> Bool {
        let shouldRedirect = shouldStartOnboardingAtAuthGate
        shouldStartOnboardingAtAuthGate = false
        return shouldRedirect
    }

    func resetSession() {
        profile = nil
        errorMessage = nil
        shouldStartOnboardingAtAuthGate = false
        UserDefaults.standard.removeObject(forKey: welcomeKey)
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        UserDefaults.standard.removeObject(forKey: localProfileKey)
        launchPhase = .onboarding
        hasBootstrapped = true
        Task {
            syncQueue.clearAll()
        }
    }

    private func flushPendingSyncIfNeeded() async {
        guard let syncedProfile = await syncQueue.flush(using: api) else { return }
        profile = syncedProfile
        saveLocalProfile(syncedProfile)
    }

    private var isTestingModeEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("--testing-mode-off") {
            UserDefaults.standard.set(false, forKey: testingModeKey)
            return false
        }

        if ProcessInfo.processInfo.arguments.contains("--testing-mode") {
            UserDefaults.standard.set(true, forKey: testingModeKey)
            return true
        }

        if UserDefaults.standard.object(forKey: testingModeKey) == nil {
            #if DEBUG
            UserDefaults.standard.set(true, forKey: testingModeKey)
            #else
            UserDefaults.standard.set(false, forKey: testingModeKey)
            #endif
        }

        return UserDefaults.standard.bool(forKey: testingModeKey)
    }

    private func bootstrapTestingMode() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let seeded = try await api.bootstrapTestingUser()
            setProfile(seeded)
            await flushPendingSyncIfNeeded()
            errorMessage = nil
            launchPhase = .ready
            return
        } catch {
            if let local = loadLocalProfile() {
                profile = local
                launchPhase = .ready
                errorMessage = "Testing mode API unavailable. Loaded local profile."
                return
            }

            let fallback = UserProfile(
                userId: defaultUserID,
                name: "Aaryan",
                age: 21,
                goals: ["GymMaxx momentum", "MindMaxx execution", "MoneyMaxx opportunities"],
                constraints: ["College workload", "Routine inconsistency"],
                communicationStyle: "Firm",
                baseline: ["gym": 61, "face": 69, "money": 66, "mind": 72, "social": 57],
                onboardingCompleted: true
            )
            setProfile(fallback)
            errorMessage = "Testing mode API unavailable. Loaded local fallback."
            launchPhase = .ready
        }
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
