import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(vm.step), total: 2)
                    .tint(LockPalette.accent)
                    .padding(.horizontal)
                    .padding(.top)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if vm.step == 1 {
                            stepOne
                        } else {
                            stepTwo
                        }
                    }
                    .padding()
                }

                footer
                    .padding()
                    .background(LockPalette.background)
            }
            .navigationTitle("Quick Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LockPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .lockScreenBackground()
        }
    }

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Step 1 of 2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LockPalette.textMuted)

            Text("Define your mission")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(LockPalette.textPrimary)

            textField("Name", text: $vm.name)
            textField("Primary objective", text: $vm.primaryObjective, axis: .vertical)

            VStack(alignment: .leading, spacing: 10) {
                Text("Preferred intensity")
                    .font(.headline)
                    .foregroundStyle(LockPalette.textSecondary)

                Picker("Preferred intensity", selection: $vm.preferredIntensity) {
                    ForEach(CoachingIntensity.allCases) { intensity in
                        Text(intensity.title).tag(intensity)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .lockCard()
    }

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Step 2 of 2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LockPalette.textMuted)

            Text("Set your first non-negotiable")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(LockPalette.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Baseline self-rating")
                    .font(.headline)
                    .foregroundStyle(LockPalette.textSecondary)

                Slider(value: $vm.baselineScore, in: 0...100, step: 1)
                    .tint(LockPalette.accent)
                Text("\(Int(vm.baselineScore))/100")
                    .font(.caption)
                    .foregroundStyle(LockPalette.textMuted)
            }

            textField("One non-negotiable action this week", text: $vm.nonNegotiableCommitment, axis: .vertical)

            VStack(alignment: .leading, spacing: 6) {
                Text("Summary")
                    .font(.headline)
                    .foregroundStyle(LockPalette.textSecondary)
                Text("\(vm.name) will pursue \"\(vm.primaryObjective)\" with \(vm.preferredIntensity.title.lowercased()) intensity.")
                    .foregroundStyle(LockPalette.textMuted)
            }
        }
        .lockCard()
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(LockPalette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if vm.step == 2 {
                    Button("Back") {
                        vm.step = 1
                    }
                    .foregroundStyle(LockPalette.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LockPalette.cardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()

                Button(vm.step == 1 ? "Continue" : (vm.isSubmitting ? "Finishing..." : "Finish Setup")) {
                    Task { await advance() }
                }
                .buttonStyle(LockPrimaryButtonStyle())
                .disabled(vm.step == 1 ? !vm.canContinueStepOne : !vm.canFinishStepTwo || vm.isSubmitting)
            }
        }
    }

    private func textField(_ title: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        TextField(title, text: text, axis: axis)
            .padding(12)
            .background(LockPalette.cardAlt)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(LockPalette.textPrimary)
    }

    private func advance() async {
        if vm.step == 1 {
            vm.step = 2
            return
        }

        vm.isSubmitting = true
        defer { vm.isSubmitting = false }
        await session.completeQuickstart(using: vm)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppSessionViewModel())
        .environmentObject(ExperienceStore())
}
