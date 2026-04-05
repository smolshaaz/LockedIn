import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var store: ExperienceStore

    @State private var selectedDomain: MaxxDomain?
    @State private var isDateFilterEnabled = false
    @State private var selectedDate = Date()
    @State private var showNewLogSheet = false
    @State private var editingEntry: LogEntry?
    @State private var revealedEntryID: UUID?

    var body: some View {
        List {
            filtersSection

            ForEach(store.groupedLogs(domain: selectedDomain, date: isDateFilterEnabled ? selectedDate : nil)) { group in
                Section(weekLabel(for: group.weekStart)) {
                    ForEach(group.entries) { entry in
                        slidingLogRow(entry)
                            .listRowInsets(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                            .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .lockScreenBackground()
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
    }

    private var filtersSection: some View {
        Section("Filters") {
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
                .padding(.vertical, 4)
            }

            Toggle("Filter by exact date", isOn: $isDateFilterEnabled)
                .tint(LockPalette.accent)

            if isDateFilterEnabled {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
            }
        }
        .listRowBackground(LockPalette.card)
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

    private func slidingLogRow(_ entry: LogEntry) -> some View {
        let isRevealed = revealedEntryID == entry.id
        let revealOffset: CGFloat = -146

        return ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Button {
                    editingEntry = entry
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
                        revealedEntryID = nil
                    }
                } label: {
                    Text("Edit")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 66, height: 42)
                        .background(Color.blue.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    store.deleteLog(entry)
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
                        revealedEntryID = nil
                    }
                } label: {
                    Text("Delete")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 42)
                        .background(LockPalette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 10)
            .opacity(isRevealed ? 1 : 0)

            logContent(entry)
                .offset(x: isRevealed ? revealOffset : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                if isRevealed {
                    revealedEntryID = nil
                } else {
                    revealedEntryID = entry.id
                }
            }
        }
    }

    private func logContent(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.action)
                    .font(.headline)
                    .foregroundStyle(LockPalette.textPrimary)
                Spacer()
                Text(entry.domain.shortTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LockPalette.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LockPalette.cardAlt)
                    .clipShape(Capsule())
            }

            if !entry.evidence.isEmpty {
                Text(entry.evidence)
                    .font(.subheadline)
                    .foregroundStyle(LockPalette.textSecondary)
            }

            HStack(spacing: 12) {
                Label("C\(entry.confidence)", systemImage: "gauge.medium")
                    .font(.caption)
                Label(entry.cadenceTag.rawValue.capitalized, systemImage: "calendar")
                    .font(.caption)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(LockPalette.textMuted)
            }
            .foregroundStyle(LockPalette.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LockPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LockPalette.stroke, lineWidth: 1)
        )
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
