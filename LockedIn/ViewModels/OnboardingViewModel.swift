import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
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
    @Published var weightText = ""
    @Published var weightUnit: WeightUnit = .kg
    @Published var targetWeightText = ""

    @Published var sleepTime = OnboardingViewModel.defaultDate(hour: 23, minute: 0)
    @Published var wakeTime = OnboardingViewModel.defaultDate(hour: 7, minute: 0)

    @Published var dailyHours: Double = 2.0
    @Published var monthlyBudget: Double = 3000

    @Published var gymAccess = ""
    @Published var dietPreferences: Set<String> = []

    @Published var primaryGoal = ""
    @Published var secondaryGoals: Set<String> = []

    @Published var currentPhase = ""
    @Published var biggestWeakness = ""

    @Published var ninetyDayGoal = ""
    @Published var biggestObstacle = ""
    @Published var motivationAnchor = ""

    @Published var lockTone: LockTone?
    @Published var notificationStyle: NotificationStyle?

    @Published var errorMessage: String?

    let totalQuestionSteps = 20

    let roleOptions = ["Student", "Working (employed)", "Freelancing", "In between"]
    let gymOptions = ["Full gym", "Home setup", "No equipment"]
    let dietOptions = [
        "No restrictions",
        "Vegetarian",
        "Vegan",
        "No gluten",
        "Dairy free",
        "High protein focus"
    ]
    let goalOptions = [
        "Build physique",
        "Fix my looks",
        "Make more money",
        "Focus harder",
        "Better social life",
        "Fix my life overall"
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
        "Procrastination"
    ]

    init() {
        if usesINR {
            monthlyBudget = 3000
        } else {
            monthlyBudget = 80
        }
    }

    var isFinalAnalysisStep: Bool {
        step == 21
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
        goalOptions.filter { $0 != primaryGoal }
    }

    var secondarySelectionCountLabel: String {
        "\(secondaryGoals.count)/2 selected"
    }

    var usesINR: Bool {
        let currency = Locale.current.currency?.identifier ?? Locale.current.currencyCode ?? ""
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
        if biggestWeakness == "Consistency" { score -= 2 }

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
            return parsedDouble(from: heightCmText) != nil
        case 5:
            return parsedDouble(from: weightText) != nil
        case 6:
            return true
        case 7:
            return true
        case 8:
            return true
        case 9:
            return true
        case 10:
            return !gymAccess.isEmpty
        case 11:
            return !dietPreferences.isEmpty
        case 12:
            return !primaryGoal.isEmpty
        case 13:
            return secondaryGoals.count <= 2
        case 14:
            return !currentPhase.isEmpty
        case 15:
            return !biggestWeakness.isEmpty
        case 16:
            return !trimmed(ninetyDayGoal).isEmpty
        case 17:
            return !trimmed(biggestObstacle).isEmpty
        case 18:
            return !trimmed(motivationAnchor).isEmpty && motivationAnchor.count <= 80
        case 19:
            return lockTone != nil
        case 20:
            return notificationStyle != nil
        default:
            return true
        }
    }

    func goNext() {
        guard step < 21 else { return }
        step += 1
    }

    func goBack() {
        guard step > 1 else { return }
        step -= 1
    }

    func skipOptionalTargetWeightStep() {
        guard step == 6 else { return }
        goNext()
    }

    func toggleDiet(_ option: String) {
        if dietPreferences.contains(option) {
            dietPreferences.remove(option)
            return
        }

        if option == "No restrictions" {
            dietPreferences = [option]
            return
        }

        dietPreferences.remove("No restrictions")
        dietPreferences.insert(option)
    }

    func toggleSecondaryGoal(_ goal: String) {
        if secondaryGoals.contains(goal) {
            secondaryGoals.remove(goal)
            return
        }

        guard secondaryGoals.count < 2 else { return }
        secondaryGoals.insert(goal)
    }

    func clampMotivation() {
        if motivationAnchor.count > 80 {
            motivationAnchor = String(motivationAnchor.prefix(80))
        }
    }

    func buildProfile(userId: String) -> UserProfile {
        let cleanedName = trimmed(name)
        let ageValue = parsedInt(from: ageText)
        let heightCm = parsedDouble(from: heightCmText)
        let weightKg = convertedWeightToKg(from: weightText)
        let targetWeightKg = convertedWeightToKg(from: targetWeightText)

        let primary = primaryGoal
        let secondary = Array(secondaryGoals)
        let goals = [primary] + secondary

        var constraints: [String] = []
        if !role.isEmpty { constraints.append("Role: \(role)") }
        if !currentPhase.isEmpty { constraints.append("Phase: \(currentPhase)") }
        if !biggestWeakness.isEmpty { constraints.append("Weakness: \(biggestWeakness)") }
        if !trimmed(biggestObstacle).isEmpty { constraints.append("Obstacle: \(trimmed(biggestObstacle))") }

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
            dietPreferences: Array(dietPreferences),
            primaryGoal: primary,
            secondaryGoals: secondary,
            currentPhase: currentPhase,
            biggestWeakness: biggestWeakness,
            ninetyDayGoal: trimmed(ninetyDayGoal),
            biggestObstacle: trimmed(biggestObstacle),
            motivationAnchor: trimmed(motivationAnchor),
            lockTone: lockTone?.rawValue,
            notificationStyle: notificationStyle?.rawValue,
            startingLifeScore: computedStartingLifeScore,
            onboardingCompleted: true
        )
    }

    private var sleepDurationHours: Double {
        let calendar = Calendar.current
        var start = sleepTime
        var end = wakeTime

        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }

        return end.timeIntervalSince(start) / 3_600
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
        case "Better social life":
            return [.social]
        case "Fix my life overall":
            return [.mind, .money, .gym, .social]
        default:
            return []
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
