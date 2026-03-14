import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var store: ExperienceStore

    @ObservedObject var lifeScoreVM: LifeScoreViewModel
    @ObservedObject var profileVM: ProfileViewModel

    @State private var showQuickLog = false
    @State private var executionFeedback: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                briefCard
                todayPlanCard
                alertsCard
                reflectionCard
            }
            .padding(16)
        }
        .lockScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Home")
                    .font(.headline)
                    .foregroundStyle(LockPalette.textPrimary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView(vm: profileVM, onResetSession: {
                        session.resetSession()
                    })
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(LockPalette.accent)
                }
            }
        }
        .sheet(isPresented: $showQuickLog) {
            NavigationStack {
                LogEditorSheet(existingEntry: nil) { newEntry in
                    store.addLog(newEntry)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(LockPalette.background)
        }
        .task {
            if lifeScoreVM.lifeScore == nil {
                await lifeScoreVM.refresh()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back, \(session.displayName)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(LockPalette.textPrimary)
                Text("Session command surface")
                    .font(.subheadline)
                    .foregroundStyle(LockPalette.textSecondary)
            }

            Spacer()

            VStack(spacing: 3) {
                Text("\(store.streakCount)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LockPalette.textPrimary)
                Text("streak")
                    .font(.caption)
                    .foregroundStyle(LockPalette.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(LockPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LockPalette.accent.opacity(0.6), lineWidth: 1)
            )
        }
    }

    private var briefCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("LOCK Brief")
                    .font(.headline)
                    .foregroundStyle(LockPalette.textSecondary)
                Text(store.lockRealityCheck)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LockPalette.textPrimary)
                Text(store.strategicReminder)
                    .foregroundStyle(LockPalette.textMuted)
            }
        }
    }

    private var todayPlanCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Today Plan")
                    .font(.headline)
                    .foregroundStyle(LockPalette.textSecondary)

                ForEach(store.todayProtocolActions.prefix(3)) { action in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(action.isCompleted ? .green : LockPalette.textMuted)
                        Text(action.title)
                            .foregroundStyle(LockPalette.textPrimary)
                    }
                }

                Button("Execute Today's Top Protocol") {
                    executionFeedback = store.executeTopProtocolAction()
                }
                .buttonStyle(LockPrimaryButtonStyle())

                if let executionFeedback {
                    Text(executionFeedback)
                        .font(.caption)
                        .foregroundStyle(LockPalette.textMuted)
                }

                Button("Quick Log") {
                    showQuickLog = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LockPalette.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(LockPalette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var alertsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Critical Alerts")
                    .font(.headline)
                    .foregroundStyle(LockPalette.textSecondary)

                if store.criticalAlerts.isEmpty {
                    Text("No active critical alerts. Keep stacking proof.")
                        .foregroundStyle(LockPalette.textMuted)
                } else {
                    ForEach(store.criticalAlerts, id: \.self) { alert in
                        Label(alert, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(LockPalette.accent)
                    }
                }
            }
        }
    }

    private var reflectionCard: some View {
        let reflection = store.weeklyReflection(currentScore: lifeScoreVM.lifeScore.map { Int($0.totalScore) })

        return card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly Reflection")
                    .font(.headline)
                    .foregroundStyle(LockPalette.textSecondary)
                Text("Last closed week: \(reflection.lastWeekScore)/100")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LockPalette.textPrimary)
                Text(reflection.currentWeekState)
                    .foregroundStyle(LockPalette.textPrimary)
                Text(reflection.upliftPotential)
                    .font(.subheadline)
                    .foregroundStyle(LockPalette.textMuted)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().lockCard()
    }
}
