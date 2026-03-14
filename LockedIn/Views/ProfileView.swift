import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @ObservedObject var vm: ProfileViewModel
    var onResetSession: (() -> Void)? = nil

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $vm.name)
            }
            .listRowBackground(LockPalette.card)

            Section("Goals") {
                TextField("Primary goals", text: $vm.goalsText, axis: .vertical)
                TextField("Constraints", text: $vm.constraintsText, axis: .vertical)
            }
            .listRowBackground(LockPalette.card)

            Section("Coaching") {
                Picker("Tone", selection: $vm.coachingTone) {
                    Text("Direct").tag("Direct")
                    Text("Balanced").tag("Balanced")
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(LockPalette.card)

            Section("Notifications") {
                Toggle("Daily reminder", isOn: $vm.dailyReminderEnabled)
                    .tint(LockPalette.accent)
                Toggle("Weekly reflection reminder", isOn: $vm.weeklyReflectionReminderEnabled)
                    .tint(LockPalette.accent)
            }
            .listRowBackground(LockPalette.card)

            Section {
                Button(vm.isSaving ? "Saving..." : "Save Profile") {
                    Task {
                        if let updated = await vm.save() {
                            session.setProfile(updated)
                        }
                    }
                }
                .buttonStyle(LockPrimaryButtonStyle())
                .disabled(vm.isSaving)
            }
            .listRowBackground(LockPalette.card)

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(LockPalette.accent)
                    .listRowBackground(LockPalette.card)
            }

            Section("Boundaries") {
                Text("LOCK provides coaching and accountability. It is not therapy, medical, or legal advice.")
                    .font(.footnote)
                    .foregroundStyle(LockPalette.textMuted)
            }
            .listRowBackground(LockPalette.card)

            if let onResetSession {
                Section("Session") {
                    Button("Reset App Session", role: .destructive) {
                        onResetSession()
                    }
                }
                .listRowBackground(LockPalette.card)
            }
        }
        .scrollContentBackground(.hidden)
        .lockScreenBackground()
        .navigationTitle("Profile & Settings")
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if let profile = session.profile {
                vm.apply(profile: profile)
            }
        }
    }
}
