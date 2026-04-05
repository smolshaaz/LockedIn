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
    @Published var isLockPresented = false
    @Published var lockContextDomain: MaxxDomain?

    @Published var logs: [LogEntry] = []
    @Published var lockRealityCheck = "Your schedule exposes your priorities."
    @Published var strategicReminder = "Protect your first 90 minutes today from noise."

    @Published private(set) var homeTasks: [HomeTaskItem] = []
    @Published private(set) var protocolDetails: [MaxxDomain: ProtocolDetailViewState] = [:]
    @Published private(set) var lifeScoreInsights: [MaxxDomain: LifeScoreDomainInsight] = [:]

    @Published private(set) var lifeScoreMovesThisWeek: [String] = []
    @Published private(set) var lifeScoreImproved: [String] = []
    @Published private(set) var lifeScoreSlipped: [String] = []
    @Published private(set) var lifeScoreCauses: [String] = []
    @Published private(set) var lifeScoreNextWeekFocus = ""

    private let calendar = Calendar(identifier: .iso8601)
    private let protocolOrder: [MaxxDomain] = [.gym, .mind, .money, .face, .social]

    init() {
        seedLogs()
        seedHomeTasks()
        seedProtocolDetails()
        seedLifeScoreInsights()
        seedLifeScoreSummary()
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

    var homeQueueState: HomeQueueViewState {
        let latestCompleted = homeTasks
            .filter(\.isCompleted)
            .sorted { lhs, rhs in
                (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
            }
            .first

        let activeTasks = homeTasks
            .filter { !$0.isCompleted }
            .sorted { $0.order < $1.order }

        return HomeQueueViewState(latestCompleted: latestCompleted, activeTasks: activeTasks)
    }

    var homeProgressFraction: Double {
        guard !homeTasks.isEmpty else { return 0 }
        let completedCount = homeTasks.filter(\.isCompleted).count
        return Double(completedCount) / Double(homeTasks.count)
    }

    var homeProgressLabel: String {
        "\(homeTasks.filter(\.isCompleted).count)/\(homeTasks.count)"
    }

    var lifeScoreDeltaThisWeek: Int {
        protocolDetails.values.map(\.weeklyDelta).reduce(0, +)
    }

    var lifeScoreWeekLabel: String {
        "WEEK 14"
    }

    var activeProtocolsCount: Int {
        protocolCards().count
    }

    var biggestIssueCard: ProtocolCardViewState? {
        protocolCards().min(by: { $0.weeklyDelta < $1.weeklyDelta })
    }

    func presentLock(with domain: MaxxDomain? = nil) {
        if let domain {
            lockContextDomain = domain
        }
        isLockPresented = true
    }

    func dismissLock() {
        isLockPresented = false
        lockContextDomain = nil
    }

    func completeHomeTask(_ taskID: UUID) {
        guard let index = homeTasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard !homeTasks[index].isCompleted else { return }

        homeTasks[index].isCompleted = true
        homeTasks[index].completedAt = Date()
    }

    func protocolCards() -> [ProtocolCardViewState] {
        protocolOrder.compactMap { domain in
            guard let detail = protocolDetails[domain] else { return nil }
            return ProtocolCardViewState(
                domain: domain,
                objective: detail.objective,
                score: detail.score,
                weeklyDelta: detail.weeklyDelta,
                statusTone: detail.statusTone,
                lockQuote: detail.lockDiagnosis,
                last7Days: Array(detail.last14Days.first?.dots.suffix(7) ?? []),
                streakDays: detail.streakDays
            )
        }
    }

    func protocolDetail(for domain: MaxxDomain) -> ProtocolDetailViewState {
        protocolDetails[domain] ?? ProtocolDetailViewState(
            domain: domain,
            objective: "Lock one high-leverage objective.",
            score: 50,
            weeklyDelta: 0,
            statusTone: .standard,
            streakDays: 0,
            lockDiagnosis: "No diagnostic yet.",
            lockAction: "Log execution for 3 days to unlock adjustments.",
            plan: [],
            adjustmentNote: "Awaiting execution history.",
            tasks: [],
            last14Days: []
        )
    }

    func toggleProtocolTask(domain: MaxxDomain, taskID: UUID) {
        guard var detail = protocolDetails[domain],
              let index = detail.tasks.firstIndex(where: { $0.id == taskID }) else { return }

        detail.tasks[index].isCompleted.toggle()
        if detail.tasks[index].isCompleted {
            detail.tasks[index].completionNote = detail.tasks[index].completionNote ?? "Done just now"
        } else {
            detail.tasks[index].completionNote = nil
        }

        protocolDetails[domain] = detail
    }

    func lifeScoreInsight(for domain: MaxxDomain) -> LifeScoreDomainInsight {
        lifeScoreInsights[domain] ?? LifeScoreDomainInsight(
            domain: domain,
            headline: "No score insight yet.",
            patternRows: [],
            helped: [],
            hurt: [],
            causes: [],
            lockAdjustments: [],
            moves: []
        )
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

    private func seedLogs() {
        logs = [
            LogEntry(domain: .mind, action: "Completed deep work block", evidence: "90-minute distraction-free sprint", confidence: 4, createdAt: Date().addingTimeInterval(-3_600), cadenceTag: .daily),
            LogEntry(domain: .gym, action: "Progressive overload session", evidence: "Bench +2.5kg, 5 reps", confidence: 5, createdAt: Date().addingTimeInterval(-86_400), cadenceTag: .daily),
            LogEntry(domain: .money, action: "Sent 3 targeted applications", evidence: "Roles: growth analyst, associate PM", confidence: 3, createdAt: Date().addingTimeInterval(-2 * 86_400), cadenceTag: .daily),
            LogEntry(domain: .social, action: "Two intentional social approaches", evidence: "Introduced myself at coworking and gym", confidence: 3, createdAt: Date().addingTimeInterval(-8 * 86_400), cadenceTag: .weekly)
        ]
    }

    private func seedHomeTasks() {
        homeTasks = [
            HomeTaskItem(title: "LockedIn sprint", subtitle: "Core native dev / architecture blocks", order: 0, isCompleted: true, completedAt: Date().addingTimeInterval(-2_400)),
            HomeTaskItem(title: "AnchorNotes maintenance", subtitle: "PWA, sharing logic, UI polish", estimate: "90m", order: 1),
            HomeTaskItem(title: "CFA Level 1", subtitle: "Deep review of the FinTree series", estimate: "60m", order: 2),
            HomeTaskItem(title: "Spiritual anchor", subtitle: "Quran recitation · final juz", estimate: "25m", order: 3),
            HomeTaskItem(title: "Gym session", subtitle: "Push day with progressive overload", estimate: "75m", order: 4),
            HomeTaskItem(title: "LinkedIn outreach", subtitle: "Reply to 5 pending messages", estimate: "30m", order: 5),
            HomeTaskItem(title: "Sleep before 11:30pm", subtitle: "Phone off by 11 · in bed by 11:30", estimate: "rule", order: 6)
        ]
    }

    private func seedProtocolDetails() {
        protocolDetails = [
            .gym: ProtocolDetailViewState(
                domain: .gym,
                objective: "Build lean muscle + strength · push/pull/legs split",
                score: 61,
                weeklyDelta: -11,
                statusTone: .push,
                streakDays: 2,
                lockDiagnosis: "Consistency is slipping. Fix the schedule.",
                lockAction: "Anchor gym sessions before noon for the next 7 days.",
                plan: [
                    ProtocolPlanItem(title: "Push session", cadence: "2x weekly"),
                    ProtocolPlanItem(title: "Pull session", cadence: "2x weekly"),
                    ProtocolPlanItem(title: "Leg day", cadence: "2x weekly"),
                    ProtocolPlanItem(title: "Protein minimum", cadence: "daily")
                ],
                adjustmentNote: "LOCK adjustment - shorten sessions to 60m if schedule slips.",
                tasks: [
                    ProtocolTaskItem(title: "Warm-up mobility", subtitle: "10 minutes dynamic prep", trailingMetric: "10m", isCompleted: true, completionNote: "done 7:20am"),
                    ProtocolTaskItem(title: "Compound lift block", subtitle: "Bench / squat / row", trailingMetric: "60m"),
                    ProtocolTaskItem(title: "Log recovery", subtitle: "Sleep, soreness, hydration", trailingMetric: "5m")
                ],
                last14Days: trendRows([
                    ("Sessions", [true, false, true, false, false, true, false, true, false, true, false, true, false, false]),
                    ("Strength", [false, true, true, false, true, true, false, false, true, true, false, true, false, true]),
                    ("Sleep", [true, true, false, true, false, true, false, true, true, false, true, false, true, false]),
                    ("Meal prep", [true, false, true, true, false, true, false, false, true, false, true, true, false, true])
                ])
            ),
            .mind: ProtocolDetailViewState(
                domain: .mind,
                objective: "3h deep work daily + stabilise sleep before 11:30pm",
                score: 72,
                weeklyDelta: 3,
                statusTone: .push,
                streakDays: 5,
                lockDiagnosis: "Sleep timing is unstable - it's cascading into your deep work output.",
                lockAction: "Anchor sleep at 11pm tonight. No negotiation.",
                plan: [
                    ProtocolPlanItem(title: "Deep work block", cadence: "3h daily"),
                    ProtocolPlanItem(title: "Wind-down routine", cadence: "nightly"),
                    ProtocolPlanItem(title: "Sleep before 11:30pm", cadence: "daily"),
                    ProtocolPlanItem(title: "No phone after 11pm", cadence: "rule")
                ],
                adjustmentNote: "LOCK adjustment - reduce deep work to 2h this week (travel schedule).",
                tasks: [
                    ProtocolTaskItem(title: "Wind-down routine", subtitle: "Lights dim, no screens", isCompleted: true, completionNote: "done 10:45pm"),
                    ProtocolTaskItem(title: "Deep work", subtitle: "3h focused block · no distractions", trailingMetric: "3h"),
                    ProtocolTaskItem(title: "Sleep before 11:30pm", subtitle: "Phone off by 11 · in bed by 11:30"),
                    ProtocolTaskItem(title: "Log sleep time", subtitle: "On wakeup · takes 5 seconds")
                ],
                last14Days: trendRows([
                    ("Deep work", [true, false, true, true, false, false, false, true, true, false, true, true, true, false]),
                    ("Sleep", [false, true, false, true, true, false, true, true, false, true, true, false, true, true]),
                    ("Wind-down", [true, true, false, true, false, true, true, true, true, false, true, true, false, true]),
                    ("No phone", [true, false, true, true, true, false, true, false, true, true, true, false, true, true])
                ])
            ),
            .money: ProtocolDetailViewState(
                domain: .money,
                objective: "Land internship + build freelance pipeline",
                score: 68,
                weeklyDelta: 1,
                statusTone: .push,
                streakDays: 3,
                lockDiagnosis: "Applications are slow. You need 2 per day minimum.",
                lockAction: "Set a fixed 45m outreach block after lunch.",
                plan: [
                    ProtocolPlanItem(title: "Application sprint", cadence: "daily"),
                    ProtocolPlanItem(title: "Portfolio artifact", cadence: "weekly"),
                    ProtocolPlanItem(title: "Follow-up outreach", cadence: "daily")
                ],
                adjustmentNote: "LOCK adjustment - prioritize conversion over volume this week.",
                tasks: [
                    ProtocolTaskItem(title: "Targeted application", subtitle: "Customize resume + pitch", trailingMetric: "45m"),
                    ProtocolTaskItem(title: "Follow-up messages", subtitle: "2 recruiter follow-ups"),
                    ProtocolTaskItem(title: "Track response rate", subtitle: "Update pipeline tracker", trailingMetric: "5m", isCompleted: true, completionNote: "done 8:05pm")
                ],
                last14Days: trendRows([
                    ("Applications", [true, false, false, true, false, true, false, true, false, false, true, false, true, false]),
                    ("Outreach", [false, true, false, false, true, false, true, false, true, false, false, true, false, true]),
                    ("Portfolio", [true, false, true, false, false, true, false, true, false, true, false, false, true, false]),
                    ("Follow-ups", [false, false, true, false, true, false, true, false, false, true, false, true, false, false])
                ])
            ),
            .face: ProtocolDetailViewState(
                domain: .face,
                objective: "Clear skin, defined jawline - 3-step routine",
                score: 70,
                weeklyDelta: 0,
                statusTone: .maintain,
                streakDays: 6,
                lockDiagnosis: "Routine is solid. Don't get lazy with SPF.",
                lockAction: "Hold consistency; no protocol changes needed.",
                plan: [
                    ProtocolPlanItem(title: "Cleanser + moisturizer", cadence: "AM/PM"),
                    ProtocolPlanItem(title: "SPF", cadence: "daily"),
                    ProtocolPlanItem(title: "Hydration target", cadence: "daily")
                ],
                adjustmentNote: "LOCK adjustment - maintain baseline through travel days.",
                tasks: [
                    ProtocolTaskItem(title: "AM skincare", subtitle: "Cleanser + moisturizer + SPF", isCompleted: true, completionNote: "done 8:10am"),
                    ProtocolTaskItem(title: "Hydration", subtitle: "3L water target"),
                    ProtocolTaskItem(title: "PM skincare", subtitle: "Cleanser + recovery layer")
                ],
                last14Days: trendRows([
                    ("AM routine", [true, true, true, true, false, true, true, true, false, true, true, true, false, true]),
                    ("PM routine", [true, false, true, true, false, true, true, false, true, true, false, true, true, false]),
                    ("Hydration", [true, true, false, true, true, false, true, true, false, true, true, false, true, true]),
                    ("SPF", [true, false, true, true, true, false, true, false, true, true, false, true, false, true])
                ])
            ),
            .social: ProtocolDetailViewState(
                domain: .social,
                objective: "Confidence, frame, approach anxiety",
                score: 55,
                weeklyDelta: -2,
                statusTone: .standard,
                streakDays: 1,
                lockDiagnosis: "Isolation is creeping in. Fix that.",
                lockAction: "Commit to one live approach every day this week.",
                plan: [
                    ProtocolPlanItem(title: "One live approach", cadence: "daily"),
                    ProtocolPlanItem(title: "Follow-up message", cadence: "daily"),
                    ProtocolPlanItem(title: "Body language reset", cadence: "nightly")
                ],
                adjustmentNote: "LOCK adjustment - reduce pressure, increase repetition.",
                tasks: [
                    ProtocolTaskItem(title: "Approach rep", subtitle: "Talk to 1 new person", trailingMetric: "1 rep"),
                    ProtocolTaskItem(title: "Follow-up", subtitle: "Send one voice note", isCompleted: true, completionNote: "done 6:20pm"),
                    ProtocolTaskItem(title: "Presence drill", subtitle: "Posture + eye contact check", trailingMetric: "5m")
                ],
                last14Days: trendRows([
                    ("Approaches", [true, false, false, false, true, false, false, true, false, true, false, true, false, false]),
                    ("Follow-ups", [false, false, true, false, false, true, false, false, true, false, true, false, true, false]),
                    ("Presence", [true, false, false, true, false, false, true, false, false, true, false, true, false, false]),
                    ("Outbound msgs", [false, true, false, false, true, false, false, true, false, false, true, false, true, false])
                ])
            )
        ]
    }

    private func seedLifeScoreInsights() {
        lifeScoreInsights = [
            .gym: LifeScoreDomainInsight(
                domain: .gym,
                headline: "GymMaxx dropped because your schedule broke consistency - 2 of 4 sessions done.",
                patternRows: trendRows([
                    ("Sessions", [true, false, true, false, false, true, false]),
                    ("Strength", [false, true, false, true, true, false, false]),
                    ("Recovery", [true, false, true, true, false, true, false])
                ]),
                helped: [
                    "Leg day intensity improved when sessions started before noon.",
                    "Protein consistency stayed stable Tue-Fri."
                ],
                hurt: [
                    "Missed 2 fixed gym slots due to late nights.",
                    "No recovery walk after high-volume day."
                ],
                causes: [
                    "No fixed schedule after 8pm.",
                    "Sleep drift broke morning training rhythm."
                ],
                lockAdjustments: [
                    "Lock 3 fixed gym slots before Monday ends.",
                    "Move heavy compound day to mornings.",
                    "Set sleep alarm at 10:45pm on training days."
                ],
                moves: [
                    "Book Mon/Wed/Fri gym slot now.",
                    "Pack gym bag before bed.",
                    "Log post-workout nutrition immediately."
                ]
            ),
            .mind: LifeScoreDomainInsight(
                domain: .mind,
                headline: "Sleep stabilized mid-week, but deep work still broke on unstructured mornings.",
                patternRows: trendRows([
                    ("Deep work", [true, false, true, false, false, true, false]),
                    ("Sleep", [false, true, false, true, true, false, false]),
                    ("Wind-down", [false, false, true, false, true, true, false])
                ]),
                helped: [
                    "Sleep stabilised Tue-Fri.",
                    "Deep work improved on structured days."
                ],
                hurt: [
                    "No fixed start time delayed sessions.",
                    "Late Saturday broke Sunday and Monday rhythm."
                ],
                causes: [
                    "Morning plan not locked before bedtime.",
                    "Phone access in first 30 minutes after waking."
                ],
                lockAdjustments: [
                    "Reduce deep work target to 2h/day for 1 week.",
                    "Phone out of room during first work block.",
                    "Keep GymMaxx in maintenance mode this week."
                ],
                moves: [
                    "Phone out of room at 10:45pm.",
                    "First deep work block before any messages.",
                    "No caffeine after 4pm."
                ]
            ),
            .money: LifeScoreDomainInsight(
                domain: .money,
                headline: "Pipeline stayed alive, but outreach volume dipped below target.",
                patternRows: trendRows([
                    ("Applications", [true, false, false, true, false, true, false]),
                    ("Follow-ups", [false, true, false, false, true, false, true]),
                    ("Portfolio", [true, false, true, false, false, true, false])
                ]),
                helped: [
                    "Targeted resumes improved callback quality.",
                    "One strong portfolio update lifted relevance."
                ],
                hurt: [
                    "Application count fell below 2/day.",
                    "Follow-up cadence was inconsistent."
                ],
                causes: [
                    "No fixed outreach block.",
                    "Context switching between coding and outreach."
                ],
                lockAdjustments: [
                    "Schedule 45m outreach after lunch daily.",
                    "Ship one portfolio win proof each week.",
                    "Batch follow-ups in a single 20m block."
                ],
                moves: [
                    "Reply to 5 pending LinkedIn messages tonight.",
                    "Submit 2 focused applications tomorrow morning.",
                    "Update outreach tracker before bed."
                ]
            ),
            .face: LifeScoreDomainInsight(
                domain: .face,
                headline: "Routine is stable. Keep consistency and avoid weekend drift.",
                patternRows: trendRows([
                    ("AM routine", [true, true, true, true, false, true, true]),
                    ("PM routine", [true, false, true, true, false, true, false]),
                    ("SPF", [true, true, false, true, true, false, true])
                ]),
                helped: [
                    "Skin routine compliance stayed high.",
                    "Hydration consistency improved skin quality."
                ],
                hurt: [
                    "Two missed PM routines over weekend.",
                    "SPF skipped on one outdoor day."
                ],
                causes: [
                    "Late-night schedule reduced PM consistency."
                ],
                lockAdjustments: [
                    "Keep maintenance mode for 2 weeks.",
                    "Set SPF reminder before leaving home."
                ],
                moves: [
                    "Prepare PM kit by desk.",
                    "Refill hydration bottle twice daily.",
                    "Keep SPF near keys for habit cue."
                ]
            ),
            .social: LifeScoreDomainInsight(
                domain: .social,
                headline: "Social confidence slipped from low exposure frequency this week.",
                patternRows: trendRows([
                    ("Approaches", [true, false, false, false, true, false, false]),
                    ("Follow-ups", [false, false, true, false, false, true, false]),
                    ("Presence", [true, false, false, true, false, false, true])
                ]),
                helped: [
                    "Follow-up voice note created one warm lead."
                ],
                hurt: [
                    "Too few real-world approach reps.",
                    "Missed two social exposure windows."
                ],
                causes: [
                    "Isolation after work hours.",
                    "No pre-planned social route."
                ],
                lockAdjustments: [
                    "One live approach every day this week.",
                    "Pre-plan social locations before 6pm."
                ],
                moves: [
                    "Run one gym conversation opener tonight.",
                    "Send one follow-up voice note.",
                    "Log confidence immediately after each rep."
                ]
            )
        ]
    }

    private func seedLifeScoreSummary() {
        lifeScoreMovesThisWeek = [
            "Lock 3 fixed gym slots before Monday ends.",
            "Deep work before checking any messages.",
            "Reply to 5 pending LinkedIn messages tonight."
        ]

        lifeScoreImproved = [
            "Skincare 7/7",
            "Weight down 0.6kg"
        ]

        lifeScoreSlipped = [
            "Gym 2/4 sessions",
            "Deep work 8h of 21h"
        ]

        lifeScoreCauses = [
            "No fixed schedule",
            "Late nights broke mornings"
        ]

        lifeScoreNextWeekFocus = "Stabilise GymMaxx without letting MoneyMaxx die. One fixed gym time. Applications daily."
    }

    private func trendRows(_ rows: [(String, [Bool])]) -> [ProtocolTrendRow] {
        rows.map { title, dots in
            ProtocolTrendRow(title: title, dots: dots)
        }
    }
}
