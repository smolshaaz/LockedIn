import Foundation
import Testing
@testable import LockedIn

struct LockedInTests {

    @Test("Tab order is Home -> LifeScore -> LOCK -> Maxx -> Logs")
    func tabOrderContract() {
        let order = AppTab.allCases
        #expect(order == [.home, .lifeScore, .lock, .maxx, .logs])
    }

    @Test("Quickstart builds profile payload")
    @MainActor
    func quickstartProfilePayload() {
        let vm = OnboardingViewModel()
        vm.name = "Sam"
        vm.primaryObjective = "Increase deep work consistency"
        vm.preferredIntensity = .focused
        vm.baselineScore = 64
        vm.nonNegotiableCommitment = "Daily 90-minute focus sprint"

        let profile = vm.buildProfile(userId: "u1")

        #expect(profile.userId == "u1")
        #expect(profile.name == "Sam")
        #expect(profile.goals.first == "Increase deep work consistency")
        #expect(profile.constraints.contains { $0.contains("Commitment") })
        #expect(profile.baseline["mind"] == 64)
    }

    @Test("Logs support add edit delete and weekly grouping")
    @MainActor
    func logsCrudAndGrouping() {
        let store = ExperienceStore()
        let initialCount = store.logs.count

        let entry = LogEntry(
            domain: .money,
            action: "Published portfolio case study",
            evidence: "Added metrics and outcomes",
            confidence: 4,
            createdAt: Date(),
            cadenceTag: .daily
        )

        store.addLog(entry)
        #expect(store.logs.count == initialCount + 1)

        var edited = entry
        edited.action = "Published revised case study"
        store.updateLog(edited)

        let groups = store.groupedLogs(domain: .money, date: nil)
        #expect(groups.isEmpty == false)
        #expect(groups.flatMap(\.entries).contains { $0.action.contains("revised") })

        store.deleteLog(entry)
        #expect(store.logs.contains(where: { $0.id == entry.id }) == false)
    }

    @Test("Weekly reflection remains confidence-safe")
    @MainActor
    func weeklyReflectionTone() {
        let store = ExperienceStore()
        let reflection = store.weeklyReflection(currentScore: 61)

        #expect(reflection.lastWeekScore == 61)
        #expect(reflection.upliftPotential.localizedCaseInsensitiveContains("upside") ||
                reflection.upliftPotential.localizedCaseInsensitiveContains("leverage"))
    }

    @Test("Domain lab supports all deep sections")
    func deepSectionCoverage() {
        #expect(Set(DomainLabSection.allCases) == Set([
            .protocolStack,
            .dailyActions,
            .metrics,
            .resources,
            .reflection,
        ]))
    }
}
