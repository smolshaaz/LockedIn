import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum HeightUnit: String, CaseIterable, Identifiable {
        case cm
        case ftIn = "ft+in"

        var id: String { rawValue }
    }

    enum WeightUnit: String, CaseIterable, Identifiable {
        case kg
        case lbs

        var id: String { rawValue }
    }

    enum LockTone: String, CaseIterable, Identifiable {
        case blunt
        case firm
        case measured

        var id: String { rawValue }

        var title: String {
            switch self {
            case .blunt: return "Blunt"
            case .firm: return "Firm"
            case .measured: return "Measured"
            }
        }

        var subtitle: String {
            switch self {
            case .blunt: return "No filter. Straight facts."
            case .firm: return "Direct but not brutal."
            case .measured: return "Honest but patient."
            }
        }
    }

    enum NotificationStyle: String, CaseIterable, Identifiable {
        case active
        case passive

        var id: String { rawValue }

        var title: String {
            switch self {
            case .active: return "Active"
            case .passive: return "Passive"
            }
        }

        var subtitle: String {
            switch self {
            case .active:
                return "LOCK messages me with check-ins and nudges"
            case .passive:
                return "I come to LOCK when I need it"
            }
        }
    }

    @Published var step = 1

    @Published var name = ""
    @Published var ageText = ""
    @Published var role = ""

    @Published var heightCmText = ""
    @Published var heightFeetText = ""
    @Published var heightInchesText = ""
    @Published var heightUnit: HeightUnit = .cm
    @Published var weightText = ""
    @Published var weightUnit: WeightUnit = .kg
    @Published var targetWeightText = ""

    @Published var sleepTime = OnboardingViewModel.defaultDate(hour: 23, minute: 0)
    @Published var wakeTime = OnboardingViewModel.defaultDate(hour: 7, minute: 0)

    @Published var dailyHours: Double = 2.0
    @Published var monthlyBudget: Double = 3000

    @Published var gymAccess = ""
    @Published var dietPreferences: Set<String> = []
    @Published var customDietPreference = ""

    @Published var primaryGoal = ""
    @Published var primaryGoalOtherText = ""
    @Published var secondaryGoals: Set<String> = []
    @Published var secondaryGoalOtherText = ""

    @Published var currentPhase = ""
    @Published var biggestWeaknesses: Set<String> = []
    @Published var biggestWeaknessOtherText = ""

    @Published var ninetyDayGoal = ""
    @Published var biggestObstacles: Set<String> = []
    @Published var biggestObstacleOtherText = ""
    @Published var biggestObstacleContext = ""
    @Published var motivationAnchor = ""

    @Published var lockTone: LockTone?
    @Published var notificationStyle: NotificationStyle?
    @Published var requestedMaxxes: Set<MaxxDomain> = []
    @Published var maxxContextNotes: [String: String] = [:]

    @Published var errorMessage: String?
    @Published var selectionFeedback: String?

    let totalQuestionSteps = 21

    let roleOptions = ["Student", "Working (employed)", "Freelancing", "In between"]
    let gymOptions = ["Full gym", "Home setup", "No equipment"]
    let dietOptions = [
        "No restrictions",
        "Vegetarian",
        "Vegan",
        "No gluten",
        "High protein focus",
        "Other"
    ]
    let goalOptions = [
        "Build physique",
        "Fix my looks",
        "Make more money",
        "Focus harder",
        "Academics",
        "Better social life",
        "Fix my life overall",
        "Other"
    ]
    let phaseOptions = [
        "Grinding hard",
        "Rebuilding from a setback",
        "Maintaining and refining",
        "Starting from zero",
        "In a transition period"
    ]
    let weaknessOptions = [
        "Consistency",
        "Distraction / focus",
        "Discipline with food",
        "Social confidence",
        "Money management",
        "Procrastination",
        "Time management",
        "Other"
    ]
    let obstacleOptions = [
        "No clear plan",
        "Inconsistent routine",
        "Low energy",
        "Phone distractions",
        "Fear of judgment",
        "No accountability",
        "Overthinking",
        "Other"
    ]

    init() {
        if usesINR {
            monthlyBudget = 3000
        } else {
            monthlyBudget = 80
        }
    }

    var isFinalAnalysisStep: Bool {
        step == 22
    }

    var progress: Double {
        Double(max(1, min(step, totalQuestionSteps))) / Double(totalQuestionSteps)
    }

    var progressLabel: String {
        "\(min(step, totalQuestionSteps)) / \(totalQuestionSteps)"
    }

    var canGoBack: Bool {
        step > 1 && !isFinalAnalysisStep
    }

    var secondaryGoalOptions: [String] {
        goalOptions.filter { option in
            if option == "Other" { return true }
            return option != primaryGoal
        }
    }

    var secondarySelectionCountLabel: String {
        "\(secondaryGoals.count)/2 selected"
    }

    var maxxSelectionCountLabel: String {
        "\(requestedMaxxes.count) selected"
    }

    var resolvedPrimaryGoal: String {
        if primaryGoal == "Other" {
            let custom = trimmed(primaryGoalOtherText)
            if custom.isEmpty { return "Other" }
            return custom
        }
        return primaryGoal
    }

    var sortedRequestedMaxxes: [MaxxDomain] {
        requestedMaxxes.sorted { $0.rawValue < $1.rawValue }
    }

    var resolvedRequestedMaxxes: [String] {
        sortedRequestedMaxxes.map(\.title)
    }

    var biggestWeaknessSummary: String {
        let resolved = resolvedWeaknesses()
        return resolved.isEmpty ? "" : resolved.joined(separator: ", ")
    }

    var biggestObstacleSummary: String {
        let resolved = resolvedObstacles()
        return resolved.isEmpty ? "" : resolved.joined(separator: ", ")
    }

    var usesINR: Bool {
        let currency = Locale.current.currency?.identifier ?? ""
        return currency.uppercased() == "INR"
    }

    var budgetRange: ClosedRange<Double> {
        usesINR ? 0...10_000 : 0...200
    }

    var budgetStep: Double {
        usesINR ? 500 : 10
    }

    var budgetPrefix: String {
        usesINR ? "₹" : "$"
    }

    var dailyHoursDisplay: String {
        if dailyHours.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", dailyHours)
        }
        return String(format: "%.1f", dailyHours)
    }

    var budgetDisplay: String {
        "\(budgetPrefix)\(Int(monthlyBudget))"
    }

    var motivationCountLabel: String {
        "\(motivationAnchor.count)/80"
    }

    var computedStartingLifeScore: Int {
        var score = 50

        if gymAccess == "Full gym" || gymAccess == "Home setup" { score += 5 }
        if dietPreferences.contains("High protein focus") { score += 3 }
        if dailyHours >= 2 { score += 4 }
        if dailyHours >= 3.5 { score += 2 }

        let sleepHours = sleepDurationHours
        if sleepHours >= 7 && sleepHours <= 9 {
            score += 4
        } else if sleepHours < 6 {
            score -= 4
        }

        switch lockTone {
        case .blunt:
            score += 2
        case .firm:
            score += 1
        case .measured, .none:
            break
        }

        if notificationStyle == .active { score += 2 }
        if biggestWeaknesses.contains("Consistency") { score -= 2 }
        if biggestObstacles.contains("No accountability") { score -= 2 }
        if biggestObstacles.contains("Inconsistent routine") { score -= 2 }

        return min(max(score, 20), 95)
    }

    var canContinueCurrentStep: Bool {
        switch step {
        case 1:
            return !trimmed(name).isEmpty
        case 2:
            return parsedInt(from: ageText) != nil
        case 3:
            return !role.isEmpty
        case 4:
            return parsedHeightCm() != nil && parsedDouble(from: weightText) != nil
        case 5:
            return true
        case 6:
            return true
        case 7:
            return true
        case 8:
            return true
        case 9:
            return !gymAccess.isEmpty
        case 10:
            let hasSelection = !dietPreferences.isEmpty
            let otherIsValid = !dietPreferences.contains("Other") || !trimmed(customDietPreference).isEmpty
            return hasSelection && otherIsValid
        case 11:
            if primaryGoal.isEmpty { return false }
            if primaryGoal == "Other" {
                return !trimmed(primaryGoalOtherText).isEmpty
            }
            return true
        case 12:
            if secondaryGoals.count > 2 { return false }
            if secondaryGoals.contains("Other") {
                return !trimmed(secondaryGoalOtherText).isEmpty
            }
            return true
        case 13:
            return !currentPhase.isEmpty
        case 14:
            if biggestWeaknesses.isEmpty { return false }
            if biggestWeaknesses.contains("Other") {
                return !trimmed(biggestWeaknessOtherText).isEmpty
            }
            return true
        case 15:
            return !trimmed(ninetyDayGoal).isEmpty
        case 16:
            if biggestObstacles.isEmpty { return false }
            if biggestObstacles.contains("Other") {
                return !trimmed(biggestObstacleOtherText).isEmpty
            }
            return true
        case 17:
            return !trimmed(motivationAnchor).isEmpty && motivationAnchor.count <= 80
        case 18:
            return lockTone != nil
        case 19:
            return notificationStyle != nil
        case 20:
            return !requestedMaxxes.isEmpty
        case 21:
            for domain in requestedMaxxes {
                if trimmed(maxxContextNotes[domain.rawValue] ?? "").isEmpty {
                    return false
                }
            }
            return !requestedMaxxes.isEmpty
        default:
            return true
        }
    }

    func goNext() {
        guard step < 22 else { return }
        step += 1
    }

    func goBack() {
        guard step > 1 else { return }
        step -= 1
    }

    func skipOptionalTargetWeightStep() {
        guard step == 5 else { return }
        goNext()
    }

    func toggleDiet(_ option: String) {
        selectionFeedback = nil

        if dietPreferences.contains(option) {
            dietPreferences.remove(option)
            if option == "Other" {
                customDietPreference = ""
            }
            return
        }

        if option == "No restrictions" {
            dietPreferences = [option]
            customDietPreference = ""
            return
        }

        dietPreferences.remove("No restrictions")
        dietPreferences.insert(option)
    }

    func toggleSecondaryGoal(_ goal: String) {
        selectionFeedback = nil

        if goal == primaryGoal {
            selectionFeedback = "\"\(resolvedPrimaryGoal)\" is already your main focus."
            return
        }

        if secondaryGoals.contains(goal) {
            secondaryGoals.remove(goal)
            if goal == "Other" {
                secondaryGoalOtherText = ""
            }
            return
        }

        guard secondaryGoals.count < 2 else {
            selectionFeedback = "You can select up to 2 secondary focuses."
            return
        }
        secondaryGoals.insert(goal)
    }

    func toggleWeakness(_ weakness: String) {
        selectionFeedback = nil

        if biggestWeaknesses.contains(weakness) {
            biggestWeaknesses.remove(weakness)
            if weakness == "Other" {
                biggestWeaknessOtherText = ""
            }
            return
        }

        biggestWeaknesses.insert(weakness)
    }

    func toggleObstacle(_ obstacle: String) {
        selectionFeedback = nil

        if biggestObstacles.contains(obstacle) {
            biggestObstacles.remove(obstacle)
            if obstacle == "Other" {
                biggestObstacleOtherText = ""
            }
            return
        }

        biggestObstacles.insert(obstacle)
    }

    func toggleRequestedMaxx(_ domain: MaxxDomain) {
        selectionFeedback = nil

        if requestedMaxxes.contains(domain) {
            requestedMaxxes.remove(domain)
            maxxContextNotes.removeValue(forKey: domain.rawValue)
            return
        }

        requestedMaxxes.insert(domain)
    }

    func maxxContextNote(for domain: MaxxDomain) -> String {
        maxxContextNotes[domain.rawValue] ?? ""
    }

    func setMaxxContextNote(_ note: String, for domain: MaxxDomain) {
        maxxContextNotes[domain.rawValue] = note
    }

    func maxxContextPrompt(for domain: MaxxDomain) -> String {
        switch domain {
        case .gym:
            return "Training status, injuries, equipment, current lifts, and what has failed before."
        case .face:
            return "Skin/hair concerns, current routine, budget, and timeline expectations."
        case .money:
            return "Current income setup, skill level, available time, and income target."
        case .mind:
            return "Focus issues, stress triggers, schedule constraints, and attention drains."
        case .social:
            return "Where social confidence breaks down, contexts that trigger anxiety, and your target behavior."
        }
    }

    func clampMotivation() {
        if motivationAnchor.count > 80 {
            motivationAnchor = String(motivationAnchor.prefix(80))
        }
    }

    func buildProfile(userId: String) -> UserProfile {
        let cleanedName = trimmed(name)
        let ageValue = parsedInt(from: ageText)
        let heightCm = parsedHeightCm()
        let weightKg = convertedWeightToKg(from: weightText)
        let targetWeightKg = convertedWeightToKg(from: targetWeightText)

        let resolvedDietPreferences = dietPreferencePayload()
        let resolvedWeaknessList = resolvedWeaknesses()
        let resolvedObstacleList = resolvedObstacles()
        let resolvedSecondaryGoals = resolvedSecondaryGoalsPayload()

        let primary = resolvedPrimaryGoal
        let secondary = resolvedSecondaryGoals
        let maxxGoals = resolvedRequestedMaxxes
        let goals = maxxGoals.isEmpty ? ([primary] + secondary) : maxxGoals

        var constraints: [String] = []
        if !role.isEmpty { constraints.append("Role: \(role)") }
        if !currentPhase.isEmpty { constraints.append("Phase: \(currentPhase)") }
        if !resolvedWeaknessList.isEmpty { constraints.append("Weaknesses: \(resolvedWeaknessList.joined(separator: ", "))") }
        if !resolvedObstacleList.isEmpty { constraints.append("Obstacles: \(resolvedObstacleList.joined(separator: ", "))") }
        if !trimmed(biggestObstacleContext).isEmpty { constraints.append("Obstacle context: \(trimmed(biggestObstacleContext))") }

        let baselinePayload = baselineScores(primary: primary, secondaries: secondary)

        return UserProfile(
            userId: userId,
            name: cleanedName,
            age: ageValue,
            goals: goals.filter { !$0.isEmpty },
            constraints: constraints,
            communicationStyle: (lockTone?.rawValue ?? "firm").capitalized,
            baseline: baselinePayload,
            role: role,
            heightCm: heightCm,
            weightKg: weightKg,
            targetWeightKg: targetWeightKg,
            sleepTime: sleepTime,
            wakeTime: wakeTime,
            dailyHours: dailyHours,
            monthlyBudget: monthlyBudget,
            gymAccess: gymAccess,
            dietPreferences: resolvedDietPreferences,
            primaryGoal: primary,
            secondaryGoals: secondary,
            currentPhase: currentPhase,
            biggestWeakness: resolvedWeaknessList.joined(separator: ", "),
            ninetyDayGoal: trimmed(ninetyDayGoal),
            biggestObstacle: resolvedObstaclePayload(resolvedObstacleList),
            motivationAnchor: trimmed(motivationAnchor),
            lockTone: lockTone?.rawValue,
            notificationStyle: notificationStyle?.rawValue,
            requestedMaxxes: maxxGoals,
            maxxContextNotes: maxxContextNotes,
            startingLifeScore: computedStartingLifeScore,
            onboardingCompleted: true,
            weeklyCheckinDay: "Sunday",
            weeklyCheckinTime: "19:00",
            timezoneId: TimeZone.current.identifier,
            preferredWeightUnit: weightUnit.rawValue,
            preferredHeightUnit: heightUnit == .cm ? "cm" : "ft-in",
            channelInAppEnabled: true,
            channelTelegramEnabled: false,
            channelDiscordEnabled: false,
            quietHoursEnabled: false,
            quietHoursStart: "23:00",
            quietHoursEnd: "07:00",
            googleConnected: false,
            telegramConnected: false,
            discordConnected: false
        )
    }

    private var sleepDurationHours: Double {
        let calendar = Calendar.current
        let start = sleepTime
        var end = wakeTime

        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }

        return end.timeIntervalSince(start) / 3_600
    }

    private func dietPreferencePayload() -> [String] {
        var ordered = dietOptions.filter { dietPreferences.contains($0) && $0 != "Other" }

        if dietPreferences.contains("Other") {
            let custom = trimmed(customDietPreference)
            if custom.isEmpty {
                ordered.append("Other")
            } else {
                ordered.append("Other: \(custom)")
            }
        }

        return ordered
    }

    private func resolvedSecondaryGoalsPayload() -> [String] {
        var goals = Array(
            secondaryGoals.filter { $0 != "Other" }
        )

        if secondaryGoals.contains("Other") {
            let custom = trimmed(secondaryGoalOtherText)
            if custom.isEmpty {
                goals.append("Other")
            } else {
                goals.append(custom)
            }
        }

        return goals
    }

    private func resolvedWeaknesses() -> [String] {
        var values = weaknessOptions
            .filter { biggestWeaknesses.contains($0) && $0 != "Other" }

        if biggestWeaknesses.contains("Other") {
            let custom = trimmed(biggestWeaknessOtherText)
            if custom.isEmpty {
                values.append("Other")
            } else {
                values.append(custom)
            }
        }

        return values
    }

    private func resolvedObstacles() -> [String] {
        var values = obstacleOptions
            .filter { biggestObstacles.contains($0) && $0 != "Other" }

        if biggestObstacles.contains("Other") {
            let custom = trimmed(biggestObstacleOtherText)
            if custom.isEmpty {
                values.append("Other")
            } else {
                values.append(custom)
            }
        }

        return values
    }

    private func resolvedObstaclePayload(_ values: [String]) -> String {
        let cleanedValues = values.filter { !$0.isEmpty }
        let context = trimmed(biggestObstacleContext)

        if cleanedValues.isEmpty {
            return context
        }

        if context.isEmpty {
            return cleanedValues.joined(separator: ", ")
        }

        return "\(cleanedValues.joined(separator: ", ")) | Context: \(context)"
    }

    private func baselineScores(primary: String, secondaries: [String]) -> [String: Double] {
        var map: [MaxxDomain: Double] = [
            .gym: 52,
            .face: 52,
            .money: 52,
            .mind: 52,
            .social: 52
        ]

        for domain in domains(for: primary) {
            map[domain] = max((map[domain] ?? 52) + 10, 0)
        }

        for goal in secondaries {
            for domain in domains(for: goal) {
                map[domain] = max((map[domain] ?? 52) + 5, 0)
            }
        }

        return Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value) })
    }

    private func domains(for goal: String) -> [MaxxDomain] {
        switch goal {
        case "Build physique":
            return [.gym]
        case "Fix my looks":
            return [.face]
        case "Make more money":
            return [.money]
        case "Focus harder":
            return [.mind]
        case "Academics":
            return [.mind]
        case "Better social life":
            return [.social]
        case "Fix my life overall":
            return [.mind, .money, .gym, .social]
        default:
            return []
        }
    }

    private func parsedHeightCm() -> Double? {
        switch heightUnit {
        case .cm:
            return parsedDouble(from: heightCmText)
        case .ftIn:
            guard let feet = parsedDouble(from: heightFeetText) else { return nil }
            let inches = parsedDoubleAllowZero(from: heightInchesText) ?? 0
            guard feet > 0, inches >= 0, inches < 12 else { return nil }
            return feet * 30.48 + inches * 2.54
        }
    }

    private func convertedWeightToKg(from text: String) -> Double? {
        guard let value = parsedDouble(from: text) else { return nil }
        if weightUnit == .kg { return value }
        return value * 0.453_592_37
    }

    private func parsedInt(from text: String) -> Int? {
        guard let number = Int(trimmed(text)), number > 0 else { return nil }
        return number
    }

    private func parsedDouble(from text: String) -> Double? {
        guard let number = Double(trimmed(text)), number > 0 else { return nil }
        return number
    }

    private func parsedDoubleAllowZero(from text: String) -> Double? {
        guard let number = Double(trimmed(text)), number >= 0 else { return nil }
        return number
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func defaultDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
}
