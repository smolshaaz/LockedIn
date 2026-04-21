import Foundation

@MainActor
final class ProfileSyncQueue {
    static let shared = ProfileSyncQueue()

    private let onboardingKey = "lockedin.sync.pendingOnboarding.v1"
    private let profileUpdatesKey = "lockedin.sync.pendingProfileUpdates.v1"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func enqueueOnboarding(_ profile: UserProfile) {
        guard let encoded = try? encoder.encode(profile) else { return }
        defaults.set(encoded, forKey: onboardingKey)
    }

    func clearOnboarding() {
        defaults.removeObject(forKey: onboardingKey)
    }

    func enqueueProfileUpdate(_ update: ProfileUpdateRequest) {
        var updates = loadProfileUpdates()
        updates.append(update)
        saveProfileUpdates(updates)
    }

    func clearProfileUpdates() {
        defaults.removeObject(forKey: profileUpdatesKey)
    }

    func clearAll() {
        clearOnboarding()
        clearProfileUpdates()
    }

    func flush(using api: LockedInAPIService) async -> UserProfile? {
        var latestProfile: UserProfile?

        if let onboarding = loadOnboarding() {
            do {
                let persisted = try await api.completeOnboarding(profile: onboarding)
                latestProfile = persisted
                clearOnboarding()
            } catch {
                return latestProfile
            }
        }

        if let mergedUpdate = mergedProfileUpdates() {
            do {
                let persisted = try await api.updateProfile(mergedUpdate)
                latestProfile = persisted
                clearProfileUpdates()
            } catch {
                return latestProfile
            }
        }

        return latestProfile
    }

    private func loadOnboarding() -> UserProfile? {
        guard let data = defaults.data(forKey: onboardingKey) else { return nil }
        return try? decoder.decode(UserProfile.self, from: data)
    }

    private func loadProfileUpdates() -> [ProfileUpdateRequest] {
        guard let data = defaults.data(forKey: profileUpdatesKey) else { return [] }
        return (try? decoder.decode([ProfileUpdateRequest].self, from: data)) ?? []
    }

    private func saveProfileUpdates(_ updates: [ProfileUpdateRequest]) {
        guard !updates.isEmpty else {
            clearProfileUpdates()
            return
        }

        guard let encoded = try? encoder.encode(updates) else { return }
        defaults.set(encoded, forKey: profileUpdatesKey)
    }

    private func mergedProfileUpdates() -> ProfileUpdateRequest? {
        let updates = loadProfileUpdates()
        guard !updates.isEmpty else { return nil }

        return updates.reduce(into: ProfileUpdateRequest.empty) { merged, next in
            if let value = next.name { merged.name = value }
            if let value = next.goals { merged.goals = value }
            if let value = next.constraints { merged.constraints = value }
            if let value = next.communicationStyle { merged.communicationStyle = value }
            if let value = next.weeklyCheckinDay { merged.weeklyCheckinDay = value }
            if let value = next.weeklyCheckinTime { merged.weeklyCheckinTime = value }
            if let value = next.timezoneId { merged.timezoneId = value }
            if let value = next.preferredWeightUnit { merged.preferredWeightUnit = value }
            if let value = next.preferredHeightUnit { merged.preferredHeightUnit = value }
            if let value = next.channelInAppEnabled { merged.channelInAppEnabled = value }
            if let value = next.channelTelegramEnabled { merged.channelTelegramEnabled = value }
            if let value = next.channelDiscordEnabled { merged.channelDiscordEnabled = value }
            if let value = next.quietHoursEnabled { merged.quietHoursEnabled = value }
            if let value = next.quietHoursStart { merged.quietHoursStart = value }
            if let value = next.quietHoursEnd { merged.quietHoursEnd = value }
            if let value = next.googleConnected { merged.googleConnected = value }
            if let value = next.telegramConnected { merged.telegramConnected = value }
            if let value = next.discordConnected { merged.discordConnected = value }
        }
    }
}
