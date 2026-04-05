import SwiftUI

private enum OnboardingUI {
    static let background = LockPalette.background
    static let card = LockPalette.card
    static let cardAlt = LockPalette.cardAlt
    static let primary = LockPalette.textPrimary
    static let secondary = LockPalette.textSecondary
    static let muted = LockPalette.textMuted
    static let ghost = LockPalette.textMuted.opacity(0.72)
    static let red = LockPalette.accent
    static let redSelectedBG = Color(hex: "1A0808")
    static let fieldBorder = LockPalette.stroke
    static let fieldBorderFocused = LockPalette.accent.opacity(0.45)
}

struct OnboardingView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @StateObject private var vm = OnboardingViewModel()
    @FocusState private var focusedField: Field?

    @State private var direction: StepDirection = .forward

    private enum StepDirection {
        case forward
        case backward
    }

    private enum Field: Hashable {
        case name
        case age
        case height
        case weight
        case targetWeight
        case ninetyDayGoal
        case biggestObstacle
        case motivationAnchor
    }

    var body: some View {
        VStack(spacing: 0) {
            if !vm.isFinalAnalysisStep {
                topChrome
            }

            ZStack {
                currentStepContent
                    .id(vm.step)
                    .transition(stepTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, vm.isFinalAnalysisStep ? 20 : 16)
            .padding(.top, vm.isFinalAnalysisStep ? 20 : 14)
            .animation(.easeInOut(duration: 0.24), value: vm.step)

            if !vm.isFinalAnalysisStep {
                continueButton
            }
        }
        .lockScreenBackground()
        .onChange(of: vm.motivationAnchor) { _, _ in
            vm.clampMotivation()
        }
    }

    private var topChrome: some View {
        VStack(spacing: 12) {
            HStack {
                if vm.canGoBack {
                    Button {
                        focusedField = nil
                        direction = .backward
                        vm.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "888888"))
                            .frame(width: 30, height: 30)
                            .background(OnboardingUI.card)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "222222"), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 30, height: 30)
                }

                Spacer()

                Button("Skip") {
                    completeOnboarding()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingUI.ghost)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: "161616"))
                            .frame(height: 2)

                        Capsule()
                            .fill(OnboardingUI.red)
                            .frame(width: proxy.size.width * vm.progress, height: 2)
                    }
                }
                .frame(height: 2)

                Text(vm.progressLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingUI.ghost)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
    }

    private var continueButton: some View {
        Button {
            guard vm.canContinueCurrentStep else { return }
            focusedField = nil
            direction = .forward
            vm.goNext()
        } label: {
            Text("Continue")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(OnboardingUI.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .opacity(vm.canContinueCurrentStep ? 1 : 0.45)
        .disabled(!vm.canContinueCurrentStep)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var currentStepContent: some View {
        Group {
            switch vm.step {
            case 1: stepName
            case 2: stepAge
            case 3: stepRole
            case 4: stepHeight
            case 5: stepWeight
            case 6: stepTargetWeight
            case 7: stepSleep
            case 8: stepDailyHours
            case 9: stepBudget
            case 10: stepGymAccess
            case 11: stepDiet
            case 12: stepPrimaryGoal
            case 13: stepSecondaryGoals
            case 14: stepCurrentPhase
            case 15: stepBiggestWeakness
            case 16: stepNinetyDayGoal
            case 17: stepBiggestObstacle
            case 18: stepMotivationAnchor
            case 19: stepLockTone
            case 20: stepNotificationStyle
            default: stepFinalAnalysis
            }
        }
    }

    private var stepTransition: AnyTransition {
        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }

    private var stepName: some View {
        questionShell(title: "What do we call you?", subtitle: "First name is fine.") {
            singleLineField(
                placeholder: "Your name",
                text: $vm.name,
                field: .name,
                keyboard: .default
            )
            .textInputAutocapitalization(.words)
        }
    }

    private var stepAge: some View {
        questionShell(title: "How old are you?") {
            singleLineField(
                placeholder: "e.g. 21",
                text: $vm.ageText,
                field: .age,
                keyboard: .numberPad
            )
        }
    }

    private var stepRole: some View {
        questionShell(
            title: "What's your current situation?",
            subtitle: "Pick the one that fits best right now."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.roleOptions, id: \.self) { option in
                    optionTile(
                        title: option,
                        isSelected: vm.role == option
                    ) {
                        vm.role = option
                    }
                }
            }
        }
    }

    private var stepHeight: some View {
        questionShell(title: "What's your height?") {
            singleLineField(
                placeholder: "e.g. 178",
                text: $vm.heightCmText,
                field: .height,
                keyboard: .decimalPad,
                suffix: "cm"
            )
        }
    }

    private var stepWeight: some View {
        questionShell(
            title: "Current weight?",
            subtitle: "Be honest. LOCK needs this to calibrate."
        ) {
            HStack(spacing: 8) {
                ForEach(OnboardingViewModel.WeightUnit.allCases) { unit in
                    Button {
                        vm.weightUnit = unit
                    } label: {
                        Text(unit.rawValue.uppercased())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(vm.weightUnit == unit ? .white : Color(hex: "444444"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(vm.weightUnit == unit ? OnboardingUI.red : OnboardingUI.cardAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            singleLineField(
                placeholder: vm.weightUnit == .kg ? "e.g. 72 kg" : "e.g. 160 lbs",
                text: $vm.weightText,
                field: .weight,
                keyboard: .decimalPad
            )
        }
    }

    private var stepTargetWeight: some View {
        questionShell(
            title: "Where do you want to be?",
            subtitle: "Skip if physique isn't a priority right now."
        ) {
            singleLineField(
                placeholder: vm.weightUnit == .kg ? "e.g. 80 kg" : "e.g. 176 lbs",
                text: $vm.targetWeightText,
                field: .targetWeight,
                keyboard: .decimalPad
            )

            Button("Not a priority") {
                focusedField = nil
                direction = .forward
                vm.skipOptionalTargetWeightStep()
            }
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(OnboardingUI.ghost)
            .padding(.top, 8)
        }
    }

    private var stepSleep: some View {
        questionShell(title: "When do you usually sleep and wake up?") {
            HStack(spacing: 10) {
                timeBlock(title: "Sleep", date: $vm.sleepTime)
                timeBlock(title: "Wake", date: $vm.wakeTime)
            }
        }
    }

    private func timeBlock(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(OnboardingUI.secondary)

            DatePicker(
                "",
                selection: date,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .environment(\.colorScheme, .dark)
            .tint(OnboardingUI.red)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(OnboardingUI.fieldBorder, lineWidth: 0.5)
        )
    }

    private var stepDailyHours: some View {
        questionShell(
            title: "How many hours a day can you realistically dedicate to self-improvement?",
            subtitle: "Be honest — not your best-case scenario."
        ) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(vm.dailyHoursDisplay)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(OnboardingUI.primary)

                Text("hrs")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(OnboardingUI.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)

            Slider(value: $vm.dailyHours, in: 0.5...6, step: 0.5)
                .tint(OnboardingUI.red)
        }
    }

    private var stepBudget: some View {
        questionShell(
            title: "Monthly budget for self-improvement?",
            subtitle: "Supplements, gym, skincare, courses, etc."
        ) {
            Text(vm.budgetDisplay)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(OnboardingUI.primary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)

            Slider(
                value: $vm.monthlyBudget,
                in: vm.budgetRange,
                step: vm.budgetStep
            )
            .tint(OnboardingUI.red)
        }
    }

    private var stepGymAccess: some View {
        questionShell(title: "Do you have gym access?") {
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.gymOptions, id: \.self) { option in
                    optionTile(
                        title: option,
                        isSelected: vm.gymAccess == option
                    ) {
                        vm.gymAccess = option
                    }
                }
            }
        }
    }

    private var stepDiet: some View {
        questionShell(title: "Any dietary preferences or restrictions?") {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.dietOptions, id: \.self) { option in
                    optionTile(
                        title: option,
                        isSelected: vm.dietPreferences.contains(option)
                    ) {
                        vm.toggleDiet(option)
                    }
                }
            }
        }
    }

    private var stepPrimaryGoal: some View {
        questionShell(
            title: "What matters most to you right now?",
            subtitle: "This becomes your primary Maxx. Everything else adjusts around it."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.goalOptions, id: \.self) { option in
                    Button {
                        vm.primaryGoal = option
                        vm.secondaryGoals.remove(option)
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Circle()
                                .fill(OnboardingUI.red)
                                .frame(width: 8, height: 8)

                            Text(option)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(vm.primaryGoal == option ? OnboardingUI.primary : OnboardingUI.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                        .padding(14)
                        .background(vm.primaryGoal == option ? OnboardingUI.redSelectedBG : OnboardingUI.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vm.primaryGoal == option ? OnboardingUI.red : OnboardingUI.fieldBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stepSecondaryGoals: some View {
        questionShell(
            title: "What else do you want to improve?",
            subtitle: "Pick up to 2. These become your secondary Maxxes."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.secondaryGoalOptions, id: \.self) { option in
                    optionTile(
                        title: option,
                        isSelected: vm.secondaryGoals.contains(option),
                        minHeight: 64
                    ) {
                        vm.toggleSecondaryGoal(option)
                    }
                }
            }

            Text(vm.secondarySelectionCountLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OnboardingUI.red)
                .padding(.top, 10)
        }
    }

    private var stepCurrentPhase: some View {
        questionShell(
            title: "What phase of life are you in right now?",
            subtitle: "LOCK uses this to set the right intensity."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.phaseOptions, id: \.self) { option in
                    optionTile(
                        title: option,
                        isSelected: vm.currentPhase == option
                    ) {
                        vm.currentPhase = option
                    }
                }
            }
        }
    }

    private var stepBiggestWeakness: some View {
        questionShell(
            title: "What's your honest biggest weakness?",
            subtitle: "The thing that's most held you back."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.weaknessOptions, id: \.self) { option in
                    optionTile(
                        title: option,
                        isSelected: vm.biggestWeakness == option
                    ) {
                        vm.biggestWeakness = option
                    }
                }
            }
        }
    }

    private var stepNinetyDayGoal: some View {
        questionShell(
            title: "What's your main goal for the next 90 days?",
            subtitle: "Be specific. Vague goals get vague results."
        ) {
            multilineField(
                placeholder: "e.g. Get to 75kg, land one freelance client, and fix my sleep schedule.",
                text: $vm.ninetyDayGoal,
                field: .ninetyDayGoal
            )
        }
    }

    private var stepBiggestObstacle: some View {
        questionShell(title: "What's the main thing standing in your way?") {
            multilineField(
                placeholder: "e.g. I start strong and give up after 2 weeks when life gets busy.",
                text: $vm.biggestObstacle,
                field: .biggestObstacle
            )
        }
    }

    private var stepMotivationAnchor: some View {
        questionShell(
            title: "What do you want LOCK to never let you forget?",
            subtitle: "One line. Your reason. LOCK will use this when you need a push."
        ) {
            singleLineField(
                placeholder: "e.g. I refuse to be average.",
                text: $vm.motivationAnchor,
                field: .motivationAnchor,
                keyboard: .default
            )

            HStack {
                Spacer()
                Text(vm.motivationCountLabel)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(OnboardingUI.ghost)
            }
            .padding(.top, 8)
        }
    }

    private var stepLockTone: some View {
        questionShell(
            title: "How hard should LOCK push you?",
            subtitle: "You can change this later."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(OnboardingViewModel.LockTone.allCases) { tone in
                    Button {
                        vm.lockTone = tone
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(tone.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(vm.lockTone == tone ? OnboardingUI.primary : OnboardingUI.secondary)

                            Text(tone.subtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(OnboardingUI.muted)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
                        .padding(12)
                        .background(vm.lockTone == tone ? OnboardingUI.redSelectedBG : OnboardingUI.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vm.lockTone == tone ? OnboardingUI.red : OnboardingUI.fieldBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stepNotificationStyle: some View {
        questionShell(
            title: "How should LOCK reach out?",
            subtitle: "Passive means LOCK only responds. Active means LOCK initiates check-ins."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingViewModel.NotificationStyle.allCases) { style in
                    Button {
                        vm.notificationStyle = style
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(style.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(vm.notificationStyle == style ? OnboardingUI.primary : OnboardingUI.secondary)

                            Text(style.subtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(OnboardingUI.muted)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(vm.notificationStyle == style ? OnboardingUI.redSelectedBG : OnboardingUI.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vm.notificationStyle == style ? OnboardingUI.red : OnboardingUI.fieldBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stepFinalAnalysis: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LOCK")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(OnboardingUI.red)

            Text("Your starting point.")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(OnboardingUI.primary)

            OnboardingLifeScoreRing(score: vm.computedStartingLifeScore)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 10) {
                analysisRow(label: "Primary focus", value: vm.primaryGoal)
                analysisRow(label: "Starting LifeScore", value: "\(vm.computedStartingLifeScore)")
                analysisRow(label: "Biggest bottleneck", value: vm.biggestWeakness)
                analysisRow(label: "90-day mission", value: vm.ninetyDayGoal)
                analysisRow(label: "LOCK tone", value: vm.lockTone?.title ?? "Firm")
            }
            .padding(14)
            .background(OnboardingUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(OnboardingUI.fieldBorder, lineWidth: 0.5)
            )

            Spacer(minLength: 12)

            Button {
                completeOnboarding()
            } label: {
                Text("Enter LockedIn")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(OnboardingUI.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func analysisRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(OnboardingUI.red)
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            Text("\(label):")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingUI.muted)

            Text(trimmedOrFallback(value))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingUI.secondary)
        }
        .lineLimit(1)
    }

    private func trimmedOrFallback(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "-" }
        return cleaned
    }

    private func questionShell(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(OnboardingUI.primary)
                    .padding(.bottom, 8)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(OnboardingUI.muted)
                        .padding(.bottom, 24)
                }

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func optionTile(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        minHeight: CGFloat = 56,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? OnboardingUI.primary : OnboardingUI.secondary)
                    .multilineTextAlignment(.leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(OnboardingUI.muted)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .padding(14)
            .background(isSelected ? OnboardingUI.redSelectedBG : OnboardingUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? OnboardingUI.red : OnboardingUI.fieldBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func singleLineField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType,
        suffix: String? = nil
    ) -> some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: text,
                prompt: Text(placeholder).foregroundStyle(Color(hex: "272727"))
            )
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color(hex: "D0D0D0"))
            .keyboardType(keyboard)
            .textInputAutocapitalization(.sentences)
            .focused($focusedField, equals: field)

            if let suffix {
                Text(suffix)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OnboardingUI.muted)
            }
        }
        .padding(14)
        .background(OnboardingUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == field ? OnboardingUI.fieldBorderFocused : OnboardingUI.fieldBorder, lineWidth: 0.5)
        )
    }

    private func multilineField(
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "272727"))
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
            }

            TextEditor(text: text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "D0D0D0"))
                .frame(minHeight: 106, maxHeight: 140)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .focused($focusedField, equals: field)
        }
        .background(OnboardingUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == field ? OnboardingUI.fieldBorderFocused : OnboardingUI.fieldBorder, lineWidth: 0.5)
        )
    }

    private func completeOnboarding() {
        focusedField = nil
        let profile = vm.buildProfile(userId: "ios-dev-user")
        session.completeOnboarding(with: profile)
    }
}

private struct OnboardingLifeScoreRing: View {
    let score: Int

    private var progress: Double {
        min(max(Double(score) / 100, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "161616"), lineWidth: 12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    OnboardingUI.red,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(OnboardingUI.primary)
        }
        .frame(width: 170, height: 170)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppSessionViewModel())
        .environmentObject(ExperienceStore())
}
