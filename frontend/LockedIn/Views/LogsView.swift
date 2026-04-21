import SwiftUI

private enum LogsUI {
    static let panel = LockPalette.card
    static let panelAlt = LockPalette.cardAlt
}

struct LogsView: View {
    @EnvironmentObject private var store: ExperienceStore

    @State private var selectedDomain: MaxxDomain?
    @State private var isDateFilterEnabled = false
    @State private var selectedDate = Date()
    @State private var showNewLogSheet = false
    @State private var editingEntry: LogEntry?
    @State private var pendingDeleteEntry: LogEntry?

    private let calendar = Calendar(identifier: .iso8601)

    private var filteredDate: Date? {
        isDateFilterEnabled ? selectedDate : nil
    }

    private var groupedEntries: [LogWeekGroup] {
        store.groupedLogs(domain: selectedDomain, date: filteredDate)
    }

    private var filteredEntries: [LogEntry] {
        store.filteredLogs(domain: selectedDomain, date: filteredDate)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                introPanel
                filtersPanel

                if groupedEntries.isEmpty {
                    emptyStatePanel
                } else {
                    ForEach(groupedEntries) { group in
                        weekSection(group)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 80)
        }
        .lockScreenBackground()
        .enableInteractiveSwipeBack()
        .navigationTitle("Logs")
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewLogSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(LockPalette.accent)
                }
            }
        }
        .sheet(isPresented: $showNewLogSheet) {
            NavigationStack {
                LogEditorSheet(existingEntry: nil) { entry in
                    store.addLog(entry)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(LockPalette.background)
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                LogEditorSheet(existingEntry: entry) { updated in
                    store.updateLog(updated)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(LockPalette.background)
        }
        .alert("Delete this log?", isPresented: Binding(
            get: { pendingDeleteEntry != nil },
            set: { if !$0 { pendingDeleteEntry = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let pendingDeleteEntry {
                    store.deleteLog(pendingDeleteEntry)
                }
                pendingDeleteEntry = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteEntry = nil
            }
        } message: {
            Text(pendingDeleteEntry?.action ?? "")
        }
    }

    private var introPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Execution Notes")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(LockPalette.textPrimary)

            Text("Use logs for quick evidence. If signals feel off, message LOCK directly.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LockPalette.textMuted)

            HStack(spacing: 10) {
                Label("\(filteredEntries.count) entries", systemImage: "book.closed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LockPalette.textSecondary)

                Label("\(store.streakCount)d streak", systemImage: "flame")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LockPalette.accent)
            }
        }
        .padding(14)
        .background(LogsUI.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LockPalette.stroke, lineWidth: 1)
        )
    }

    private var filtersPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", isSelected: selectedDomain == nil) {
                        selectedDomain = nil
                    }

                    ForEach(MaxxDomain.allCases) { domain in
                        filterChip(title: domain.shortTitle, isSelected: selectedDomain == domain) {
                            selectedDomain = domain
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDateFilterEnabled.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isDateFilterEnabled ? "calendar.badge.checkmark" : "calendar")
                        Text(isDateFilterEnabled ? "Date on" : "Date off")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LockPalette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(isDateFilterEnabled ? LockPalette.accentSoft : LogsUI.panelAlt)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(LockPalette.stroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if isDateFilterEnabled {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.colorScheme, .dark)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(LogsUI.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LockPalette.stroke, lineWidth: 1)
        )
    }

    private func weekSection(_ group: LogWeekGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(weekLabel(for: group.weekStart))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LockPalette.textSecondary)

            VStack(spacing: 10) {
                ForEach(group.entries) { entry in
                    logCard(entry)
                }
            }
        }
    }

    private var emptyStatePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No logs for this filter")
                .font(.headline.weight(.bold))
                .foregroundStyle(LockPalette.textPrimary)

            Text("Add one executed action or skip logs and tell LOCK in chat.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LockPalette.textMuted)

            Button("Add log") {
                showNewLogSheet = true
            }
            .buttonStyle(LockPrimaryButtonStyle())
        }
        .padding(16)
        .background(LogsUI.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LockPalette.stroke, lineWidth: 1)
        )
    }

    private func logCard(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                domainTag(entry.domain)

                Spacer()

                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LockPalette.textMuted)
            }

            Text(entry.action)
                .font(.headline.weight(.bold))
                .foregroundStyle(LockPalette.textPrimary)

            if !entry.evidence.isEmpty {
                Text(entry.evidence)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LockPalette.textSecondary)
            }

            HStack(spacing: 8) {
                confidencePill(entry.confidence)

                Text(entry.cadenceTag.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LockPalette.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(LogsUI.panelAlt)
                    .clipShape(Capsule())

                Spacer(minLength: 8)

                iconActionButton(icon: "square.and.pencil", tint: Color(hex: "2F7DF6")) {
                    editingEntry = entry
                }

                iconActionButton(icon: "trash", tint: LockPalette.accent) {
                    pendingDeleteEntry = entry
                }
            }
        }
        .padding(14)
        .background(LogsUI.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LockPalette.stroke, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(domainColor(entry.domain))
                .frame(width: 3)
                .padding(.vertical, 12)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isSelected ? LockPalette.accent : LockPalette.cardAlt)
                .foregroundStyle(LockPalette.textPrimary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(LockPalette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func domainTag(_ domain: MaxxDomain) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(domainColor(domain))
                .frame(width: 8, height: 8)

            Text(domain.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LockPalette.textPrimary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(LogsUI.panelAlt)
        .clipShape(Capsule())
    }

    private func confidencePill(_ confidence: Int) -> some View {
        HStack(spacing: 5) {
            Text("C\(confidence)")
                .font(.caption.weight(.bold))
                .foregroundStyle(LockPalette.textPrimary)

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { idx in
                    Capsule()
                        .fill(idx <= confidence ? LockPalette.accent : LockPalette.stroke)
                        .frame(width: 8, height: 4)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(LogsUI.panelAlt)
        .clipShape(Capsule())
    }

    private func iconActionButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func domainColor(_ domain: MaxxDomain) -> Color {
        switch domain {
        case .gym: return Color(hex: "E74C3C")
        case .face: return Color(hex: "F39C12")
        case .money: return Color(hex: "2ECC71")
        case .mind: return Color(hex: "3498DB")
        case .social: return Color(hex: "9B59B6")
        }
    }

    private func weekLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Week of \(formatter.string(from: date))"
    }
}

struct LogEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingEntry: LogEntry?
    let onSave: (LogEntry) -> Void

    @State private var domain: MaxxDomain = .mind
    @State private var action = ""
    @State private var evidence = ""
    @State private var confidence: Double = 3
    @State private var cadenceTag: LogCadenceTag = .daily

    var body: some View {
        Form {
            Section("Action") {
                TextField("What did you execute?", text: $action)
                TextField("Evidence / context", text: $evidence, axis: .vertical)
            }
            .listRowBackground(LockPalette.card)

            Section("Quality") {
                Picker("Domain", selection: $domain) {
                    ForEach(MaxxDomain.allCases) { domain in
                        Text(domain.title).tag(domain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Confidence: \(Int(confidence))/5")
                    Slider(value: $confidence, in: 1...5, step: 1)
                        .tint(LockPalette.accent)
                }

                Picker("Cadence", selection: $cadenceTag) {
                    ForEach(LogCadenceTag.allCases) { cadence in
                        Text(cadence.rawValue.capitalized).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(LockPalette.card)
        }
        .scrollContentBackground(.hidden)
        .background(LockPalette.background)
        .navigationTitle(existingEntry == nil ? "Quick Log" : "Edit Log")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(LockPalette.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .foregroundStyle(LockPalette.accent)
                .disabled(action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            if let existingEntry {
                domain = existingEntry.domain
                action = existingEntry.action
                evidence = existingEntry.evidence
                confidence = Double(existingEntry.confidence)
                cadenceTag = existingEntry.cadenceTag
            }
        }
    }

    private func save() {
        let saved = LogEntry(
            id: existingEntry?.id ?? UUID(),
            domain: domain,
            action: action.trimmingCharacters(in: .whitespacesAndNewlines),
            evidence: evidence.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: Int(confidence),
            createdAt: existingEntry?.createdAt ?? Date(),
            cadenceTag: cadenceTag
        )

        onSave(saved)
        dismiss()
    }
}
