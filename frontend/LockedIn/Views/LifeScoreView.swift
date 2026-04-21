import SwiftUI
import Charts

private enum LifeScoreUI {
    static let pageBackground = LockPalette.background
    static let cardBackground = LockPalette.card
    static let innerBackground = LockPalette.cardAlt
    static let divider = LockPalette.stroke.opacity(0.55)

    static let textPrimary = LockPalette.textPrimary
    static let textSecondary = LockPalette.textSecondary
    static let textMuted = LockPalette.textMuted
    static let textGhost = LockPalette.textMuted.opacity(0.72)

    static let red = LockPalette.accent
}

struct LifeScoreView: View {
    @EnvironmentObject private var store: ExperienceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var vm: LifeScoreViewModel
    @State private var animatedScoreValue: Double = 0
    @State private var animatedRingProgress: Double = 0
    @State private var barRevealProgress: Double = 0
    @State private var hasRunInitialCounter = false
    @State private var scoreCounterTask: Task<Void, Never>?
    @State private var showHistorySheet = false
    @State private var animateSections = false

    private var cards: [ProtocolCardViewState] {
        store.protocolCards()
    }

    private var displayScore: Int {
        if let score = vm.lifeScore?.totalScore {
            return Int(score)
        }

        guard !cards.isEmpty else { return 67 }
        let average = Double(cards.map(\.score).reduce(0, +)) / Double(cards.count)
        return Int(average)
    }

    private var ringProgress: Double {
        min(max(Double(displayScore) / 100, 0), 1)
    }

    private var visibleScore: Int {
        Int(animatedScoreValue.rounded())
    }

    private var trendData: [LifeScoreTrendDatum] {
        let trend = vm.lifeScore?.trend ?? []
        let sorted = trend.sorted { $0.weekStart < $1.weekStart }
        return sorted.enumerated().map { index, point in
            LifeScoreTrendDatum(
                id: "\(point.weekStart)-\(index)",
                weekStart: point.weekStart,
                score: point.score
            )
        }
    }

    private var weeklyDelta: Int {
        vm.weeklyDelta
    }

    private var weeklyDeltaLabel: String {
        if weeklyDelta == 0 { return "0" }
        return weeklyDelta > 0 ? "+\(weeklyDelta)" : "\(weeklyDelta)"
    }

    private var weeklyDeltaColor: Color {
        if weeklyDelta == 0 { return LifeScoreUI.textMuted }
        return weeklyDelta > 0 ? .green : LifeScoreUI.red
    }

    private var biggestIssueHeadline: String {
        guard let domain = store.biggestIssueCard?.domain else {
            return "Execution signals unlock once you complete a full week."
        }
        return store.lifeScoreInsight(for: domain).headline
    }

    private var biggestIssueCard: ProtocolCardViewState? {
        store.biggestIssueCard
    }

    var body: some View {
        content
        .lockScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractiveSwipeBack()
        .overlay(alignment: .top) {
            if vm.isLoading && vm.lifeScore == nil {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(LifeScoreUI.textSecondary)
                    Text("Calculating your latest score...")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeScoreUI.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(LifeScoreUI.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(LifeScoreUI.divider, lineWidth: 1)
                )
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            NavigationStack {
                historySheet
                    .navigationTitle("LifeScore History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                showHistorySheet = false
                            }
                            .foregroundStyle(LifeScoreUI.textSecondary)
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationBackground(LockPalette.background)
        }
        .task {
            runSynchronizedCounter()
            await vm.refresh()
            runSynchronizedCounter()
        }
        .onAppear {
            animateSections = true
        }
        .onChange(of: displayScore) { _, _ in
            runSynchronizedCounter()
        }
        .onChange(of: trendData.count) { _, _ in
            runSynchronizedCounter()
        }
        .onDisappear {
            scoreCounterTask?.cancel()
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                topHeader
                    .subtleAppear(animateSections, delay: 0.02)
                scoreRing
                    .subtleAppear(animateSections, delay: 0.06)
                biggestIssue
                    .subtleAppear(animateSections, delay: 0.1)
                breakdownSection
                    .subtleAppear(animateSections, delay: 0.14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    private var topHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LifeScore")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(LifeScoreUI.textPrimary)
            Spacer()
            Text(store.lifeScoreWeekLabel)
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)
        }
    }

    private var scoreRing: some View {
        Button {
            showHistorySheet = true
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(LifeScoreUI.innerBackground, lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: animatedRingProgress)
                        .stroke(
                            LifeScoreUI.red,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(visibleScore)")
                            .font(.system(size: 50, weight: .black, design: .rounded))
                            .foregroundStyle(LifeScoreUI.textPrimary)
                            .contentTransition(.numericText())
                        Text(weeklyDeltaLabel)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(weeklyDeltaColor)
                    }
                }
                .frame(width: 190, height: 190)

                Text("TAP FOR HISTORY")
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(LifeScoreUI.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private var biggestIssue: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("BIGGEST ISSUE")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(LifeScoreUI.textMuted)

                if let domain = biggestIssueCard?.domain {
                    Text(domain.shortTitle.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(LifeScoreUI.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LifeScoreUI.innerBackground)
                        .clipShape(Capsule())
                }

                Spacer()

                if let score = biggestIssueCard?.score {
                    Text("\(score)")
                        .font(.title3.weight(.black))
                        .foregroundStyle(LifeScoreUI.textPrimary)
                }
            }

            Text(biggestIssueHeadline)
                .font(.headline.weight(.bold))
                .foregroundStyle(LifeScoreUI.textPrimary)
                .multilineTextAlignment(.leading)

            if let weeklyDelta = biggestIssueCard?.weeklyDelta {
                Text("weekly shift \(deltaMiniLabel(weeklyDelta))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(deltaColor(weeklyDelta))
            }
        }
        .padding(14)
        .background(LifeScoreUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "DFA34B").opacity(0.9),
                            LifeScoreUI.red.opacity(0.75),
                            LifeScoreUI.divider
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var movesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MOVES FOR THIS WEEK")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            ForEach(Array(store.lifeScoreMovesThisWeek.enumerated()), id: \.offset) { index, move in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LifeScoreUI.red)
                        .frame(width: 18, alignment: .leading)

                    Text(move)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LifeScoreUI.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)

                if index != store.lifeScoreMovesThisWeek.count - 1 {
                    Divider().overlay(LifeScoreUI.divider)
                }
            }
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MAXX BREAKDOWN")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                NavigationLink {
                    LifeScoreDomainDetailView(domain: card.domain)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(card.domain.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(LifeScoreUI.textPrimary)
                                Text(shortInsight(for: card.domain))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LifeScoreUI.textMuted)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int((Double(card.score) * barRevealProgress).rounded()))")
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundStyle(LifeScoreUI.textPrimary)
                                    .contentTransition(.numericText())
                                Text(deltaMiniLabel(card.weeklyDelta))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(deltaColor(card.weeklyDelta))
                            }

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.black))
                                .foregroundStyle(LifeScoreUI.textMuted)
                        }

                        GeometryReader { proxy in
                            let fillWidth = max(10, proxy.size.width * (Double(card.score) / 100) * barRevealProgress)
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(LifeScoreUI.innerBackground)
                                Capsule()
                                    .fill(progressColor(for: card))
                                    .frame(width: fillWidth)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(LifeScoreUI.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(LifeScoreUI.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if index != cards.count - 1 {
                    Spacer()
                        .frame(height: 2)
                }
            }
        }
    }

    private var historySheet: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                lifeScoreHistorySection
                movesSection
                weeklySection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 26)
        }
        .background(LockPalette.background)
    }

    private var lifeScoreHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SCORE HISTORY")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            Chart {
                ForEach(trendData) { point in
                    AreaMark(
                        x: .value("Week", point.date),
                        yStart: .value("Floor", 0),
                        yEnd: .value("LifeScore", point.score)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [LifeScoreUI.red.opacity(0.28), LifeScoreUI.red.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Week", point.date),
                        y: .value("LifeScore", point.score)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(LifeScoreUI.red)

                    PointMark(
                        x: .value("Week", point.date),
                        y: .value("LifeScore", point.score)
                    )
                    .symbolSize(32)
                    .foregroundStyle(LifeScoreUI.textPrimary)
                }

                RuleMark(y: .value("Target", 70))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(LifeScoreUI.textMuted.opacity(0.45))
            }
            .chartYScale(domain: 35...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [40, 55, 70, 85, 100]) { _ in
                    AxisGridLine().foregroundStyle(LifeScoreUI.divider)
                    AxisValueLabel().foregroundStyle(LifeScoreUI.textMuted)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(LifeScoreUI.textMuted)
                }
            }
            .frame(height: 220)
            .padding(12)
            .background(LifeScoreUI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LifeScoreUI.divider, lineWidth: 1)
            )

            if let latest = trendData.last, let previous = trendData.dropLast().last {
                let diff = Int((latest.score - previous.score).rounded())
                Text("Latest change: \(diff >= 0 ? "+" : "")\(diff) from last check-in")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(diff >= 0 ? Color.green : LifeScoreUI.red)
            } else {
                Text("Complete weekly check-ins to unlock richer score history.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeScoreUI.textMuted)
            }
        }
    }

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THIS WEEK")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            bulletGroup(title: "IMPROVED", color: .green, items: store.lifeScoreImproved)
            bulletGroup(title: "SLIPPED", color: LifeScoreUI.red, items: store.lifeScoreSlipped)
            bulletGroup(title: "CAUSE", color: LifeScoreUI.textMuted, items: store.lifeScoreCauses)

            Text("NEXT WEEK")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            Text(store.lifeScoreNextWeekFocus)
                .font(.headline.weight(.semibold))
                .italic()
                .foregroundStyle(LifeScoreUI.textSecondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LifeScoreUI.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LifeScoreUI.divider, lineWidth: 1)
                )
        }
    }

    private func bulletGroup(title: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("·")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.top, -1)
                    Text(item)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LifeScoreUI.textSecondary)
                }
            }
        }
    }

    private func runSynchronizedCounter() {
        scoreCounterTask?.cancel()

        let targetScore = Double(displayScore)
        let targetRing = ringProgress

        if reduceMotion {
            animatedScoreValue = targetScore
            animatedRingProgress = targetRing
            barRevealProgress = 1
            hasRunInitialCounter = true
            return
        }

        let startScore: Double
        let startRing: Double
        let startBars: Double
        if hasRunInitialCounter {
            startScore = animatedScoreValue
            startRing = animatedRingProgress
            startBars = barRevealProgress
        } else {
            startScore = max(30, targetScore - 22)
            startRing = 0
            startBars = 0
        }

        let scoreDistance = abs(targetScore - startScore)
        let steps = max(26, min(86, Int(scoreDistance * 2.3)))
        let duration = hasRunInitialCounter ? 0.85 : 1.25
        let intervalNs = UInt64((duration / Double(steps)) * 1_000_000_000)

        animatedScoreValue = startScore
        animatedRingProgress = startRing
        barRevealProgress = startBars

        scoreCounterTask = Task {
            for step in 0...steps {
                if Task.isCancelled { return }
                let t = Double(step) / Double(steps)
                let eased = t * t * (3 - 2 * t) // smoothstep

                await MainActor.run {
                    animatedScoreValue = startScore + (targetScore - startScore) * eased
                    animatedRingProgress = startRing + (targetRing - startRing) * eased
                    barRevealProgress = startBars + (1 - startBars) * eased
                }

                try? await Task.sleep(nanoseconds: intervalNs)
            }

            await MainActor.run {
                animatedScoreValue = targetScore
                animatedRingProgress = targetRing
                barRevealProgress = 1
                hasRunInitialCounter = true
            }
        }
    }

    private func shortInsight(for domain: MaxxDomain) -> String {
        store.lifeScoreInsight(for: domain).headline
    }

    private func deltaMiniLabel(_ value: Int) -> String {
        if value == 0 { return "-" }
        return value > 0 ? "+\(value)" : "\(value)"
    }

    private func deltaColor(_ value: Int) -> Color {
        if value == 0 { return LifeScoreUI.textMuted }
        return value > 0 ? .green : LifeScoreUI.red
    }

    private func progressColor(for card: ProtocolCardViewState) -> Color {
        if card.weeklyDelta > 0 {
            return Color(hex: "43E97B")
        }
        if card.weeklyDelta < 0 {
            return Color(hex: "DFA34B")
        }
        return LifeScoreUI.textMuted
    }
}

private struct LifeScoreTrendDatum: Identifiable {
    let id: String
    let weekStart: String
    let score: Double

    var date: Date {
        Self.weekFormatter.date(from: weekStart) ?? .now
    }

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct LifeScoreDomainDetailView: View {
    @EnvironmentObject private var store: ExperienceStore
    @Environment(\.dismiss) private var dismiss

    let domain: MaxxDomain

    private var insight: LifeScoreDomainInsight {
        store.lifeScoreInsight(for: domain)
    }

    private var detail: ProtocolDetailViewState {
        store.protocolDetail(for: domain)
    }

    private var cardSummary: ProtocolCardViewState? {
        store.protocolCards().first(where: { $0.domain == domain })
    }

    private var comparisonRows: [LifeScoreComparisonRow] {
        detail.last14Days.prefix(3).map { row in
            let dots = row.dots
            let thisWeek = Array(dots.suffix(min(7, dots.count)))
            let lastWeek = Array(dots.prefix(max(0, dots.count - thisWeek.count)).suffix(7))
            let thisWeekDone = thisWeek.filter { $0 }.count
            let lastWeekDone = lastWeek.filter { $0 }.count

            return LifeScoreComparisonRow(
                title: row.title,
                previousWeek: lastWeekDone,
                currentWeek: thisWeekDone
            )
        }
    }

    private var patternRows: [ProtocolTrendRow] {
        detail.last14Days.prefix(3).map { row in
            ProtocolTrendRow(title: row.title, dots: Array(row.dots.suffix(7)))
        }
    }

    private var scoreHistoryData: [LifeScoreTrendDatum] {
        let source: [TrendPoint]
        if detail.scoreHistory.isEmpty {
            source = fallbackScoreHistory()
        } else {
            source = detail.scoreHistory
        }

        let sorted = source.sorted { $0.weekStart < $1.weekStart }
        return sorted.enumerated().map { index, point in
            LifeScoreTrendDatum(
                id: "\(point.weekStart)-\(index)",
                weekStart: point.weekStart,
                score: point.score
            )
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                topRow
                topSummary
                scoreHistorySection
                diagnosisCard
                targetVsActual
                patternMap
                whatMovedBlock
                lockAdjustmentBlock
                movesBlock
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .lockScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractiveSwipeBack()
        .task {
            await store.syncMaxxDetailIfNeeded(domain: domain)
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
                    .background(LifeScoreUI.cardBackground)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "222222"), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            Text("LIFESCORE")
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(LifeScoreUI.textMuted)

            Spacer(minLength: 0)
        }
    }

    private var topSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIFESCORE")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.domain.title)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(LifeScoreUI.textPrimary)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    Text(detail.objective)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LifeScoreUI.textMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(cardSummary?.score ?? detail.score)")
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .foregroundStyle(LifeScoreUI.textPrimary)
                    Text(deltaLabel(cardSummary?.weeklyDelta ?? detail.weeklyDelta))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(deltaColor(cardSummary?.weeklyDelta ?? detail.weeklyDelta))
                }
            }
        }
    }

    private var scoreHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MAXX SCORE TREND")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            Chart {
                ForEach(scoreHistoryData) { point in
                    AreaMark(
                        x: .value("Week", point.date),
                        yStart: .value("Floor", 0),
                        yEnd: .value("Score", point.score)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [LifeScoreUI.red.opacity(0.24), LifeScoreUI.red.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Week", point.date),
                        y: .value("Score", point.score)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .foregroundStyle(LifeScoreUI.red)

                    PointMark(
                        x: .value("Week", point.date),
                        y: .value("Score", point.score)
                    )
                    .symbolSize(30)
                    .foregroundStyle(LifeScoreUI.textPrimary)
                }
            }
            .chartYScale(domain: 35...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [40, 55, 70, 85, 100]) { _ in
                    AxisGridLine().foregroundStyle(LifeScoreUI.divider)
                    AxisValueLabel().foregroundStyle(LifeScoreUI.textMuted)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(LifeScoreUI.textMuted)
                }
            }
            .frame(height: 208)
            .padding(12)
            .background(LifeScoreUI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LifeScoreUI.divider, lineWidth: 1)
            )
        }
    }

    private var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LOCK DIAGNOSIS")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.red)

            Text(insight.headline)
                .font(.headline.weight(.bold))
                .foregroundStyle(LifeScoreUI.textPrimary)

            Text("Move: \(detail.lockAction)")
                .font(.headline.weight(.bold))
                .foregroundStyle(LifeScoreUI.red)
        }
        .padding(16)
        .background(LifeScoreUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [LifeScoreUI.red.opacity(0.6), LifeScoreUI.divider],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var targetVsActual: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TARGET VS ACTUAL")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            ForEach(Array(comparisonRows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LifeScoreUI.textPrimary)

                    Spacer()

                    Text("\(row.targetLabel) -> \(row.actualLabel)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(row.deltaColor)
                }
                .padding(.vertical, 6)

                if index != comparisonRows.count - 1 {
                    Divider().overlay(LifeScoreUI.divider)
                }
            }
        }
    }

    private var patternMap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PATTERN MAP")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(patternRows) { row in
                    HStack(spacing: 8) {
                        Text(row.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LifeScoreUI.textMuted)
                            .frame(width: 86, alignment: .leading)

                        ForEach(Array(row.dots.enumerated()), id: \.offset) { _, isComplete in
                            Circle()
                                .fill(isComplete ? LifeScoreUI.red : LifeScoreUI.innerBackground)
                                .frame(width: 11, height: 11)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("")
                        .frame(width: 86)

                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, token in
                        Text(token)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(LifeScoreUI.textMuted.opacity(0.9))
                            .frame(width: 11)
                    }
                }
            }
            .padding(14)
            .background(LifeScoreUI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LifeScoreUI.divider, lineWidth: 1)
            )
        }
    }

    private var whatMovedBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT MOVED THE SCORE")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            bulletGroup(title: "HELPED", color: .green, items: insight.helped)
            bulletGroup(title: "HURT", color: LifeScoreUI.red, items: insight.hurt)
        }
    }

    private var lockAdjustmentBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCK ADJUSTMENT")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            ForEach(insight.lockAdjustments, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(LifeScoreUI.red)
                        .frame(width: 8, height: 8)
                        .padding(.top, 7)
                    Text(item)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LifeScoreUI.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var movesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MOVES")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(LifeScoreUI.textMuted)

            ForEach(Array(insight.moves.enumerated()), id: \.offset) { index, move in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LifeScoreUI.red)
                        .frame(width: 18, alignment: .leading)
                    Text(move)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LifeScoreUI.textPrimary)
                }
                .padding(.vertical, 5)

                if index != insight.moves.count - 1 {
                    Divider().overlay(LifeScoreUI.divider)
                }
            }
        }
    }

    private func bulletGroup(title: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("·")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.top, -1)
                    Text(item)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LifeScoreUI.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func fallbackScoreHistory() -> [TrendPoint] {
        let calendar = Calendar(identifier: .iso8601)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let current = Double(detail.score)
        let previous = Double(max(0, min(100, detail.score - detail.weeklyDelta)))
        let older = max(0, min(100, previous - Double(detail.weeklyDelta) * 0.6))
        let oldest = max(0, min(100, older - Double(detail.weeklyDelta) * 0.4))
        let values = [oldest, older, previous, current]

        return values.enumerated().compactMap { index, value in
            guard let date = calendar.date(byAdding: .weekOfYear, value: index - 3, to: Date()) else {
                return nil
            }
            return TrendPoint(weekStart: formatter.string(from: date), score: value)
        }
    }

    private func deltaLabel(_ value: Int) -> String {
        if value == 0 { return "no change" }
        return value > 0 ? "+\(value) this week" : "\(value) this week"
    }

    private func deltaColor(_ value: Int) -> Color {
        if value == 0 { return LifeScoreUI.textMuted }
        return value > 0 ? .green : LifeScoreUI.red
    }
}

private struct LifeScoreComparisonRow: Identifiable {
    let title: String
    let previousWeek: Int
    let currentWeek: Int

    var id: String { title }

    var deltaColor: Color {
        if currentWeek == previousWeek { return LifeScoreUI.textMuted }
        return currentWeek > previousWeek ? .green : LifeScoreUI.red
    }

    var targetLabel: String {
        if title.lowercased().contains("deep work") {
            return "21h"
        }
        return "7/7"
    }

    var actualLabel: String {
        if title.lowercased().contains("deep work") {
            return "\(currentWeek * 3)h"
        }
        return "\(currentWeek)/7"
    }
}
