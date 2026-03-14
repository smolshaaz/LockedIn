import Foundation

enum AppLaunchPhase: String {
    case splash
    case welcome
    case onboarding
    case ready
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case lifeScore
    case lock
    case maxx
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .lifeScore: return "LifeScore"
        case .lock: return "LOCK"
        case .maxx: return "Maxx"
        case .logs: return "Logs"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .lifeScore: return "chart.line.uptrend.xyaxis"
        case .lock: return "message.fill"
        case .maxx: return "target"
        case .logs: return "list.bullet.rectangle.portrait"
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
}

struct ChatContext: Codable {
    var wantsProtocol: Bool
    var urgency: String
    var domain: MaxxDomain?
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

struct TrendPoint: Codable, Identifiable {
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
