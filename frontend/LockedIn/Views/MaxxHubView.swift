import SwiftUI

private enum ProtocolUI {
    static let pageBackground = LockPalette.background
    static let cardBackground = LockPalette.card
    static let innerBackground = LockPalette.cardAlt
    static let divider = LockPalette.stroke.opacity(0.55)

    static let textPrimary = LockPalette.textPrimary
    static let textSecondary = LockPalette.textSecondary
    static let textMuted = LockPalette.textMuted
    static let textGhost = LockPalette.textMuted.opacity(0.72)

    static let warning = Color(hex: "C98C3B")

    static let success = Color(hex: "43E97B")
    static let successMuted = Color(hex: "2EAF60")
    static let focus = Color(hex: "4CB8D9")

    static let pushBadgeBG = Color(hex: "20170C")
    static let pushBadgeBorder = Color(hex: "584125")
    static let pushBadgeText = Color(hex: "D7A562")

    static let maintainBadgeBG = Color(hex: "0A1A12")
    static let maintainBadgeBorder = Color(hex: "1F5133")
    static let maintainBadgeText = Color(hex: "71E39D")

    static let standardBadgeBG = Color(hex: "111723")
    static let standardBadgeBorder = Color(hex: "20364D")
    static let standardBadgeText = Color(hex: "7EB3E3")
}

struct ProtocolsView: View {
    @EnvironmentObject private var store: ExperienceStore
    @State private var animateSections = false

    private var cards: [ProtocolCardViewState] {
        store.protocolCards()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Protocols")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(ProtocolUI.textPrimary)

                    Spacer()

                    Text("\(store.activeProtocolsCount) ACTIVE")
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(ProtocolUI.textMuted)
                }
                .padding(.bottom, 16)
                .subtleAppear(animateSections, delay: 0.02)

                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    NavigationLink {
                        ProtocolDetailView(domain: card.domain)
                    } label: {
                        ProtocolCardView(card: card)
                            .subtleAppear(animateSections, delay: 0.06 + (Double(index) * 0.035))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("protocol.card.\(card.domain.rawValue)")
                }

                Button {} label: {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)

                        Image(systemName: "plus")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(ProtocolUI.textMuted)

                        Text("Create new Maxx")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(ProtocolUI.textMuted)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 18)
                    .background(ProtocolUI.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(hex: "1a1a1a"), lineWidth: 0.5)
                    )
                }
                .disabled(true)
                .accessibilityIdentifier("protocol.createPlaceholder")
                .subtleAppear(animateSections, delay: 0.2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .lockScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            animateSections = true
        }
    }
}

private struct ProtocolCardView: View {
    let card: ProtocolCardViewState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowOne

            Rectangle()
                .fill(ProtocolUI.divider)
                .frame(height: 0.5)

            rowTwo
                .padding(.top, 12)

            rowThree
                .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(ProtocolUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.8),
                            accentColor.opacity(0.1),
                            Color(hex: "1E1E1E")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var rowOne: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(card.domain.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(ProtocolUI.textPrimary)

                Text(card.objective)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ProtocolUI.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(card.score)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(ProtocolUI.textPrimary)

                Text(deltaLabel(card.weeklyDelta))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(deltaColor(card.weeklyDelta))
            }
        }
        .padding(.bottom, 12)
    }

    private var rowTwo: some View {
        HStack(alignment: .top, spacing: 10) {
            modeBadge
                .fixedSize()

            Text(card.lockQuote)
                .font(.subheadline.weight(.semibold))
                .italic()
                .foregroundStyle(ProtocolUI.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    private var rowThree: some View {
        HStack(spacing: 4) {
            ForEach(Array(normalizedStreak.enumerated()), id: \.offset) { _, isDone in
                Circle()
                    .fill(isDone ? ProtocolUI.successMuted : Color(hex: "1E1E1E"))
                    .frame(width: 7, height: 7)
            }

            Text("last 7 days")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ProtocolUI.textGhost)
                .padding(.leading, 4)
        }
    }

    private var normalizedStreak: [Bool] {
        if card.last7Days.count == 7 { return card.last7Days }
        if card.last7Days.count > 7 { return Array(card.last7Days.prefix(7)) }
        return card.last7Days + Array(repeating: false, count: 7 - card.last7Days.count)
    }

    private var modeBadge: some View {
        Text(card.statusTone.label)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(modeBadgeColors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(modeBadgeColors.background)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(modeBadgeColors.border, lineWidth: 0.5)
            )
    }

    private var modeBadgeColors: (background: Color, border: Color, text: Color) {
        switch card.statusTone {
        case .push:
            return (ProtocolUI.pushBadgeBG, ProtocolUI.pushBadgeBorder, ProtocolUI.pushBadgeText)
        case .maintain:
            return (ProtocolUI.maintainBadgeBG, ProtocolUI.maintainBadgeBorder, ProtocolUI.maintainBadgeText)
        case .standard:
            return (ProtocolUI.standardBadgeBG, ProtocolUI.standardBadgeBorder, ProtocolUI.standardBadgeText)
        }
    }

    private var accentColor: Color {
        switch card.statusTone {
        case .push:
            return ProtocolUI.warning
        case .maintain:
            return ProtocolUI.successMuted
        case .standard:
            return ProtocolUI.focus
        }
    }

    private func deltaLabel(_ value: Int) -> String {
        if value == 0 { return "no change" }
        return value > 0 ? "+\(value) this week" : "\(value) this week"
    }

    private func deltaColor(_ value: Int) -> Color {
        if value == 0 { return ProtocolUI.textGhost }
        return value > 0 ? ProtocolUI.success : ProtocolUI.warning
    }
}

struct ProtocolDetailView: View {
    @EnvironmentObject private var store: ExperienceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let domain: MaxxDomain
    @State private var actionFeedback: String?
    @State private var isAddTaskExpanded = false
    @State private var newTaskTitle = ""
    @State private var newTaskSubtitle = ""
    @State private var newTaskEstimate = ""
    @State private var isGoalSheetPresented = false
    @State private var goalDraft = ""

    private var detail: ProtocolDetailViewState {
        store.protocolDetail(for: domain)
    }

    private var accentColor: Color {
        switch detail.statusTone {
        case .push:
            return ProtocolUI.warning
        case .maintain:
            return ProtocolUI.successMuted
        case .standard:
            return ProtocolUI.focus
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                topRow
                heroSection
                planCard
                lockInsightCard
                currentPlanSection
                tasksSection
                addTaskSection
                habitGraphSection
                talkToLOCKButton
                actionButtons

                if let actionFeedback {
                    Text(actionFeedback)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ProtocolUI.textGhost)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .lockScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractiveSwipeBack()
        .task {
            await store.syncMaxxDetailIfNeeded(domain: domain)
        }
        .sheet(isPresented: $isGoalSheetPresented) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Update \(detail.domain.title) objective")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ProtocolUI.textPrimary)

                    TextField("New objective", text: $goalDraft, axis: .vertical)
                        .lineLimit(2...5)
                        .textInputAutocapitalization(.sentences)
                        .foregroundStyle(ProtocolUI.textPrimary)
                        .padding(12)
                        .background(ProtocolUI.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ProtocolUI.divider, lineWidth: 0.5)
                        )

                    Text("Keep it specific and measurable.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ProtocolUI.textGhost)

                    Spacer(minLength: 0)
                }
                .padding(16)
                .lockScreenBackground()
                .navigationTitle("Change Goal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isGoalSheetPresented = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                let feedback = await store.changeProtocolGoal(
                                    domain: domain,
                                    objective: goalDraft
                                )
                                actionFeedback = feedback
                                isGoalSheetPresented = false
                            }
                        }
                        .disabled(
                            goalDraft.trimmingCharacters(in: .whitespacesAndNewlines).count < 8
                                || store.isProtocolActionUpdating(domain)
                        )
                    }
                }
            }
        }
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "888888"))
                    .frame(width: 30, height: 30)
                    .background(ProtocolUI.cardBackground)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "222222"), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            Text("PROTOCOLS")
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(ProtocolUI.textMuted)

            Spacer(minLength: 0)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(detail.domain.title)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(ProtocolUI.textPrimary)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(detail.score)")
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .tracking(-1.0)
                        .foregroundStyle(ProtocolUI.textPrimary)

                    Text(deltaLabel(detail.weeklyDelta))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(deltaColor(detail.weeklyDelta))
                        .padding(.top, 3)
                }
            }

            HStack(spacing: 10) {
                ProtocolModeBadge(status: detail.statusTone)

                HStack(spacing: 0) {
                    Text("\(detail.streakDays)")
                        .foregroundStyle(ProtocolUI.success)
                    Text(" day streak")
                        .foregroundStyle(ProtocolUI.textGhost)
                }
                .font(.caption.weight(.semibold))
            }

            Text(detail.objective)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ProtocolUI.textSecondary)
                .lineLimit(3)
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ProtocolUI.cardBackground)
                .frame(height: 0.5)
        }
    }

    private var planCard: some View {
        NavigationLink {
            ProtocolPlanView(detail: detail)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLAN")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(ProtocolUI.textMuted)

                    Text(detail.adjustmentNote)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ProtocolUI.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("View full plan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(ProtocolUI.textMuted)
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .background(ProtocolUI.innerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.4),
                                accentColor.opacity(0.08),
                                Color(hex: "1E1E1E")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var lockInsightCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("LOCK")
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(accentColor)

            Text(detail.lockDiagnosis)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ProtocolUI.textSecondary)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)

            Text(detail.lockAction)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accentColor)
        }
        .padding(14)
        .background(ProtocolUI.innerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.8),
                            accentColor.opacity(0.1),
                            Color(hex: "1E1E1E")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var currentPlanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("CURRENT PLAN")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(detail.plan.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ProtocolUI.textPrimary)

                        Spacer(minLength: 8)

                        Text(item.cadence)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ProtocolUI.textMuted)
                    }
                    .padding(.vertical, 10)

                    if index != detail.plan.count - 1 {
                        Rectangle()
                            .fill(ProtocolUI.divider)
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TODAY'S TASKS")

            ForEach(detail.tasks) { task in
                Button {
                    Task {
                        await store.toggleProtocolTask(domain: domain, taskID: task.id)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        checkbox(for: task)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .top) {
                                Text(task.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(task.isCompleted ? Color(hex: "303030") : Color(hex: "D0D0D0"))
                                    .strikethrough(task.isCompleted, color: Color(hex: "303030"))

                                Spacer(minLength: 6)

                                if let trailingMetric = task.trailingMetric {
                                    Text(trailingMetric)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ProtocolUI.textMuted)
                                }
                            }

                            Text(task.subtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(ProtocolUI.textMuted)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(ProtocolUI.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ProtocolUI.divider, lineWidth: 0.5)
                    )
                    .opacity(task.isCompleted ? 0.38 : 1)
                }
                .buttonStyle(.plain)
                .disabled(store.isTaskUpdating(task.id))
                .opacity(store.isTaskUpdating(task.id) ? 0.62 : 1)
            }
        }
    }

    private var addTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ADD TASK")

            Button {
                withAnimation(taskAnimation) {
                    isAddTaskExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isAddTaskExpanded ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accentColor)

                    Text(isAddTaskExpanded ? "Hide task composer" : "Add task to \(detail.domain.shortTitle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ProtocolUI.textSecondary)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(ProtocolUI.innerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ProtocolUI.divider, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            if isAddTaskExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Task title", text: $newTaskTitle)
                        .textInputAutocapitalization(.sentences)
                        .foregroundStyle(ProtocolUI.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(ProtocolUI.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ProtocolUI.divider, lineWidth: 0.5)
                        )

                    TextField("Task details", text: $newTaskSubtitle, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                        .foregroundStyle(ProtocolUI.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(ProtocolUI.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ProtocolUI.divider, lineWidth: 0.5)
                        )

                    TextField("Estimate (optional)", text: $newTaskEstimate)
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(ProtocolUI.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(ProtocolUI.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ProtocolUI.divider, lineWidth: 0.5)
                        )

                    Button {
                        Task {
                            let feedback = await store.addProtocolTask(
                                domain: domain,
                                title: newTaskTitle,
                                subtitle: newTaskSubtitle,
                                estimate: newTaskEstimate
                            )
                            actionFeedback = feedback
                            if feedback == "Task added." {
                                newTaskTitle = ""
                                newTaskSubtitle = ""
                                newTaskEstimate = ""
                                withAnimation(taskAnimation) {
                                    isAddTaskExpanded = false
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Spacer(minLength: 0)
                            Text(store.isProtocolActionUpdating(domain) ? "Adding..." : "Add Task")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.white)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        store.isProtocolActionUpdating(domain)
                            || newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || newTaskSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(12)
                .background(ProtocolUI.innerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ProtocolUI.divider, lineWidth: 0.5)
                )
            }
        }
        .animation(taskAnimation, value: isAddTaskExpanded)
    }

    private func checkbox(for task: ProtocolTaskItem) -> some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "272727"), lineWidth: 1.5)
                .frame(width: 20, height: 20)

            if task.isCompleted {
                Circle()
                    .fill(ProtocolUI.successMuted)
                    .frame(width: 20, height: 20)

                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 1)
    }

    private var habitGraphSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PATTERN MAP")

            HabitGridView(rows: Array(detail.last14Days.prefix(3)))
        }
    }

    private var talkToLOCKButton: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
                store.presentLock(with: domain)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WANT SOMETHING CHANGED?")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(ProtocolUI.textMuted)

                    Text("Talk to LOCK about \(detail.domain.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ProtocolUI.textSecondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(ProtocolUI.textMuted)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .background(ProtocolUI.innerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.4),
                                accentColor.opacity(0.08),
                                Color(hex: "1E1E1E")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            actionButton(title: "Change goal", tint: Color(hex: "383838")) {
                goalDraft = detail.objective
                isGoalSheetPresented = true
            }

            actionButton(title: "Pause", tint: Color(hex: "383838")) {
                Task {
                    actionFeedback = await store.pauseProtocol(domain: domain)
                }
            }

            actionButton(title: "Archive", tint: Color(hex: "4a2020")) {
                Task {
                    actionFeedback = await store.archiveProtocol(domain: domain)
                }
            }
        }
        .opacity(store.isProtocolActionUpdating(domain) ? 0.65 : 1)
        .disabled(store.isProtocolActionUpdating(domain))
    }

    private func actionButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(ProtocolUI.innerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ProtocolUI.divider, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(ProtocolUI.textMuted)
    }

    private var taskAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.86)
    }

    private func deltaLabel(_ value: Int) -> String {
        if value == 0 { return "no change" }
        return value > 0 ? "+\(value) this week" : "\(value) this week"
    }

    private func deltaColor(_ value: Int) -> Color {
        if value == 0 { return ProtocolUI.textGhost }
        return value > 0 ? ProtocolUI.success : ProtocolUI.warning
    }
}

private struct ProtocolModeBadge: View {
    let status: ProtocolStatusTone

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(colors.background)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(colors.border, lineWidth: 0.5)
            )
            .fixedSize()
    }

    private var colors: (background: Color, border: Color, text: Color) {
        switch status {
        case .push:
            return (ProtocolUI.pushBadgeBG, ProtocolUI.pushBadgeBorder, ProtocolUI.pushBadgeText)
        case .maintain:
            return (ProtocolUI.maintainBadgeBG, ProtocolUI.maintainBadgeBorder, ProtocolUI.maintainBadgeText)
        case .standard:
            return (ProtocolUI.standardBadgeBG, ProtocolUI.standardBadgeBorder, ProtocolUI.standardBadgeText)
        }
    }
}

private struct HabitGridView: View {
    let rows: [ProtocolTrendRow]

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S", "M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Last 14 days")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ProtocolUI.textSecondary)

                Spacer(minLength: 0)

                legendDot(color: ProtocolUI.successMuted, label: "hit")
                legendDot(color: Color(hex: "1B1B1B"), label: "miss")
            }

            ForEach(rows) { row in
                let dots = normalizedDots(for: row)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.title.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(ProtocolUI.textMuted)

                        Spacer(minLength: 6)

                        Text("\(completionRate(dots))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ProtocolUI.textGhost)
                    }

                    HStack(spacing: 4) {
                        ForEach(Array(dots.enumerated()), id: \.offset) { index, isHit in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isHit ? rowAccent(for: row, at: index) : Color(hex: "171717"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color(hex: "1E1E1E"), lineWidth: isHit ? 0 : 0.5)
                                )
                                .frame(width: 12, height: 8)
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, token in
                    Text(token)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ProtocolUI.textGhost)
                        .frame(width: 12)
                        .opacity(index.isMultiple(of: 2) ? 1 : 0.45)
                }
            }
        }
        .padding(14)
        .background(ProtocolUI.innerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ProtocolUI.divider, lineWidth: 0.5)
        )
    }

    private func normalizedDots(for row: ProtocolTrendRow) -> [Bool] {
        if row.dots.count == 14 { return row.dots }
        if row.dots.count > 14 { return Array(row.dots.suffix(14)) }
        return Array(repeating: false, count: 14 - row.dots.count) + row.dots
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ProtocolUI.textGhost)
        }
    }

    private func completionRate(_ dots: [Bool]) -> Int {
        guard !dots.isEmpty else { return 0 }
        let hits = dots.filter { $0 }.count
        return Int((Double(hits) / Double(dots.count) * 100).rounded())
    }

    private func rowAccent(for row: ProtocolTrendRow, at index: Int) -> Color {
        let key = row.title.lowercased()
        if key.contains("high") {
            return ProtocolUI.warning.opacity(index >= 7 ? 1 : 0.75)
        }
        if key.contains("recover") {
            return ProtocolUI.focus.opacity(index >= 7 ? 1 : 0.75)
        }
        return ProtocolUI.successMuted.opacity(index >= 7 ? 1 : 0.75)
    }
}

private struct ProtocolPlanView: View {
    let detail: ProtocolDetailViewState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(detail.domain.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(ProtocolUI.textPrimary)

                ForEach(detail.plan) { item in
                    HStack {
                        Text(item.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ProtocolUI.textPrimary)

                        Spacer(minLength: 8)

                        Text(item.cadence)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ProtocolUI.textMuted)
                    }
                    .padding(.vertical, 8)

                    Rectangle()
                        .fill(Color(hex: "161616"))
                        .frame(height: 0.5)
                }
            }
            .padding(16)
        }
        .lockScreenBackground()
        .enableInteractiveSwipeBack()
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
