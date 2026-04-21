import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var store: ExperienceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var lifeScoreVM: LifeScoreViewModel
    @ObservedObject var profileVM: ProfileViewModel
    let onOpenLock: () -> Void
    @State private var animatedScoreValue: Double = 67
    @State private var hasRunHomeCounter = false
    @State private var homeScoreCounterTask: Task<Void, Never>?
    @State private var isNameVisible = false
    @State private var areTasksVisible = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                lockBrief
                progressBlock
                tasksContent
            }
            .padding(16)
        }
        .lockScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            runEntranceAnimations()
        }
        .onDisappear {
            homeScoreCounterTask?.cancel()
        }
        .task {
            await store.syncTaskData()
            await lifeScoreVM.refresh()
            runHomeScoreAnimation(target: displayScore)
            store.refreshLockBrief(currentScore: visibleScore)
        }
        .onChange(of: displayScore) { _, newValue in
            runHomeScoreAnimation(target: newValue)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentWeekday)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LockPalette.textMuted)

                NavigationLink {
                    ProfileView(vm: profileVM)
                } label: {
                    Text(session.displayName)
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(LockPalette.textPrimary)
                        .minimumScaleFactor(0.8)
                        .opacity((isNameVisible || reduceMotion) ? 1 : 0.001)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.45),
                            value: isNameVisible
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.nameButton")
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 12) {
                Button(action: onOpenLock) {
                    Text("Talk to LOCK")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(LockPalette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.lockLauncher")

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.selectedTab = .lifeScore
                    }
                } label: {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(visibleScore)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(LockPalette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .contentTransition(.numericText())
                        Text(weeklyDeltaLabel)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(weeklyDeltaColor)
                        Text("LIFESCORE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LockPalette.textMuted)
                            .tracking(1.2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Open LifeScore tab")
            }
        }
    }

    private var lockBrief: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOCK")
                .font(.headline.weight(.heavy))
                .foregroundStyle(LockPalette.accent)

            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(LockPalette.accent)
                    .frame(width: 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.lockRealityCheck)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LockPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(store.strategicReminder)
                        .font(.subheadline)
                        .foregroundStyle(LockPalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lockGlassCard(cornerRadius: 16, tint: LockPalette.glassBase)
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S PROGRESS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LockPalette.textMuted)
                Spacer()
                Text(store.homeProgressLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LockPalette.textPrimary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LockPalette.glassBase.opacity(0.7))
                    Capsule()
                        .fill(LockPalette.accent)
                        .frame(width: max(14, proxy.size.width * store.homeProgressFraction))
                }
            }
            .frame(height: 8)
        }
    }

    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            tasksHeader
            queueCard
        }
        .offset(y: (areTasksVisible || reduceMotion) ? 0 : 220)
        .opacity((areTasksVisible || reduceMotion) ? 1 : 0.001)
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.62, extraBounce: 0),
            value: areTasksVisible
        )
    }

    private var tasksHeader: some View {
        HStack {
            Text("TASKS")
                .font(.headline.weight(.bold))
                .foregroundStyle(LockPalette.textSecondary)
            Spacer()
            Text("tap to complete")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LockPalette.textMuted)
        }
    }

    private var queueCard: some View {
        let queue = store.homeQueueState

        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if let latestCompleted = queue.latestCompleted {
                    taskRow(task: latestCompleted, style: .completed)
                }

                ForEach(Array(queue.activeTasks.enumerated()), id: \.element.id) { index, task in
                    let style: HomeTaskRowStyle = index < 3 ? .focus : .dim
                    taskRow(task: task, style: style)
                }
            }
            .padding(.vertical, 18)
        }
        .frame(minHeight: 360, maxHeight: 500)
        .mask(queueFadeMask)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [LockPalette.background.opacity(0.85), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, LockPalette.background.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 38)
            .allowsHitTesting(false)
        }
    }

    private func taskRow(task: HomeTaskItem, style: HomeTaskRowStyle) -> some View {
        Button {
            guard !task.isCompleted else { return }
            Task {
                await store.completeHomeTask(task.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(borderColor(for: task, style: style), lineWidth: 2)
                        .frame(width: 30, height: 30)

                    if task.isCompleted {
                        Circle()
                            .fill(LockPalette.accent.opacity(style == .completed ? 0.55 : 0.95))
                            .frame(width: 30, height: 30)
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(textColor(for: style))
                            .strikethrough(task.isCompleted, color: LockPalette.textMuted)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if let estimate = task.estimate {
                            Text(estimate)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LockPalette.textMuted)
                        }
                    }

                    Text(task.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LockPalette.textMuted.opacity(style == .dim ? 0.7 : 1))
                        .lineLimit(2)

                    if let completionNote = task.completedAt {
                        Text("done \(completionNote.formatted(date: .omitted, time: .shortened))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(LockPalette.textMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lockGlassCard(
                cornerRadius: 16,
                tint: style == .focus ? LockPalette.glassBase.opacity(0.84) : LockPalette.glassBase.opacity(0.68)
            )
            .opacity(style == .dim ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(task.isCompleted || store.isTaskUpdating(task.id))
        .opacity(store.isTaskUpdating(task.id) ? 0.58 : 1)
        .accessibilityIdentifier("home.task.\(task.id.uuidString)")
    }

    private var queueFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.9),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var currentWeekday: String {
        Date.now.formatted(.dateTime.weekday(.wide)).uppercased()
    }

    private var displayScore: Int {
        Int(lifeScoreVM.lifeScore?.totalScore ?? 67)
    }

    private var visibleScore: Int {
        Int(animatedScoreValue.rounded())
    }

    private var weeklyDeltaLabel: String {
        let delta = lifeScoreVM.weeklyDelta
        if delta == 0 { return "no change" }
        return delta > 0 ? "+\(delta) this week" : "\(delta) this week"
    }

    private var weeklyDeltaColor: Color {
        let delta = lifeScoreVM.weeklyDelta
        if delta == 0 { return LockPalette.textMuted }
        return delta > 0 ? .green : LockPalette.accent
    }

    private func runHomeScoreAnimation(target: Int) {
        homeScoreCounterTask?.cancel()

        let targetValue = Double(target)

        if reduceMotion {
            animatedScoreValue = targetValue
            hasRunHomeCounter = true
            return
        }

        let startValue: Double
        if hasRunHomeCounter {
            startValue = animatedScoreValue
        } else {
            startValue = max(35, targetValue - 20)
        }
        animatedScoreValue = startValue

        let distance = abs(targetValue - startValue)
        let steps = max(18, min(62, Int(distance * 2.0)))
        let duration = hasRunHomeCounter ? 0.72 : 1.05
        let intervalNs = UInt64((duration / Double(steps)) * 1_000_000_000)

        homeScoreCounterTask = Task {
            for step in 0...steps {
                if Task.isCancelled { return }
                let t = Double(step) / Double(steps)
                let eased = t * t * (3 - 2 * t)

                await MainActor.run {
                    animatedScoreValue = startValue + (targetValue - startValue) * eased
                }

                try? await Task.sleep(nanoseconds: intervalNs)
            }

            await MainActor.run {
                animatedScoreValue = targetValue
                hasRunHomeCounter = true
            }
        }
    }

    private func runEntranceAnimations() {
        if reduceMotion {
            isNameVisible = true
            areTasksVisible = true
            return
        }

        isNameVisible = false
        areTasksVisible = false

        withAnimation(.easeOut(duration: 0.45)) {
            isNameVisible = true
        }

        withAnimation(.smooth(duration: 0.62, extraBounce: 0).delay(0.08)) {
            areTasksVisible = true
        }
    }

    private func textColor(for style: HomeTaskRowStyle) -> Color {
        switch style {
        case .completed:
            return LockPalette.textMuted
        case .focus:
            return LockPalette.textPrimary
        case .dim:
            return LockPalette.textSecondary
        }
    }

    private func borderColor(for task: HomeTaskItem, style: HomeTaskRowStyle) -> Color {
        if task.isCompleted { return LockPalette.accent.opacity(0.9) }
        switch style {
        case .completed:
            return LockPalette.textMuted
        case .focus:
            return LockPalette.textSecondary
        case .dim:
            return LockPalette.textMuted.opacity(0.65)
        }
    }
}

private enum HomeTaskRowStyle {
    case completed
    case focus
    case dim
}
