import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    enum WeeklyCheckinDayOption: String, CaseIterable, Identifiable {
        case monday = "Monday"
        case tuesday = "Tuesday"
        case wednesday = "Wednesday"
        case thursday = "Thursday"
        case friday = "Friday"
        case saturday = "Saturday"
        case sunday = "Sunday"

        var id: String { rawValue }
    }

    enum WeightUnitOption: String, CaseIterable, Identifiable {
        case kg
        case lbs

        var id: String { rawValue }
        var label: String { rawValue.uppercased() }
    }

    enum HeightUnitOption: String, CaseIterable, Identifiable {
        case cm
        case ftIn = "ft-in"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .cm: return "CM"
            case .ftIn: return "FT+IN"
            }
        }
    }

    enum ConnectedAccount: String, CaseIterable, Identifiable {
        case google
        case telegram
        case discord

        var id: String { rawValue }

        var title: String {
            switch self {
            case .google: return "Google"
            case .telegram: return "Telegram"
            case .discord: return "Discord"
            }
        }
    }

    @Published var name = ""

    @Published var goals: [String] = []
    @Published var constraints: [String] = []
    @Published var goalInput = ""
    @Published var constraintInput = ""

    @Published var coachingTone = "Firm"
    @Published var dailyReminderEnabled = true
    @Published var weeklyReflectionReminderEnabled = true
    @Published var dmCheckinsEnabled = true
    @Published var streakNudgeEnabled = true

    @Published var weeklyCheckinDay: WeeklyCheckinDayOption = .sunday
    @Published var weeklyCheckinTime: Date = ProfileViewModel.defaultTime(hour: 19, minute: 0)
    @Published var timezoneId = TimeZone.current.identifier

    @Published var preferredWeightUnit: WeightUnitOption = .kg
    @Published var preferredHeightUnit: HeightUnitOption = .cm

    @Published var channelInAppEnabled = true
    @Published var channelTelegramEnabled = false
    @Published var channelDiscordEnabled = false

    @Published var quietHoursEnabled = false
    @Published var quietHoursStart: Date = ProfileViewModel.defaultTime(hour: 23, minute: 0)
    @Published var quietHoursEnd: Date = ProfileViewModel.defaultTime(hour: 7, minute: 0)

    @Published var googleConnected = false
    @Published var telegramConnected = false
    @Published var discordConnected = false

    @Published var isSaving = false
    @Published var isExporting = false
    @Published var isDeletingData = false
    @Published var exportedDataText: String?
    @Published var errorMessage: String?

    let toneOptions = ["Blunt", "Firm", "Measured"]
    let goalSuggestions = [
        "Build physique",
        "Lose fat",
        "Focus harder",
        "Make more money",
        "Fix my looks",
        "Better social life",
        "Build consistency",
        "Increase confidence"
    ]
    let constraintSuggestions = [
        "Limited time",
        "Low budget",
        "Travel schedule",
        "Exam season",
        "Night shifts",
        "Injury recovery",
        "Family commitments",
        "Unstable routine"
    ]

    private let api: LockedInAPIService
    private let syncQueue = ProfileSyncQueue.shared
    private let settingsKey = "lockedin.settings.preferences.v2"
    private var profileSnapshot: UserProfile?

    private struct LocalSettings: Codable {
        let coachingTone: String
        let dailyReminderEnabled: Bool
        let weeklyReflectionReminderEnabled: Bool
        let dmCheckinsEnabled: Bool
        let streakNudgeEnabled: Bool
        let weeklyCheckinDay: String
        let weeklyCheckinTime: String
        let timezoneId: String
        let preferredWeightUnit: String
        let preferredHeightUnit: String
        let channelInAppEnabled: Bool
        let channelTelegramEnabled: Bool
        let channelDiscordEnabled: Bool
        let quietHoursEnabled: Bool
        let quietHoursStart: String
        let quietHoursEnd: String
        let googleConnected: Bool
        let telegramConnected: Bool
        let discordConnected: Bool
    }

    init(api: LockedInAPIService) {
        self.api = api
        loadLocalSettings()
    }

    var timezoneOptions: [String] {
        let fixed = [
            TimeZone.current.identifier,
            "UTC",
            "America/New_York",
            "Europe/London",
            "Asia/Kolkata",
            "Asia/Dubai",
            "Asia/Singapore",
            "Australia/Sydney"
        ]
        var seen = Set<String>()
        return fixed.filter { seen.insert($0).inserted }
    }

    func apply(profile: UserProfile) {
        profileSnapshot = profile
        name = profile.name
        goals = dedup(profile.goals)
        constraints = dedup(profile.constraints)
        coachingTone = normalizeTone(profile.communicationStyle)

        if let value = profile.weeklyCheckinDay,
           let parsed = WeeklyCheckinDayOption(rawValue: value) {
            weeklyCheckinDay = parsed
        }

        if let value = profile.weeklyCheckinTime,
           let parsed = parseTime(value) {
            weeklyCheckinTime = parsed
        }

        if let tz = profile.timezoneId, !tz.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            timezoneId = tz
        }

        if let unit = profile.preferredWeightUnit,
           let parsed = WeightUnitOption(rawValue: unit) {
            preferredWeightUnit = parsed
        }

        if let unit = profile.preferredHeightUnit,
           let parsed = HeightUnitOption(rawValue: unit) {
            preferredHeightUnit = parsed
        }

        channelInAppEnabled = profile.channelInAppEnabled ?? true
        channelTelegramEnabled = profile.channelTelegramEnabled ?? false
        channelDiscordEnabled = profile.channelDiscordEnabled ?? false

        quietHoursEnabled = profile.quietHoursEnabled ?? false
        if let value = profile.quietHoursStart,
           let parsed = parseTime(value) {
            quietHoursStart = parsed
        }
        if let value = profile.quietHoursEnd,
           let parsed = parseTime(value) {
            quietHoursEnd = parsed
        }

        googleConnected = profile.googleConnected ?? false
        telegramConnected = profile.telegramConnected ?? false
        discordConnected = profile.discordConnected ?? false

        persistLocalSettings()
    }

    func toggleGoalSuggestion(_ value: String) {
        if goals.contains(value) {
            goals.removeAll { $0 == value }
        } else {
            goals.append(value)
        }
        goals = dedup(goals)
    }

    func toggleConstraintSuggestion(_ value: String) {
        if constraints.contains(value) {
            constraints.removeAll { $0 == value }
        } else {
            constraints.append(value)
        }
        constraints = dedup(constraints)
    }

    func addGoalFromInput() {
        let cleaned = cleanedText(goalInput)
        guard !cleaned.isEmpty else { return }
        goals.append(cleaned)
        goals = dedup(goals)
        goalInput = ""
    }

    func addConstraintFromInput() {
        let cleaned = cleanedText(constraintInput)
        guard !cleaned.isEmpty else { return }
        constraints.append(cleaned)
        constraints = dedup(constraints)
        constraintInput = ""
    }

    func removeGoal(_ value: String) {
        goals.removeAll { $0 == value }
    }

    func removeConstraint(_ value: String) {
        constraints.removeAll { $0 == value }
    }

    func setConnected(_ account: ConnectedAccount, connected: Bool) {
        switch account {
        case .google:
            googleConnected = connected
        case .telegram:
            telegramConnected = connected
            if !connected {
                channelTelegramEnabled = false
            }
        case .discord:
            discordConnected = connected
            if !connected {
                channelDiscordEnabled = false
            }
        }
    }

    func save() async -> UserProfile? {
        isSaving = true
        defer { isSaving = false }

        let cleanedName = cleanedText(name)
        let cleanedGoals = dedup(goals)
        let cleanedConstraints = dedup(constraints)

        guard !cleanedName.isEmpty else {
            errorMessage = "Name is required."
            return nil
        }

        guard !cleanedGoals.isEmpty else {
            errorMessage = "Add at least one goal."
            return nil
        }

        if !channelInAppEnabled && !channelTelegramEnabled && !channelDiscordEnabled {
            errorMessage = "Enable at least one delivery channel."
            return nil
        }

        if channelTelegramEnabled && !telegramConnected {
            errorMessage = "Connect Telegram before enabling Telegram channel."
            return nil
        }

        if channelDiscordEnabled && !discordConnected {
            errorMessage = "Connect Discord before enabling Discord channel."
            return nil
        }

        let request = ProfileUpdateRequest(
            name: cleanedName,
            goals: cleanedGoals,
            constraints: cleanedConstraints,
            communicationStyle: coachingTone,
            weeklyCheckinDay: weeklyCheckinDay.rawValue,
            weeklyCheckinTime: formatTime(weeklyCheckinTime),
            timezoneId: timezoneId,
            preferredWeightUnit: preferredWeightUnit.rawValue,
            preferredHeightUnit: preferredHeightUnit.rawValue,
            channelInAppEnabled: channelInAppEnabled,
            channelTelegramEnabled: channelTelegramEnabled,
            channelDiscordEnabled: channelDiscordEnabled,
            quietHoursEnabled: quietHoursEnabled,
            quietHoursStart: formatTime(quietHoursStart),
            quietHoursEnd: formatTime(quietHoursEnd),
            googleConnected: googleConnected,
            telegramConnected: telegramConnected,
            discordConnected: discordConnected
        )

        persistLocalSettings()
        let optimisticProfile = buildOptimisticProfile(
            request: request,
            fallbackName: cleanedName,
            fallbackGoals: cleanedGoals,
            fallbackConstraints: cleanedConstraints
        )

        do {
            let updated = try await api.updateProfile(request)
            profileSnapshot = updated
            syncQueue.clearProfileUpdates()
            errorMessage = nil
            return updated
        } catch {
            syncQueue.enqueueProfileUpdate(request)
            profileSnapshot = optimisticProfile
            errorMessage = "Saved locally. Pending sync to backend when available."
            return optimisticProfile
        }
    }

    func exportData() async -> String? {
        isExporting = true
        defer { isExporting = false }

        do {
            let payload = try await api.exportUserData()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            let text = String(decoding: data, as: UTF8.self)
            exportedDataText = text
            errorMessage = nil
            return text
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteAccountData() async -> Bool {
        isDeletingData = true
        defer { isDeletingData = false }

        do {
            try await api.deleteAccountData()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func dedup(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let cleaned = cleanedText(value)
            guard !cleaned.isEmpty else { continue }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(cleaned)
        }

        return result
    }

    private func cleanedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeTone(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "blunt":
            return "Blunt"
        case "measured":
            return "Measured"
        case "firm", "balanced", "direct":
            return "Firm"
        default:
            return "Firm"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func parseTime(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: value)
    }

    private func buildOptimisticProfile(
        request: ProfileUpdateRequest,
        fallbackName: String,
        fallbackGoals: [String],
        fallbackConstraints: [String]
    ) -> UserProfile {
        var profile = profileSnapshot ?? UserProfile(
            userId: "ios-dev-user",
            name: fallbackName,
            age: nil,
            goals: fallbackGoals,
            constraints: fallbackConstraints,
            communicationStyle: coachingTone,
            baseline: [
                "gym": 50,
                "face": 50,
                "money": 50,
                "mind": 50,
                "social": 50,
            ]
        )

        if let value = request.name { profile.name = value }
        if let value = request.goals { profile.goals = value }
        if let value = request.constraints { profile.constraints = value }
        if let value = request.communicationStyle { profile.communicationStyle = value }
        if let value = request.weeklyCheckinDay { profile.weeklyCheckinDay = value }
        if let value = request.weeklyCheckinTime { profile.weeklyCheckinTime = value }
        if let value = request.timezoneId { profile.timezoneId = value }
        if let value = request.preferredWeightUnit { profile.preferredWeightUnit = value }
        if let value = request.preferredHeightUnit { profile.preferredHeightUnit = value }
        if let value = request.channelInAppEnabled { profile.channelInAppEnabled = value }
        if let value = request.channelTelegramEnabled { profile.channelTelegramEnabled = value }
        if let value = request.channelDiscordEnabled { profile.channelDiscordEnabled = value }
        if let value = request.quietHoursEnabled { profile.quietHoursEnabled = value }
        if let value = request.quietHoursStart { profile.quietHoursStart = value }
        if let value = request.quietHoursEnd { profile.quietHoursEnd = value }
        if let value = request.googleConnected { profile.googleConnected = value }
        if let value = request.telegramConnected { profile.telegramConnected = value }
        if let value = request.discordConnected { profile.discordConnected = value }
        if let value = request.maxxContextNotes { profile.maxxContextNotes = value }

        return profile
    }

    private func persistLocalSettings() {
        let payload = LocalSettings(
            coachingTone: coachingTone,
            dailyReminderEnabled: dailyReminderEnabled,
            weeklyReflectionReminderEnabled: weeklyReflectionReminderEnabled,
            dmCheckinsEnabled: dmCheckinsEnabled,
            streakNudgeEnabled: streakNudgeEnabled,
            weeklyCheckinDay: weeklyCheckinDay.rawValue,
            weeklyCheckinTime: formatTime(weeklyCheckinTime),
            timezoneId: timezoneId,
            preferredWeightUnit: preferredWeightUnit.rawValue,
            preferredHeightUnit: preferredHeightUnit.rawValue,
            channelInAppEnabled: channelInAppEnabled,
            channelTelegramEnabled: channelTelegramEnabled,
            channelDiscordEnabled: channelDiscordEnabled,
            quietHoursEnabled: quietHoursEnabled,
            quietHoursStart: formatTime(quietHoursStart),
            quietHoursEnd: formatTime(quietHoursEnd),
            googleConnected: googleConnected,
            telegramConnected: telegramConnected,
            discordConnected: discordConnected
        )
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(encoded, forKey: settingsKey)
    }

    private func loadLocalSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(LocalSettings.self, from: data) else {
            return
        }

        coachingTone = normalizeTone(decoded.coachingTone)
        dailyReminderEnabled = decoded.dailyReminderEnabled
        weeklyReflectionReminderEnabled = decoded.weeklyReflectionReminderEnabled
        dmCheckinsEnabled = decoded.dmCheckinsEnabled
        streakNudgeEnabled = decoded.streakNudgeEnabled
        weeklyCheckinDay = WeeklyCheckinDayOption(rawValue: decoded.weeklyCheckinDay) ?? .sunday
        weeklyCheckinTime = parseTime(decoded.weeklyCheckinTime) ?? ProfileViewModel.defaultTime(hour: 19, minute: 0)
        timezoneId = decoded.timezoneId
        preferredWeightUnit = WeightUnitOption(rawValue: decoded.preferredWeightUnit) ?? .kg
        preferredHeightUnit = HeightUnitOption(rawValue: decoded.preferredHeightUnit) ?? .cm
        channelInAppEnabled = decoded.channelInAppEnabled
        channelTelegramEnabled = decoded.channelTelegramEnabled
        channelDiscordEnabled = decoded.channelDiscordEnabled
        quietHoursEnabled = decoded.quietHoursEnabled
        quietHoursStart = parseTime(decoded.quietHoursStart) ?? ProfileViewModel.defaultTime(hour: 23, minute: 0)
        quietHoursEnd = parseTime(decoded.quietHoursEnd) ?? ProfileViewModel.defaultTime(hour: 7, minute: 0)
        googleConnected = decoded.googleConnected
        telegramConnected = decoded.telegramConnected
        discordConnected = decoded.discordConnected
    }

    private static func defaultTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
}
