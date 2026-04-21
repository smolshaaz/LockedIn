import Foundation
import CoreGraphics
import Testing
@testable import LockedIn

struct LockedInTests {

    @Test("Tab order is Home -> Protocols -> LifeScore")
    func tabOrderContract() {
        let order = AppTab.allCases
        #expect(order == [.home, .protocols, .lifeScore])
    }

    @Test("Lock gesture uses horizontal intent guard")
    func lockGestureIntentGuard() {
        let accidentalVertical = LockGestureRules.shouldOpen(
            translation: CGSize(width: -80, height: 140),
            predictedEndTranslation: CGSize(width: -120, height: 160),
            cooldownActive: false
        )
        #expect(accidentalVertical == false)

        let deliberateHorizontal = LockGestureRules.shouldOpen(
            translation: CGSize(width: -86, height: 20),
            predictedEndTranslation: CGSize(width: -130, height: 24),
            cooldownActive: false
        )
        #expect(deliberateHorizontal == true)
    }

    @Test("Onboarding builds profile payload")
    @MainActor
    func quickstartProfilePayload() {
        let vm = OnboardingViewModel()
        vm.name = "Sam"
        vm.ageText = "23"
        vm.role = "Student"
        vm.heightCmText = "178"
        vm.weightText = "72"
        vm.gymAccess = "Full gym"
        vm.dietPreferences = ["High protein focus"]
        vm.primaryGoal = "Focus harder"
        vm.secondaryGoals = ["Make more money"]
        vm.currentPhase = "Grinding hard"
        vm.biggestWeakness = "Consistency"
        vm.ninetyDayGoal = "Build stronger execution cadence"
        vm.biggestObstacle = "Late sleep and context switching"
        vm.motivationAnchor = "No more wasted months."
        vm.lockTone = .firm
        vm.notificationStyle = .active

        let profile = vm.buildProfile(userId: "u1")

        #expect(profile.userId == "u1")
        #expect(profile.name == "Sam")
        #expect(profile.primaryGoal == "Focus harder")
        #expect(profile.secondaryGoals?.contains("Make more money") == true)
        #expect(profile.onboardingCompleted == true)
        #expect(profile.startingLifeScore != nil)
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

    @Test("Home queue promotes latest completed task and keeps active order")
    @MainActor
    func homeQueueOrdering() {
        let store = ExperienceStore()
        let initial = store.homeQueueState
        guard let taskToComplete = initial.activeTasks.first else {
            Issue.record("Expected at least one active task.")
            return
        }

        store.completeHomeTask(taskToComplete.id)
        let updated = store.homeQueueState

        #expect(updated.latestCompleted?.id == taskToComplete.id)
        #expect(updated.activeTasks.contains(where: { $0.id == taskToComplete.id }) == false)
    }

    @Test("Protocols view-state mapping includes cards and 14-day rows")
    @MainActor
    func protocolMappingCoverage() {
        let store = ExperienceStore()
        let cards = store.protocolCards()

        #expect(cards.count == MaxxDomain.allCases.count)
        #expect(cards.first?.last7Days.count == 7)

        let detail = store.protocolDetail(for: .mind)
        #expect(detail.last14Days.isEmpty == false)
        #expect(detail.last14Days.allSatisfy { $0.dots.count == 14 })
    }
}
