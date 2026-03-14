import Foundation
import Combine

struct LogWeekGroup: Identifiable {
    let weekStart: Date
    let entries: [LogEntry]
    var id: Date { weekStart }
}

@MainActor
final class ExperienceStore: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var logs: [LogEntry] = []
    @Published var todayProtocolActions: [ProtocolActionItem] = []
    @Published var criticalAlerts: [String] = []
    @Published var lockRealityCheck = "Your schedule exposes your priorities."
    @Published var strategicReminder = "Protect your first 90 minutes today from noise."
    @Published private(set) var domainStates: [MaxxDomain: DomainOSState] = [:]

    private let calendar = Calendar(identifier: .iso8601)

    init() {
        seedLogs()
        seedProtocolActions()
        seedDomainStates()
        seedAlerts()
    }

    var streakCount: Int {
        let uniqueDays = Set(logs.map { calendar.startOfDay(for: $0.createdAt) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())

        while uniqueDays.contains(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = previousDay
        }

        return streak
    }

    var insightDrivers: [String] {
        let recent = logs.sorted { $0.createdAt > $1.createdAt }.prefix(4)
        if recent.isEmpty {
            return ["Start logging daily actions to unlock score drivers."]
        }

        return recent.map { entry in
            "\(entry.domain.shortTitle): \(entry.action)"
        }
    }

    func weeklyReflection(currentScore: Int?) -> WeeklyReflectionViewState {
        let thisWeek = logs.filter { calendar.isDate($0.createdAt, equalTo: Date(), toGranularity: .weekOfYear) }

        let lastWeekReference = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let lastWeek = logs.filter {
            calendar.isDate($0.createdAt, equalTo: lastWeekReference, toGranularity: .weekOfYear)
        }

        let lastWeekConfidence = lastWeek.isEmpty
            ? 60
            : Int(lastWeek.map(\.confidence).reduce(0, +) / max(lastWeek.count, 1)) * 12

        let state: String
        if thisWeek.count >= 5 {
            state = "You are in control this week. Keep the rhythm."
        } else if thisWeek.count >= 2 {
            state = "On pace. Stack two more clean days to lock momentum."
        } else {
            state = "Week is still recoverable. Start with one decisive action today."
        }

        let uplift: String
        if thisWeek.count == 0 {
            uplift = "Strong upside: 2 focused days can still lift this week meaningfully."
        } else {
            uplift = "Your next 3 logs have high leverage on this week’s outcome."
        }

        return WeeklyReflectionViewState(
            lastWeekScore: currentScore ?? min(95, max(48, lastWeekConfidence)),
            currentWeekState: state,
            upliftPotential: uplift,
            drivers: insightDrivers
        )
    }

    func executeTopProtocolAction() -> String {
        if let index = todayProtocolActions.firstIndex(where: { !$0.isCompleted }) {
            todayProtocolActions[index].isCompleted = true
            if !criticalAlerts.isEmpty {
                criticalAlerts.removeFirst()
            }
            return "Top protocol executed. Log the evidence while details are fresh."
        }

        return "All top actions are complete. Use Quick Log to record execution quality."
    }

    func addLog(_ entry: LogEntry) {
        logs.insert(entry, at: 0)
    }

    func updateLog(_ entry: LogEntry) {
        guard let index = logs.firstIndex(where: { $0.id == entry.id }) else { return }
        logs[index] = entry
    }

    func deleteLog(_ entry: LogEntry) {
        logs.removeAll { $0.id == entry.id }
    }

    func filteredLogs(domain: MaxxDomain?, date: Date?) -> [LogEntry] {
        logs
            .filter { entry in
                let domainMatch = domain == nil || entry.domain == domain
                let dateMatch: Bool
                if let date {
                    dateMatch = calendar.isDate(entry.createdAt, inSameDayAs: date)
                } else {
                    dateMatch = true
                }
                return domainMatch && dateMatch
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func groupedLogs(domain: MaxxDomain?, date: Date?) -> [LogWeekGroup] {
        let grouped = Dictionary(grouping: filteredLogs(domain: domain, date: date)) { entry in
            calendar.dateInterval(of: .weekOfYear, for: entry.createdAt)?.start ?? calendar.startOfDay(for: entry.createdAt)
        }

        return grouped
            .map { LogWeekGroup(weekStart: $0.key, entries: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.weekStart > $1.weekStart }
    }

    func state(for domain: MaxxDomain) -> DomainOSState {
        domainStates[domain] ?? DomainOSState(
            domain: domain,
            level: "L1",
            compliance: 50,
            nextMove: "Lock one high-leverage action.",
            protocolStack: ["Baseline protocol"],
            dailyActions: [],
            metrics: [],
            resources: [],
            reflections: []
        )
    }

    func toggleDomainAction(domain: MaxxDomain, actionID: UUID) {
        guard var state = domainStates[domain],
              let index = state.dailyActions.firstIndex(where: { $0.id == actionID }) else { return }

        state.dailyActions[index].isCompleted.toggle()
        let completedCount = state.dailyActions.filter(\.isCompleted).count
        let ratio = Double(completedCount) / Double(max(1, state.dailyActions.count))
        state.compliance = Int((ratio * 100).rounded())
        domainStates[domain] = state
    }

    private func seedLogs() {
        logs = [
            LogEntry(domain: .mind, action: "Completed deep work block", evidence: "90-minute distraction-free sprint", confidence: 4, createdAt: Date().addingTimeInterval(-3600), cadenceTag: .daily),
            LogEntry(domain: .gym, action: "Progressive overload session", evidence: "Bench +2.5kg, 5 reps", confidence: 5, createdAt: Date().addingTimeInterval(-86_400), cadenceTag: .daily),
            LogEntry(domain: .money, action: "Sent 3 targeted applications", evidence: "Roles: growth analyst, associate PM", confidence: 3, createdAt: Date().addingTimeInterval(-2 * 86_400), cadenceTag: .daily),
            LogEntry(domain: .social, action: "Two intentional social approaches", evidence: "Introduced myself at coworking and gym", confidence: 3, createdAt: Date().addingTimeInterval(-8 * 86_400), cadenceTag: .weekly)
        ]
    }

    private func seedProtocolActions() {
        todayProtocolActions = [
            ProtocolActionItem(title: "Mind: 90-minute deep work sprint", domain: .mind, isCompleted: false),
            ProtocolActionItem(title: "Gym: high-intensity compound lift session", domain: .gym, isCompleted: false),
            ProtocolActionItem(title: "Money: one leverage outreach", domain: .money, isCompleted: true)
        ]
    }

    private func seedAlerts() {
        criticalAlerts = [
            "Sleep consistency dropped below target this week.",
            "No FaceMaxx routine log in the last 48 hours."
        ]
    }

    private func seedDomainStates() {
        MaxxDomain.allCases.forEach { domain in
            let compliance = baseCompliance(for: domain)
            domainStates[domain] = DomainOSState(
                domain: domain,
                level: "L2",
                compliance: compliance,
                nextMove: nextMove(for: domain),
                protocolStack: protocolStack(for: domain),
                dailyActions: [
                    ProtocolActionItem(title: "Primary action block", domain: domain, isCompleted: false),
                    ProtocolActionItem(title: "Review execution quality", domain: domain, isCompleted: false),
                    ProtocolActionItem(title: "Plan next adjustment", domain: domain, isCompleted: true)
                ],
                metrics: metrics(for: domain),
                resources: resources(for: domain),
                reflections: [
                    "What worked this week in \(domain.title)?",
                    "What friction repeated and why?",
                    "What single adjustment will compound next week?"
                ]
            )
        }
    }

    private func baseCompliance(for domain: MaxxDomain) -> Int {
        switch domain {
        case .gym: return 78
        case .face: return 63
        case .money: return 69
        case .mind: return 74
        case .social: return 58
        }
    }

    private func nextMove(for domain: MaxxDomain) -> String {
        switch domain {
        case .gym: return "Lock 3 progressive overload sessions before Sunday."
        case .face: return "Standardize AM/PM grooming routine for 7 days."
        case .money: return "Ship one portfolio artifact this week."
        case .mind: return "Protect your first deep-work block daily."
        case .social: return "Initiate 3 high-quality conversations."
        }
    }

    private func protocolStack(for domain: MaxxDomain) -> [String] {
        switch domain {
        case .gym:
            return ["Strength microcycle", "Protein floor + hydration", "Deload trigger rule"]
        case .face:
            return ["Skin baseline routine", "Haircut cadence", "Style upgrade checklist"]
        case .money:
            return ["Skill compounding lane", "Application sprint", "Negotiation prep loop"]
        case .mind:
            return ["Sleep lock protocol", "Deep work schedule", "Weekly reset ritual"]
        case .social:
            return ["Conversation opener set", "Body language reps", "Approach anxiety exposure"]
        }
    }

    private func metrics(for domain: MaxxDomain) -> [DomainMetric] {
        switch domain {
        case .gym:
            return [DomainMetric(title: "Sessions", value: "3/4"), DomainMetric(title: "PR Trend", value: "+6%")]
        case .face:
            return [DomainMetric(title: "Routine Adherence", value: "5/7"), DomainMetric(title: "Grooming Quality", value: "8/10")]
        case .money:
            return [DomainMetric(title: "Skill Hours", value: "6h"), DomainMetric(title: "Outreach", value: "4")]
        case .mind:
            return [DomainMetric(title: "Deep Work", value: "8.5h"), DomainMetric(title: "Sleep Avg", value: "7h 12m")]
        case .social:
            return [DomainMetric(title: "Initiations", value: "5"), DomainMetric(title: "Follow-ups", value: "3")]
        }
    }

    private func resources(for domain: MaxxDomain) -> [String] {
        switch domain {
        case .gym:
            return ["Compound lift checklist", "Warm-up flow", "Recovery protocol"]
        case .face:
            return ["Skincare matrix", "Hair style board", "Outfit fit guide"]
        case .money:
            return ["Interview question bank", "Portfolio template", "Skill roadmap"]
        case .mind:
            return ["Focus sprint template", "Sleep wind-down sequence", "Weekly planning sheet"]
        case .social:
            return ["Conversation framework", "Approach scripts", "Presence cues"]
        }
    }
}
