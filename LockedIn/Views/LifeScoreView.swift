import SwiftUI

struct LifeScoreView: View {
    @EnvironmentObject private var store: ExperienceStore
    @ObservedObject var vm: LifeScoreViewModel

    var body: some View {
        Group {
            if let lifeScore = vm.lifeScore {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LifeScore")
                                .font(.headline)
                                .foregroundStyle(LockPalette.textSecondary)
                            Text("\(Int(lifeScore.totalScore))/100")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(LockPalette.textPrimary)
                            Text("Weekly reflection, not punishment. Keep execution tight.")
                                .foregroundStyle(LockPalette.textMuted)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Weekly Reflection") {
                        let reflection = store.weeklyReflection(currentScore: Int(lifeScore.totalScore))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last closed week: \(reflection.lastWeekScore)/100")
                                .foregroundStyle(LockPalette.textPrimary)
                            Text(reflection.currentWeekState)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LockPalette.textPrimary)
                            Text(reflection.upliftPotential)
                                .foregroundStyle(LockPalette.textMuted)
                        }
                    }

                    Section("Domain Contributions") {
                        ForEach(MaxxDomain.allCases) { domain in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(domain.title)
                                        .foregroundStyle(LockPalette.textPrimary)
                                    Text("Weight \(formatted(lifeScore.weights[domain.rawValue] ?? 0))")
                                        .font(.caption)
                                        .foregroundStyle(LockPalette.textMuted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Int(lifeScore.domainScore(for: domain)))/100")
                                        .foregroundStyle(LockPalette.textPrimary)
                                    Text("+\(formatted(lifeScore.contribution(for: domain)))")
                                        .font(.caption)
                                        .foregroundStyle(LockPalette.accent)
                                }
                            }
                        }
                    }

                    Section("Trend") {
                        if lifeScore.trend.isEmpty {
                            Text("Trend appears after your weekly cycle updates.")
                                .foregroundStyle(LockPalette.textMuted)
                        } else {
                            ForEach(lifeScore.trend) { point in
                                HStack {
                                    Text(point.weekStart)
                                        .foregroundStyle(LockPalette.textPrimary)
                                    Spacer()
                                    Text("\(Int(point.score))")
                                        .foregroundStyle(LockPalette.accent)
                                }
                            }
                        }
                    }

                    Section("What Moved Your Score") {
                        ForEach(store.insightDrivers, id: \.self) { driver in
                            Text(driver)
                                .foregroundStyle(LockPalette.textSecondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .listRowBackground(LockPalette.card)
            } else if vm.isLoading {
                ProgressView("Loading LifeScore...")
                    .tint(LockPalette.accent)
            } else {
                ContentUnavailableView("No score yet", systemImage: "chart.line.uptrend.xyaxis", description: Text("Log daily actions to build your first reflection cycle."))
            }
        }
        .lockScreenBackground()
        .navigationTitle("LifeScore")
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await vm.refresh()
        }
        .refreshable {
            await vm.refresh()
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
