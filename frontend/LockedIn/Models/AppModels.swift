import Foundation
import CoreGraphics

enum AppLaunchPhase: String {
    case splash
    case welcome
    case onboarding
    case ready
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case protocols
    case lifeScore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .protocols: return "Protocols"
        case .lifeScore: return "LifeScore"
        }
    }

    var icon: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .protocols: return "list.bullet.rectangle.portrait.fill"
        case .lifeScore: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum HomeModule: String, CaseIterable {
    case brief
    case todayPlan
    case alerts
    case quickLog
    case reflection
}

enum MaxxDomain: String, CaseIterable, Codable, Identifiable {
    case gym
    case face
    case money
    case mind
    case social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gym: return "GymMaxx"
        case .face: return "FaceMaxx"
        case .money: return "MoneyMaxx"
        case .mind: return "MindMaxx"
        case .social: return "SocialMaxx"
        }
    }

    var shortTitle: String {
        rawValue.capitalized
    }
}

enum CoachingIntensity: String, CaseIterable, Identifiable, Codable {
    case focused
    case hard
    case beast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focused: return "Focused"
        case .hard: return "Hard"
        case .beast: return "Beast"
        }
    }
}

enum LogCadenceTag: String, CaseIterable, Identifiable, Codable {
    case daily
    case weekly

    var id: String { rawValue }
}

enum DomainLabSection: String, CaseIterable, Identifiable {
    case protocolStack
    case dailyActions
    case metrics
    case resources
    case reflection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protocolStack: return "Protocol"
        case .dailyActions: return "Actions"
        case .metrics: return "Metrics"
        case .resources: return "Resources"
        case .reflection: return "Reflection"
        }
    }
}

enum ProtocolStatusTone: String, Codable, CaseIterable {
    case push
    case maintain
    case standard

    var label: String {
        switch self {
        case .push: return "PUSH"
        case .maintain: return "MAINTAIN"
        case .standard: return "STANDARD"
        }
    }
}

struct HomeTaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var domain: MaxxDomain?
    var title: String
    var subtitle: String
    var estimate: String?
    var order: Int
    var isCompleted: Bool
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        domain: MaxxDomain? = nil,
        title: String,
        subtitle: String,
        estimate: String? = nil,
        order: Int,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.domain = domain
        self.title = title
        self.subtitle = subtitle
        self.estimate = estimate
        self.order = order
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

struct HomeQueueViewState {
    let latestCompleted: HomeTaskItem?
    let activeTasks: [HomeTaskItem]
}

struct ProtocolPlanItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var cadence: String

    init(id: UUID = UUID(), title: String, cadence: String) {
        self.id = id
        self.title = title
        self.cadence = cadence
    }
}

struct ProtocolTaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var subtitle: String
    var trailingMetric: String?
    var isCompleted: Bool
    var completionNote: String?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        trailingMetric: String? = nil,
        isCompleted: Bool = false,
        completionNote: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.trailingMetric = trailingMetric
        self.isCompleted = isCompleted
        self.completionNote = completionNote
    }
}

struct ProtocolTrendRow: Identifiable, Codable, Equatable {
    var id: String { title }
    var title: String
    var dots: [Bool]
}

struct ProtocolCardViewState: Identifiable, Codable, Equatable {
    var id: String { domain.rawValue }
    var domain: MaxxDomain
    var objective: String
    var score: Int
    var weeklyDelta: Int
    var statusTone: ProtocolStatusTone
    var lockQuote: String
    var last7Days: [Bool]
    var streakDays: Int
}

struct ProtocolDetailViewState: Identifiable, Codable, Equatable {
    var id: String { domain.rawValue }
    var domain: MaxxDomain
    var objective: String
    var score: Int
    var scoreHistory: [TrendPoint] = []
    var weeklyDelta: Int
    var statusTone: ProtocolStatusTone
    var streakDays: Int
    var lockDiagnosis: String
    var lockAction: String
    var plan: [ProtocolPlanItem]
    var adjustmentNote: String
    var tasks: [ProtocolTaskItem]
    var last14Days: [ProtocolTrendRow]
}

struct LifeScoreDomainInsight: Identifiable, Codable, Equatable {
    var id: String { domain.rawValue }
    var domain: MaxxDomain
    var headline: String
    var patternRows: [ProtocolTrendRow]
    var helped: [String]
    var hurt: [String]
    var causes: [String]
    var lockAdjustments: [String]
    var moves: [String]
}

struct LockGestureRules {
    static func shouldOpen(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        cooldownActive: Bool
    ) -> Bool {
        guard !cooldownActive else { return false }
        guard translation.width < 0 else { return false }

        let horizontalIntent = abs(translation.width) > abs(translation.height) * 1.15
        guard horizontalIntent else { return false }

        let crossesDistance = translation.width <= -65
        let crossesPredictedDistance = predictedEndTranslation.width <= -110
        return crossesDistance || crossesPredictedDistance
    }

    static func shouldClose(
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> Bool {
        guard translation.width > 0 else { return false }

        let horizontalIntent = abs(translation.width) > abs(translation.height) * 1.1
        guard horizontalIntent else { return false }

        let crossesDistance = translation.width >= 55
        let crossesPredictedDistance = predictedEndTranslation.width >= 95
        return crossesDistance || crossesPredictedDistance
    }
}

struct LogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var domain: MaxxDomain
    var action: String
    var evidence: String
    var confidence: Int
    var createdAt: Date
    var cadenceTag: LogCadenceTag

    init(
        id: UUID = UUID(),
        domain: MaxxDomain,
        action: String,
        evidence: String,
        confidence: Int,
        createdAt: Date = Date(),
        cadenceTag: LogCadenceTag
    ) {
        self.id = id
        self.domain = domain
        self.action = action
        self.evidence = evidence
        self.confidence = confidence
        self.createdAt = createdAt
        self.cadenceTag = cadenceTag
    }
}

struct WeeklyReflectionViewState {
    let lastWeekScore: Int
    let currentWeekState: String
    let upliftPotential: String
    let drivers: [String]
}

struct ProtocolActionItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var domain: MaxxDomain
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, domain: MaxxDomain, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.domain = domain
        self.isCompleted = isCompleted
    }
}

struct DomainMetric: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let value: String

    init(id: UUID = UUID(), title: String, value: String) {
        self.id = id
        self.title = title
        self.value = value
    }
}

struct DomainOSState: Identifiable, Codable, Equatable {
    var id: String { domain.rawValue }
    let domain: MaxxDomain
    var level: String
    var compliance: Int
    var nextMove: String
    var protocolStack: [String]
    var dailyActions: [ProtocolActionItem]
    var metrics: [DomainMetric]
    var resources: [String]
    var reflections: [String]
}

struct UserProfile: Codable {
    let userId: String
    var name: String
    var age: Int?
    var goals: [String]
    var constraints: [String]
    var communicationStyle: String
    var baseline: [String: Double]

    var role: String?
    var heightCm: Double?
    var weightKg: Double?
    var targetWeightKg: Double?
    var sleepTime: Date?
    var wakeTime: Date?
    var dailyHours: Double?
    var monthlyBudget: Double?
    var gymAccess: String?
    var dietPreferences: [String]?
    var primaryGoal: String?
    var secondaryGoals: [String]?
    var currentPhase: String?
    var biggestWeakness: String?
    var ninetyDayGoal: String?
    var biggestObstacle: String?
    var motivationAnchor: String?
    var lockTone: String?
    var notificationStyle: String?
    var requestedMaxxes: [String]?
    var maxxContextNotes: [String: String]?
    var startingLifeScore: Int?
    var onboardingCompleted: Bool?
    var weeklyCheckinDay: String?
    var weeklyCheckinTime: String?
    var timezoneId: String?
    var preferredWeightUnit: String?
    var preferredHeightUnit: String?
    var channelInAppEnabled: Bool?
    var channelTelegramEnabled: Bool?
    var channelDiscordEnabled: Bool?
    var quietHoursEnabled: Bool?
    var quietHoursStart: String?
    var quietHoursEnd: String?
    var googleConnected: Bool?
    var telegramConnected: Bool?
    var discordConnected: Bool?

    init(
        userId: String,
        name: String,
        age: Int?,
        goals: [String],
        constraints: [String],
        communicationStyle: String,
        baseline: [String: Double],
        role: String? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        targetWeightKg: Double? = nil,
        sleepTime: Date? = nil,
        wakeTime: Date? = nil,
        dailyHours: Double? = nil,
        monthlyBudget: Double? = nil,
        gymAccess: String? = nil,
        dietPreferences: [String]? = nil,
        primaryGoal: String? = nil,
        secondaryGoals: [String]? = nil,
        currentPhase: String? = nil,
        biggestWeakness: String? = nil,
        ninetyDayGoal: String? = nil,
        biggestObstacle: String? = nil,
        motivationAnchor: String? = nil,
        lockTone: String? = nil,
        notificationStyle: String? = nil,
        requestedMaxxes: [String]? = nil,
        maxxContextNotes: [String: String]? = nil,
        startingLifeScore: Int? = nil,
        onboardingCompleted: Bool? = nil,
        weeklyCheckinDay: String? = nil,
        weeklyCheckinTime: String? = nil,
        timezoneId: String? = nil,
        preferredWeightUnit: String? = nil,
        preferredHeightUnit: String? = nil,
        channelInAppEnabled: Bool? = nil,
        channelTelegramEnabled: Bool? = nil,
        channelDiscordEnabled: Bool? = nil,
        quietHoursEnabled: Bool? = nil,
        quietHoursStart: String? = nil,
        quietHoursEnd: String? = nil,
        googleConnected: Bool? = nil,
        telegramConnected: Bool? = nil,
        discordConnected: Bool? = nil
    ) {
        self.userId = userId
        self.name = name
        self.age = age
        self.goals = goals
        self.constraints = constraints
        self.communicationStyle = communicationStyle
        self.baseline = baseline
        self.role = role
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.targetWeightKg = targetWeightKg
        self.sleepTime = sleepTime
        self.wakeTime = wakeTime
        self.dailyHours = dailyHours
        self.monthlyBudget = monthlyBudget
        self.gymAccess = gymAccess
        self.dietPreferences = dietPreferences
        self.primaryGoal = primaryGoal
        self.secondaryGoals = secondaryGoals
        self.currentPhase = currentPhase
        self.biggestWeakness = biggestWeakness
        self.ninetyDayGoal = ninetyDayGoal
        self.biggestObstacle = biggestObstacle
        self.motivationAnchor = motivationAnchor
        self.lockTone = lockTone
        self.notificationStyle = notificationStyle
        self.requestedMaxxes = requestedMaxxes
        self.maxxContextNotes = maxxContextNotes
        self.startingLifeScore = startingLifeScore
        self.onboardingCompleted = onboardingCompleted
        self.weeklyCheckinDay = weeklyCheckinDay
        self.weeklyCheckinTime = weeklyCheckinTime
        self.timezoneId = timezoneId
        self.preferredWeightUnit = preferredWeightUnit
        self.preferredHeightUnit = preferredHeightUnit
        self.channelInAppEnabled = channelInAppEnabled
        self.channelTelegramEnabled = channelTelegramEnabled
        self.channelDiscordEnabled = channelDiscordEnabled
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.googleConnected = googleConnected
        self.telegramConnected = telegramConnected
        self.discordConnected = discordConnected
    }
}

struct ChatContext: Codable {
    var wantsProtocol: Bool
    var urgency: ChatUrgency
    var domain: MaxxDomain?
    var domains: [MaxxDomain]?
    var urgencyByDomain: [MaxxDomain: ChatUrgency]?
}

enum ChatUrgency: String, Codable {
    case low
    case normal
    case high
}

struct ChatRequest: Codable {
    var threadId: String
    var message: String
    var context: ChatContext
}

struct ProtocolStep: Codable, Identifiable {
    var id: String { "\(title)-\(frequency)" }
    let title: String
    let action: String
    let frequency: String
    let reason: String
}

struct ProtocolPlan: Codable {
    let objective: String
    let horizonDays: Int
    let steps: [ProtocolStep]
    let checkpoints: [String]
}

struct CoachReply: Codable {
    let message: String
    let modelUsed: String
    let realityCheck: String
    let suggestedProtocol: ProtocolPlan?
    let taskSync: ChatTaskSync?
}

struct ChatTaskSync: Codable {
    let createdDrafts: [BackendCoachingTask]
    let autoActivated: [BackendCoachingTask]
    let trustScore: Double
}

struct ChatStreamMetaPayload: Codable {
    let modelUsed: String
    let realityCheck: String
}

struct ChatStreamTokenPayload: Codable {
    let token: String
}

struct ChatStreamDonePayload: Codable {
    let message: String
}

enum ChatStreamEvent {
    case meta(ChatStreamMetaPayload)
    case token(String)
    case protocolPlan(ProtocolPlan)
    case tasks(ChatTaskSync)
    case done(String)
}

struct CheckinEntry: Codable, Identifiable {
    var id: String { domain.rawValue }
    let domain: MaxxDomain
    let score: Double
    let notes: String
}

struct WeeklyCheckinRequest: Codable {
    let weekStart: String
    let entries: [CheckinEntry]
}

struct DomainProgress: Codable, Identifiable {
    var id: String { domain.rawValue }
    let domain: MaxxDomain
    let previousScore: Double
    let newScore: Double
    let delta: Double
    let note: String
}

struct TrendPoint: Codable, Identifiable, Equatable {
    var id: String { weekStart }
    let weekStart: String
    let score: Double
}

struct LifeScoreBreakdown: Codable {
    let totalScore: Double
    let domainScores: [String: Double]
    let weights: [String: Double]
    let contributions: [String: Double]
    let trend: [TrendPoint]

    func domainScore(for domain: MaxxDomain) -> Double {
        domainScores[domain.rawValue] ?? 0
    }

    func contribution(for domain: MaxxDomain) -> Double {
        contributions[domain.rawValue] ?? 0
    }
}

struct WeeklyCheckinResponse: Codable {
    let progress: [DomainProgress]
    let lifeScore: LifeScoreBreakdown
}

struct ProfileEnvelope: Codable {
    let profile: UserProfile?
}

struct ProfileUpdateRequest: Codable {
    var name: String? = nil
    var goals: [String]? = nil
    var constraints: [String]? = nil
    var communicationStyle: String? = nil
    var weeklyCheckinDay: String? = nil
    var weeklyCheckinTime: String? = nil
    var timezoneId: String? = nil
    var preferredWeightUnit: String? = nil
    var preferredHeightUnit: String? = nil
    var channelInAppEnabled: Bool? = nil
    var channelTelegramEnabled: Bool? = nil
    var channelDiscordEnabled: Bool? = nil
    var quietHoursEnabled: Bool? = nil
    var quietHoursStart: String? = nil
    var quietHoursEnd: String? = nil
    var googleConnected: Bool? = nil
    var telegramConnected: Bool? = nil
    var discordConnected: Bool? = nil
    var maxxContextNotes: [String: String]? = nil

    static var empty: ProfileUpdateRequest {
        ProfileUpdateRequest(
            name: nil,
            goals: nil,
            constraints: nil,
            communicationStyle: nil,
            weeklyCheckinDay: nil,
            weeklyCheckinTime: nil,
            timezoneId: nil,
            preferredWeightUnit: nil,
            preferredHeightUnit: nil,
            channelInAppEnabled: nil,
            channelTelegramEnabled: nil,
            channelDiscordEnabled: nil,
            quietHoursEnabled: nil,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            googleConnected: nil,
            telegramConnected: nil,
            discordConnected: nil,
            maxxContextNotes: nil
        )
    }
}

struct ExportLifeScoreSnapshot: Codable, Identifiable {
    var id: String { weekStart }
    let weekStart: String
    let score: Double
}

struct ExportTaskEvent: Codable, Identifiable {
    let id: String
    let taskId: String
    let action: String
    let actor: String
    let at: String
}

struct ExportThreadState: Codable {
    let lastMessageAt: String
    let messageCount: Int
}

struct UserDataExport: Codable {
    let exportedAt: String
    let userId: String
    let profile: UserProfile?
    let domainScores: [String: Double]
    let weeklyCheckins: [WeeklyCheckinRequest]
    let lifeScoreSnapshots: [ExportLifeScoreSnapshot]
    let coachingTasks: [BackendCoachingTask]
    let taskEvents: [ExportTaskEvent]
    let threadState: [String: ExportThreadState]
}

struct UserDataExportEnvelope: Codable {
    let exportData: UserDataExport
}

struct DeleteAccountDataResponse: Codable {
    let success: Bool
}

enum TaskEventAction: String, Codable {
    case completed
    case reopened
}

enum TaskMutationAction: String, Codable {
    case create
    case complete
    case reopen
    case approveDraft = "approve_draft"
    case rejectDraft = "reject_draft"
    case archive
}

struct BackendCoachingTask: Codable, Identifiable, Equatable {
    let id: String
    let domain: MaxxDomain?
    let title: String
    let subtitle: String
    let estimate: String?
    let priority: Int
    let risk: String
    let state: String
    let source: String
    let createdAt: String
    let dueAt: String?
    let isCompleted: Bool
    let completedAt: String?
}

struct BackendTaskQueue: Codable, Equatable {
    let latestCompleted: BackendCoachingTask?
    let activeTasks: [BackendCoachingTask]
}

struct BackendTaskQueueEnvelope: Codable {
    let queue: BackendTaskQueue
}

struct BackendProtocolTasksEnvelope: Codable {
    let domain: MaxxDomain
    let tasks: [BackendCoachingTask]
}

struct BackendTaskEventResponse: Codable {
    let task: BackendCoachingTask
}

struct TaskMutationRequestPayload: Codable {
    let idempotencyKey: String
    let action: TaskMutationAction
    let taskId: String?
    let domain: MaxxDomain?
    let title: String?
    let subtitle: String?
    let estimate: String?
    let priority: Int?
    let dueAt: String?
    let source: String?
    let actor: String?

    init(
        idempotencyKey: String = UUID().uuidString,
        action: TaskMutationAction,
        taskId: String? = nil,
        domain: MaxxDomain? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        estimate: String? = nil,
        priority: Int? = nil,
        dueAt: String? = nil,
        source: String? = nil,
        actor: String? = nil
    ) {
        self.idempotencyKey = idempotencyKey
        self.action = action
        self.taskId = taskId
        self.domain = domain
        self.title = title
        self.subtitle = subtitle
        self.estimate = estimate
        self.priority = priority
        self.dueAt = dueAt
        self.source = source
        self.actor = actor
    }
}

struct BackendTaskMutationResponse: Codable {
    let task: BackendCoachingTask?
    let snapshot: BackendTaskSnapshot
    let idempotent: Bool
    let status: String

    private enum CodingKeys: String, CodingKey {
        case task
        case snapshot
        case idempotent
        case status
    }

    init(task: BackendCoachingTask?, snapshot: BackendTaskSnapshot, idempotent: Bool, status: String) {
        self.task = task
        self.snapshot = snapshot
        self.idempotent = idempotent
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        task = try container.decodeIfPresent(BackendCoachingTask.self, forKey: .task)
        idempotent = try container.decodeIfPresent(Bool.self, forKey: .idempotent) ?? false
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "ok"
        snapshot = (try? container.decode(BackendTaskSnapshot.self, forKey: .snapshot)) ?? .empty
    }
}

struct BackendTaskSnapshot: Codable, Equatable {
    let homeQueue: BackendTaskQueue
    let byDomain: [MaxxDomain: [BackendCoachingTask]]
    let allActive: [BackendCoachingTask]
    let drafts: [BackendCoachingTask]
    let unassigned: [BackendCoachingTask]

    static var empty: BackendTaskSnapshot {
        var mapped: [MaxxDomain: [BackendCoachingTask]] = [:]
        for domain in MaxxDomain.allCases {
            mapped[domain] = []
        }
        return BackendTaskSnapshot(
            homeQueue: BackendTaskQueue(latestCompleted: nil, activeTasks: []),
            byDomain: mapped,
            allActive: [],
            drafts: [],
            unassigned: []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case homeQueue
        case byDomain
        case allActive
        case drafts
        case unassigned
    }

    init(
        homeQueue: BackendTaskQueue,
        byDomain: [MaxxDomain: [BackendCoachingTask]],
        allActive: [BackendCoachingTask],
        drafts: [BackendCoachingTask],
        unassigned: [BackendCoachingTask]
    ) {
        self.homeQueue = homeQueue
        self.byDomain = byDomain
        self.allActive = allActive
        self.drafts = drafts
        self.unassigned = unassigned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeQueue = try container.decode(BackendTaskQueue.self, forKey: .homeQueue)
        allActive = try container.decodeIfPresent([BackendCoachingTask].self, forKey: .allActive) ?? []
        drafts = try container.decodeIfPresent([BackendCoachingTask].self, forKey: .drafts) ?? []
        unassigned = try container.decodeIfPresent([BackendCoachingTask].self, forKey: .unassigned) ?? []

        let rawByDomain = try container.decodeIfPresent([String: [BackendCoachingTask]].self, forKey: .byDomain) ?? [:]
        var mapped: [MaxxDomain: [BackendCoachingTask]] = [:]
        for domain in MaxxDomain.allCases {
            mapped[domain] = rawByDomain[domain.rawValue] ?? []
        }
        byDomain = mapped
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(homeQueue, forKey: .homeQueue)
        try container.encode(allActive, forKey: .allActive)
        try container.encode(drafts, forKey: .drafts)
        try container.encode(unassigned, forKey: .unassigned)

        var rawByDomain: [String: [BackendCoachingTask]] = [:]
        for domain in MaxxDomain.allCases {
            rawByDomain[domain.rawValue] = byDomain[domain] ?? []
        }
        try container.encode(rawByDomain, forKey: .byDomain)
    }
}

struct BackendTaskSnapshotEnvelope: Codable {
    let snapshot: BackendTaskSnapshot
}

struct BackendMaxxPlanItem: Codable, Equatable {
    let title: String
    let cadence: String
}

struct BackendMaxxTrendRow: Codable, Equatable {
    let title: String
    let dots: [Bool]
}

struct BackendMaxxDetail: Codable, Equatable {
    let domain: MaxxDomain
    let score: Int
    let scoreHistory: [TrendPoint]?
    let weeklyDelta: Int
    let statusTone: ProtocolStatusTone
    let streakDays: Int
    let objective: String
    let lockDiagnosis: String
    let lockAction: String
    let adjustmentNote: String
    let plan: [BackendMaxxPlanItem]
    let tasks: [BackendCoachingTask]
    let last14Days: [BackendMaxxTrendRow]
    let homeQueue: BackendTaskQueue
}

struct BackendMaxxDetailEnvelope: Codable {
    let detail: BackendMaxxDetail
}
