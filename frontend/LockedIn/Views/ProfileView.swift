import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @ObservedObject var vm: ProfileViewModel

    @FocusState private var focusedField: Field?
    @State private var showSignOutConfirm = false
    @State private var showDeleteDataConfirm = false
    @State private var showExportSheet = false

    private enum Field: Hashable {
        case name
        case goalInput
        case constraintInput
    }

    private let chipColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                identitySection
                goalsSection
                cadenceSection
                unitsSection
                channelsSection
                quietHoursSection
                connectedAccountsSection
                coachingSection
                dataControlsSection
                saveSection
                signOutSection
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .lockScreenBackground()
        .enableInteractiveSwipeBack()
        .navigationTitle("Settings")
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Sign out of LockedIn?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                session.signOutToAuthGate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be logged out and sent back to auth.")
        }
        .alert("Delete all account data?", isPresented: $showDeleteDataConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    if await vm.deleteAccountData() {
                        session.signOutToAuthGate()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your profile, tasks, check-ins, and score history.")
        }
        .sheet(isPresented: $showExportSheet) {
            NavigationStack {
                ScrollView {
                    Text(vm.exportedDataText ?? "No export generated yet.")
                        .font(.caption.monospaced())
                        .foregroundStyle(LockPalette.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background(LockPalette.background)
                .navigationTitle("Exported Data")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            showExportSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(LockPalette.background)
        }
        .onAppear {
            if let profile = session.profile {
                vm.apply(profile: profile)
            }
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Profile",
                subtitle: "Identity LOCK uses across app, web, and bots."
            )

            TextField("Your name", text: $vm.name)
                .focused($focusedField, equals: .name)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(LockPalette.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            focusedField == .name ? LockPalette.accent.opacity(0.6) : LockPalette.stroke,
                            lineWidth: 1
                        )
                )
        }
        .lockCard()
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Goals & Constraints",
                subtitle: "Clear targets above, friction below. LOCK adapts from this map."
            )

            HStack(spacing: 8) {
                mapSignalChip(
                    title: "Goals",
                    value: "\(vm.goals.count)",
                    tint: LockPalette.accent.opacity(0.88)
                )
                mapSignalChip(
                    title: "Constraints",
                    value: "\(vm.constraints.count)",
                    tint: Color(hex: "2B6EF3")
                )
                mapSignalChip(
                    title: "Pressure",
                    value: pressureLabel,
                    tint: pressureColor
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Strategic goals")
                inputRow(
                    placeholder: "Add a custom goal",
                    text: $vm.goalInput,
                    field: .goalInput
                ) {
                    vm.addGoalFromInput()
                }

                LazyVGrid(columns: chipColumns, spacing: 8) {
                    ForEach(vm.goalSuggestions, id: \.self) { suggestion in
                        selectableChip(
                            title: suggestion,
                            isSelected: vm.goals.contains(suggestion)
                        ) {
                            vm.toggleGoalSuggestion(suggestion)
                        }
                    }
                }

                selectedStack(
                    title: "Goal stack",
                    items: vm.goals,
                    emptyLabel: "No goals selected yet",
                    remove: vm.removeGoal
                )
            }

            Divider()
                .overlay(LockPalette.stroke)

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Constraints and friction")
                inputRow(
                    placeholder: "Add a real blocker",
                    text: $vm.constraintInput,
                    field: .constraintInput
                ) {
                    vm.addConstraintFromInput()
                }

                LazyVGrid(columns: chipColumns, spacing: 8) {
                    ForEach(vm.constraintSuggestions, id: \.self) { suggestion in
                        selectableChip(
                            title: suggestion,
                            isSelected: vm.constraints.contains(suggestion)
                        ) {
                            vm.toggleConstraintSuggestion(suggestion)
                        }
                    }
                }

                selectedStack(
                    title: "Constraint map",
                    items: vm.constraints,
                    emptyLabel: "No constraints added",
                    remove: vm.removeConstraint
                )
            }
        }
        .lockCard()
    }

    private var cadenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Weekly Check-In Cadence",
                subtitle: "When LOCK should run your weekly review cycle."
            )

            HStack(spacing: 10) {
                Picker("Day", selection: $vm.weeklyCheckinDay) {
                    ForEach(ProfileViewModel.WeeklyCheckinDayOption.allCases) { day in
                        Text(day.rawValue).tag(day)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(LockPalette.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                DatePicker(
                    "Time",
                    selection: $vm.weeklyCheckinTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(LockPalette.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Picker("Timezone", selection: $vm.timezoneId) {
                ForEach(vm.timezoneOptions, id: \.self) { zone in
                    Text(zone).tag(zone)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(LockPalette.cardAlt)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .lockCard()
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Units",
                subtitle: "Controls what LOCK uses in plans, metrics, and reminders."
            )

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Weight")
                Picker("Weight unit", selection: $vm.preferredWeightUnit) {
                    ForEach(ProfileViewModel.WeightUnitOption.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Height")
                Picker("Height unit", selection: $vm.preferredHeightUnit) {
                    ForEach(ProfileViewModel.HeightUnitOption.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .lockCard()
    }

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "LOCK Channels",
                subtitle: "Where LOCK can deliver check-ins, reminders, and nudges."
            )

            reminderToggle("In-app", isOn: $vm.channelInAppEnabled)
            reminderToggle("Telegram", isOn: $vm.channelTelegramEnabled)
                .disabled(!vm.telegramConnected)
                .opacity(vm.telegramConnected ? 1 : 0.55)
            reminderToggle("Discord", isOn: $vm.channelDiscordEnabled)
                .disabled(!vm.discordConnected)
                .opacity(vm.discordConnected ? 1 : 0.55)

            if !vm.telegramConnected || !vm.discordConnected {
                Text("Connect Telegram/Discord below to enable those channels.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LockPalette.textMuted)
            }
        }
        .lockCard()
    }

    private var quietHoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Quiet Hours",
                subtitle: "Pause LOCK outreach in your protected window."
            )

            reminderToggle("Enable quiet hours", isOn: $vm.quietHoursEnabled)

            if vm.quietHoursEnabled {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        fieldLabel("Start")
                        DatePicker(
                            "",
                            selection: $vm.quietHoursStart,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(LockPalette.cardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        fieldLabel("End")
                        DatePicker(
                            "",
                            selection: $vm.quietHoursEnd,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(LockPalette.cardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .lockCard()
    }

    private var connectedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Connected Accounts",
                subtitle: "Link accounts to unlock external channel delivery."
            )

            accountRow(
                account: .google,
                connected: vm.googleConnected
            )
            accountRow(
                account: .telegram,
                connected: vm.telegramConnected
            )
            accountRow(
                account: .discord,
                connected: vm.discordConnected
            )
        }
        .lockCard()
    }

    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Coaching Tone",
                subtitle: "How direct LOCK should be in feedback."
            )

            Picker("Tone", selection: $vm.coachingTone) {
                ForEach(vm.toneOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Divider()
                .overlay(LockPalette.stroke)

            sectionHeader(
                title: "Reminder Strategy",
                subtitle: "Fine-grained nudges for accountability loops."
            )

            reminderToggle("Daily execution reminder", isOn: $vm.dailyReminderEnabled)
            reminderToggle("Sunday weekly reflection", isOn: $vm.weeklyReflectionReminderEnabled)
            reminderToggle("DM check-ins", isOn: $vm.dmCheckinsEnabled)
            reminderToggle("Streak nudges", isOn: $vm.streakNudgeEnabled)
        }
        .lockCard()
    }

    private var dataControlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Data Controls",
                subtitle: "Export your data or permanently delete account records."
            )

            Button(vm.isExporting ? "Exporting..." : "Export My Data") {
                Task {
                    if await vm.exportData() != nil {
                        showExportSheet = true
                    }
                }
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: "2B6EF3"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(vm.isExporting)

            Button(vm.isDeletingData ? "Deleting..." : "Delete Account Data") {
                showDeleteDataConfirm = true
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(LockPalette.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(vm.isDeletingData)
        }
        .lockCard()
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(vm.isSaving ? "Saving..." : "Save Settings") {
                Task {
                    if let updated = await vm.save() {
                        session.setProfile(updated)
                    }
                }
            }
            .buttonStyle(LockPrimaryButtonStyle())
            .disabled(vm.isSaving)

            if let error = vm.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LockPalette.accent)
            }
        }
        .lockCard()
    }

    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "Session",
                subtitle: "Sign out from this device and go back to auth."
            )

            Button(role: .destructive) {
                showSignOutConfirm = true
            } label: {
                Text("Sign Out")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LockPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .lockCard()
    }

    private func accountRow(account: ProfileViewModel.ConnectedAccount, connected: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(account.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LockPalette.textPrimary)
                Text(connected ? "Connected" : "Not connected")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(connected ? .green : LockPalette.textMuted)
            }

            Spacer(minLength: 8)

            Button(connected ? "Disconnect" : "Connect") {
                vm.setConnected(account, connected: !connected)
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(connected ? Color(hex: "4A4A4A") : Color(hex: "2B6EF3"))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(LockPalette.cardAlt)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func reminderToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LockPalette.textPrimary)
        }
        .tint(LockPalette.accent)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(LockPalette.textPrimary)

            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(LockPalette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(LockPalette.textMuted)
            .tracking(0.8)
    }

    private func inputRow(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        onAdd: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(LockPalette.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            focusedField == field ? LockPalette.accent.opacity(0.6) : LockPalette.stroke,
                            lineWidth: 1
                        )
                )

            Button {
                onAdd()
                focusedField = nil
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(LockPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func selectableChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : LockPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(isSelected ? LockPalette.accent.opacity(0.9) : LockPalette.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LockPalette.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func selectedStack(
        title: String,
        items: [String],
        emptyLabel: String,
        remove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LockPalette.textMuted)
                .tracking(0.8)

            if items.isEmpty {
                Text(emptyLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LockPalette.textMuted)
            } else {
                LazyVGrid(columns: chipColumns, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 6) {
                            Text(item)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LockPalette.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Button {
                                remove(item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(LockPalette.textMuted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(item)")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(LockPalette.cardAlt.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func mapSignalChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(LockPalette.textMuted)
                .tracking(0.7)
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(tint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(0.5), lineWidth: 1)
        )
    }

    private var pressureLabel: String {
        switch vm.constraints.count {
        case 0:
            return "Low"
        case 1...2:
            return "Medium"
        default:
            return "High"
        }
    }

    private var pressureColor: Color {
        switch vm.constraints.count {
        case 0:
            return Color(hex: "1E9E62")
        case 1...2:
            return Color(hex: "D98E04")
        default:
            return LockPalette.accent
        }
    }
}
