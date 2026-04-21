import SwiftUI

struct WeeklyCheckinView: View {
    @ObservedObject var vm: WeeklyCheckinViewModel
    let onLifeScoreUpdated: (LifeScoreBreakdown) -> Void

    var body: some View {
        Form {
            Section("Weekly Domain Scores") {
                ForEach(MaxxDomain.allCases) { domain in
                    VStack(alignment: .leading) {
                        Text(domain.title)
                            .font(.headline)
                            .foregroundStyle(LockPalette.textSecondary)
                        Slider(value: Binding(
                            get: { vm.domainScores[domain] ?? 50 },
                            set: { vm.domainScores[domain] = $0 }
                        ), in: 0...100, step: 1)
                        .tint(LockPalette.accent)
                        Text("\(Int(vm.domainScores[domain] ?? 50))/100")
                            .font(.caption)
                            .foregroundStyle(LockPalette.textMuted)
                        TextField("What moved this score?", text: Binding(
                            get: { vm.domainNotes[domain] ?? "" },
                            set: { vm.domainNotes[domain] = $0 }
                        ))
                    }
                }
            }
            .listRowBackground(LockPalette.card)

            Section {
                Button(vm.isSubmitting ? "Submitting..." : "Submit Weekly Check-in") {
                    Task {
                        if let updated = await vm.submit() {
                            onLifeScoreUpdated(updated)
                        }
                    }
                }
                .buttonStyle(LockPrimaryButtonStyle())
                .disabled(vm.isSubmitting)
            }
            .listRowBackground(LockPalette.card)

            if !vm.progress.isEmpty {
                Section("Domain Deltas") {
                    ForEach(vm.progress) { row in
                        HStack {
                            Text(row.domain.title)
                            Spacer()
                            Text(String(format: "%+.0f", row.delta))
                                .foregroundStyle(row.delta >= 0 ? .green : LockPalette.accent)
                        }
                    }
                }
                .listRowBackground(LockPalette.card)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(LockPalette.accent)
                    .listRowBackground(LockPalette.card)
            }
        }
        .scrollContentBackground(.hidden)
        .lockScreenBackground()
        .enableInteractiveSwipeBack()
        .navigationTitle("Weekly Check-in")
    }
}
