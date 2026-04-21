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

    @State private var gateStage: PreOnboardingGate = .intro
    @State private var direction: StepDirection = .forward
    @State private var hasGeneratedInitialMaxx = false
    @State private var generationProgress = 0.0
    @State private var generationPhaseIndex = 0
    @State private var generationPulse = false
    @State private var generationOrbit = false
    @State private var generationBeam = false
    @State private var isSyncingOnboarding = false
    @State private var generationErrorMessage: String?
    @State private var syncedProfile: UserProfile?
    @State private var generationTask: Task<Void, Never>?

    private enum StepDirection {
        case forward
        case backward
    }

    private enum PreOnboardingGate {
        case intro
        case auth
        case flow
    }

    private enum Field: Hashable {
        case name
        case age
        case height
        case heightFeet
        case heightInches
        case weight
        case targetWeight
        case ninetyDayGoal
        case obstacleOther
        case obstacleContext
        case motivationAnchor
        case dietOther
        case primaryGoalOther
        case secondaryGoalOther
        case weaknessOther
    }

    private let generationPhases = [
        "Syncing your onboarding profile to LOCK",
        "Scoring your baseline across selected Maxxes",
        "Building your first execution protocol",
        "Finalizing your first Maxx blueprint"
    ]

    var body: some View {
        Group {
            switch gateStage {
            case .intro:
                onboardingIntro
            case .auth:
                authPlaceholder
            case .flow:
                onboardingFlow
            }
        }
        .lockScreenBackground()
        .onAppear {
            if session.consumeOnboardingAuthGateRedirect() {
                gateStage = .auth
            }
        }
        .onChange(of: vm.motivationAnchor) { _, _ in
            vm.clampMotivation()
        }
        .onChange(of: vm.step) { _, _ in
            handleStepTransition()
        }
        .onDisappear {
            generationTask?.cancel()
        }
    }

    private var onboardingIntro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)

            Text("LOCKEDIN")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(OnboardingUI.red)

            Text("Stop reading.\nStart doing.")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(OnboardingUI.primary)

            Text("LOCK will map your baseline, generate your first Maxx, and push execution from day one.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OnboardingUI.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Button {
                withAnimation(.easeInOut(duration: 0.24)) {
                    gateStage = .auth
                }
            } label: {
                Text("Continue")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(OnboardingUI.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var authPlaceholder: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)

            Text("LOCK")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(OnboardingUI.red)

            Text("auth comes here")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(OnboardingUI.primary)

            Text("Temporary auth placeholder for testing. Real auth flow will be connected here.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OnboardingUI.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Button {
                focusedField = nil
                withAnimation(.easeInOut(duration: 0.24)) {
                    gateStage = .flow
                }
            } label: {
                Text("Skip auth")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(OnboardingUI.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip auth and continue onboarding")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var onboardingFlow: some View {
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
            case 4: stepBodyMetrics
            case 5: stepTargetWeight
            case 6: stepSleep
            case 7: stepDailyHours
            case 8: stepBudget
            case 9: stepGymAccess
            case 10: stepDiet
            case 11: stepPrimaryGoal
            case 12: stepSecondaryGoals
            case 13: stepCurrentPhase
            case 14: stepBiggestWeakness
            case 15: stepNinetyDayGoal
            case 16: stepBiggestObstacle
            case 17: stepMotivationAnchor
            case 18: stepLockTone
            case 19: stepNotificationStyle
            case 20: stepRequestedMaxxes
            case 21: stepMaxxContext
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

    private var stepBodyMetrics: some View {
        questionShell(
            title: "Set your body baseline",
            subtitle: "Height + current weight so LOCK can calibrate your first Maxx."
        ) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("HEIGHT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(OnboardingUI.ghost)
                            .tracking(0.8)
                        Spacer()
                        unitSwitch(
                            options: OnboardingViewModel.HeightUnit.allCases,
                            selected: vm.heightUnit
                        ) { vm.heightUnit = $0 }
                    }

                    if vm.heightUnit == .cm {
                        singleLineField(
                            placeholder: "e.g. 178",
                            text: $vm.heightCmText,
                            field: .height,
                            keyboard: .decimalPad,
                            suffix: "cm"
                        )
                    } else {
                        HStack(spacing: 10) {
                            singleLineField(
                                placeholder: "5",
                                text: $vm.heightFeetText,
                                field: .heightFeet,
                                keyboard: .decimalPad,
                                suffix: "ft"
                            )

                            singleLineField(
                                placeholder: "10",
                                text: $vm.heightInchesText,
                                field: .heightInches,
                                keyboard: .decimalPad,
                                suffix: "in"
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CURRENT WEIGHT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(OnboardingUI.ghost)
                            .tracking(0.8)
                        Spacer()
                        unitSwitch(
                            options: OnboardingViewModel.WeightUnit.allCases,
                            selected: vm.weightUnit
                        ) { vm.weightUnit = $0 }
                    }

                    singleLineField(
                        placeholder: vm.weightUnit == .kg ? "e.g. 72" : "e.g. 160",
                        text: $vm.weightText,
                        field: .weight,
                        keyboard: .decimalPad,
                        suffix: vm.weightUnit.rawValue.uppercased()
                    )
                }
            }
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
        questionShell(
            title: "Any dietary preferences or restrictions?",
            subtitle: "Pick all that apply. Add custom specifics if needed."
        ) {
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

            if vm.dietPreferences.contains("Other") {
                singleLineField(
                    placeholder: "Tell LOCK your exact preference",
                    text: $vm.customDietPreference,
                    field: .dietOther,
                    keyboard: .default
                )
                .textInputAutocapitalization(.sentences)
                .padding(.top, 12)
            }

            HStack {
                Text("\(vm.dietPreferences.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingUI.red)
                Spacer()
                Text("Use No restrictions if unrestricted")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingUI.ghost)
            }
            .padding(.top, 10)
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
                    optionTile(
                        title: option,
                        subtitle: goalSubtitle(for: option),
                        isSelected: vm.primaryGoal == option,
                        minHeight: 84
                    ) {
                        vm.primaryGoal = option
                        vm.secondaryGoals.remove(option)
                        vm.selectionFeedback = nil
                    }
                }
            }

            if vm.primaryGoal == "Other" {
                singleLineField(
                    placeholder: "Tell LOCK what your real main focus is",
                    text: $vm.primaryGoalOtherText,
                    field: .primaryGoalOther,
                    keyboard: .default
                )
                .textInputAutocapitalization(.sentences)
                .padding(.top, 12)
            }
        }
    }

    private var stepSecondaryGoals: some View {
        questionShell(
            title: "What else do you want to improve?",
            subtitle: "Pick up to 2. These become your secondary Maxxes."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MAIN FOCUS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(OnboardingUI.ghost)
                    .tracking(0.8)
                Text(vm.resolvedPrimaryGoal.isEmpty ? "-" : vm.resolvedPrimaryGoal)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(OnboardingUI.primary)
            }
            .padding(.bottom, 12)

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

            if vm.secondaryGoals.contains("Other") {
                singleLineField(
                    placeholder: "Secondary other focus",
                    text: $vm.secondaryGoalOtherText,
                    field: .secondaryGoalOther,
                    keyboard: .default
                )
                .textInputAutocapitalization(.sentences)
                .padding(.top, 12)
            }

            Text(vm.secondarySelectionCountLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OnboardingUI.red)
                .padding(.top, 10)

            if let feedback = vm.selectionFeedback, !feedback.isEmpty {
                Text(feedback)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OnboardingUI.red)
                    .padding(.top, 4)
            }
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
            title: "What has been holding you back?",
            subtitle: "Select all that apply."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.weaknessOptions, id: \.self) { option in
                    optionTile(
                        title: option,
                        subtitle: weaknessSubtitle(for: option),
                        isSelected: vm.biggestWeaknesses.contains(option),
                        minHeight: 78
                    ) {
                        vm.toggleWeakness(option)
                    }
                }
            }

            if vm.biggestWeaknesses.contains("Other") {
                singleLineField(
                    placeholder: "Add your specific blocker",
                    text: $vm.biggestWeaknessOtherText,
                    field: .weaknessOther,
                    keyboard: .default
                )
                .textInputAutocapitalization(.sentences)
                .padding(.top, 12)
            }

            Text("\(vm.biggestWeaknesses.count) selected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OnboardingUI.red)
                .padding(.top, 10)

            if !vm.biggestWeaknessSummary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current weakness map")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(OnboardingUI.ghost)
                        .tracking(0.6)
                    Text(vm.biggestWeaknessSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OnboardingUI.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OnboardingUI.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(OnboardingUI.fieldBorder, lineWidth: 0.5)
                )
                .padding(.top, 8)
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
        questionShell(
            title: "What is blocking execution right now?",
            subtitle: "Select all core obstacles. Add context so LOCK can design around constraints."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.obstacleOptions, id: \.self) { option in
                    optionTile(
                        title: option,
                        subtitle: obstacleSubtitle(for: option),
                        isSelected: vm.biggestObstacles.contains(option),
                        minHeight: 78
                    ) {
                        vm.toggleObstacle(option)
                    }
                }
            }

            if vm.biggestObstacles.contains("Other") {
                singleLineField(
                    placeholder: "Add your specific obstacle",
                    text: $vm.biggestObstacleOtherText,
                    field: .obstacleOther,
                    keyboard: .default
                )
                .textInputAutocapitalization(.sentences)
                .padding(.top, 12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Context for LOCK (optional)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(OnboardingUI.ghost)
                    .tracking(0.8)

                multilineField(
                    placeholder: "e.g. My routine breaks whenever college workload spikes mid-week.",
                    text: $vm.biggestObstacleContext,
                    field: .obstacleContext
                )
            }
            .padding(.top, 12)

            HStack {
                Text("\(vm.biggestObstacles.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingUI.red)
                Spacer()
                if !vm.biggestObstacleSummary.isEmpty {
                    Text(vm.biggestObstacleSummary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OnboardingUI.ghost)
                        .lineLimit(1)
                }
            }
            .padding(.top, 8)
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

    private var stepRequestedMaxxes: some View {
        questionShell(
            title: "Which Maxxes should LOCK build first?",
            subtitle: "Pick at least one. These will be generated immediately after onboarding."
        ) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(MaxxDomain.allCases) { domain in
                    optionTile(
                        title: domain.title,
                        isSelected: vm.requestedMaxxes.contains(domain),
                        minHeight: 74
                    ) {
                        vm.toggleRequestedMaxx(domain)
                    }
                }
            }

            HStack {
                Text(vm.maxxSelectionCountLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingUI.red)
                Spacer()
                Text("Select what matters now. LOCK can add more later.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingUI.ghost)
            }
            .padding(.top, 10)
        }
    }

    private var stepMaxxContext: some View {
        questionShell(
            title: "Give LOCK high-signal context",
            subtitle: "These notes are fed into protocol generation so LOCK doesn’t ask repetitive questions later."
        ) {
            VStack(spacing: 12) {
                ForEach(vm.sortedRequestedMaxxes) { domain in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(domain.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(OnboardingUI.red)
                            .tracking(0.6)

                        Text(vm.maxxContextPrompt(for: domain))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(OnboardingUI.muted)

                        maxxContextField(for: domain)
                    }
                    .padding(12)
                    .background(OnboardingUI.cardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(OnboardingUI.fieldBorder, lineWidth: 0.5)
                    )
                }
            }
        }
    }

    private var stepFinalAnalysis: some View {
        Group {
            if hasGeneratedInitialMaxx {
                stepFinalSummary
            } else {
                stepGeneratingMaxx
            }
        }
    }

    private var stepGeneratingMaxx: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LOCK")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(OnboardingUI.red)

            Text("Generating your first Maxx")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(OnboardingUI.primary)

            Text(generationPhases[generationPhaseIndex])
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingUI.muted)

            ZStack {
                Circle()
                    .stroke(Color(hex: "161616"), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: max(generationProgress, 0.04))
                    .stroke(
                        OnboardingUI.red,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0.15, to: 0.48)
                    .stroke(
                        OnboardingUI.red.opacity(0.75),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(generationOrbit ? 360 : 0))

                Image(systemName: "bolt.fill")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(OnboardingUI.primary)
                    .scaleEffect(generationPulse ? 1.06 : 0.93)

                RoundedRectangle(cornerRadius: 2)
                    .fill(OnboardingUI.red.opacity(0.85))
                    .frame(width: 120, height: 2)
                    .blur(radius: 0.5)
                    .offset(y: generationBeam ? 58 : -58)
                    .opacity(0.55)
            }
            .frame(width: 170, height: 170)
            .onAppear {
                if !generationPulse {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        generationPulse = true
                    }
                }

                if !generationOrbit {
                    withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                        generationOrbit = true
                    }
                }

                if !generationBeam {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        generationBeam = true
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            ProgressView(value: generationProgress, total: 1)
                .tint(OnboardingUI.red)

            Text("\(Int(generationProgress * 100))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(OnboardingUI.ghost)
                .frame(maxWidth: .infinity, alignment: .center)

            if isSyncingOnboarding {
                Label("Syncing onboarding to backend", systemImage: "network")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingUI.secondary)
            }

            if let generationErrorMessage, !generationErrorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(generationErrorMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OnboardingUI.red)

                    Button {
                        startMaxxGenerationAnimation()
                    } label: {
                        Text("Retry Generation")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(OnboardingUI.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stepFinalSummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LOCK")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(OnboardingUI.red)

            Text("Your first Maxx is ready.")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(OnboardingUI.primary)

            OnboardingLifeScoreRing(score: vm.computedStartingLifeScore)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 10) {
                analysisRow(label: "Primary focus", value: vm.resolvedPrimaryGoal)
                analysisRow(label: "Requested Maxxes", value: vm.resolvedRequestedMaxxes.joined(separator: ", "))
                analysisRow(label: "Starting LifeScore", value: "\(vm.computedStartingLifeScore)")
                analysisRow(label: "Biggest bottleneck", value: vm.biggestWeaknessSummary)
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
                enterLockedIn()
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

    private func goalSubtitle(for goal: String) -> String? {
        switch goal {
        case "Build physique":
            return "Strength, body composition, and gym output."
        case "Fix my looks":
            return "Face, grooming, skin, and presentation."
        case "Make more money":
            return "Income growth and execution consistency."
        case "Focus harder":
            return "Attention control and mental sharpness."
        case "Academics":
            return "Deep work, study cadence, and retention."
        case "Better social life":
            return "Confidence, conversations, and social reps."
        case "Fix my life overall":
            return "Cross-domain reset with strict structure."
        case "Other":
            return "Your own custom focus."
        default:
            return nil
        }
    }

    private func weaknessSubtitle(for weakness: String) -> String? {
        switch weakness {
        case "Consistency":
            return "Execution drops after the first push."
        case "Distraction / focus":
            return "Deep work gets broken by noise."
        case "Discipline with food":
            return "Nutrition slips under stress."
        case "Social confidence":
            return "Hesitation in social settings."
        case "Money management":
            return "Spend, save, and plan are unstable."
        case "Procrastination":
            return "Delay loop before starting tasks."
        case "Time management":
            return "Calendar gets crowded and chaotic."
        case "Other":
            return "A blocker not captured above."
        default:
            return nil
        }
    }

    private func obstacleSubtitle(for obstacle: String) -> String? {
        switch obstacle {
        case "No clear plan":
            return "I know the goal but not the path."
        case "Inconsistent routine":
            return "I start strong and drop off fast."
        case "Low energy":
            return "Sleep, stress, or fatigue kills momentum."
        case "Phone distractions":
            return "Scroll loops break focus windows."
        case "Fear of judgment":
            return "I hesitate because of what people think."
        case "No accountability":
            return "No one tracks if I execute."
        case "Overthinking":
            return "Planning never turns into action."
        case "Other":
            return "A specific blocker not listed."
        default:
            return nil
        }
    }

    private func unitSwitch<T: CaseIterable & Hashable & RawRepresentable>(
        options: T.AllCases,
        selected: T,
        action: @escaping (T) -> Void
    ) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
        HStack(spacing: 6) {
            ForEach(Array(options), id: \.self) { option in
                Button {
                    action(option)
                } label: {
                    Text(option.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selected == option ? .white : Color(hex: "5D5D5D"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected == option ? OnboardingUI.red : OnboardingUI.cardAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
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

    private func maxxContextField(for domain: MaxxDomain) -> some View {
        let binding = Binding<String>(
            get: { vm.maxxContextNote(for: domain) },
            set: { vm.setMaxxContextNote($0, for: domain) }
        )

        return ZStack(alignment: .topLeading) {
            if binding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Specific details for \(domain.title)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "2D2D2D"))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }

            TextEditor(text: binding)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "D0D0D0"))
                .frame(minHeight: 92, maxHeight: 128)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .background(OnboardingUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(OnboardingUI.fieldBorder, lineWidth: 0.5)
        )
    }

    private func handleStepTransition() {
        if vm.isFinalAnalysisStep {
            startMaxxGenerationAnimation()
            return
        }

        generationTask?.cancel()
        hasGeneratedInitialMaxx = false
        generationProgress = 0
        generationPhaseIndex = 0
        generationErrorMessage = nil
        isSyncingOnboarding = false
        syncedProfile = nil
    }

    private func startMaxxGenerationAnimation() {
        generationTask?.cancel()
        hasGeneratedInitialMaxx = false
        generationProgress = 0.06
        generationPhaseIndex = 0
        generationErrorMessage = nil
        isSyncingOnboarding = true
        syncedProfile = nil

        generationTask = Task { @MainActor in
            let pendingProfile = vm.buildProfile(userId: "ios-dev-user")
            let checkpoints: [Double] = [0.24, 0.48, 0.76, 1.0]
            async let syncResult = session.syncOnboardingProfile(pendingProfile)

            for (index, value) in checkpoints.enumerated() {
                try? await Task.sleep(nanoseconds: 420_000_000)
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.24)) {
                    generationProgress = value
                    generationPhaseIndex = min(index, generationPhases.count - 1)
                }
            }

            do {
                syncedProfile = try await syncResult
            } catch {
                if Task.isCancelled { return }
                generationErrorMessage = "Could not sync onboarding to backend. Check API/server and retry."
                generationProgress = 0.16
                generationPhaseIndex = 0
                isSyncingOnboarding = false
                return
            }

            try? await Task.sleep(nanoseconds: 220_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                hasGeneratedInitialMaxx = true
                isSyncingOnboarding = false
            }
        }
    }

    private func completeOnboarding() {
        focusedField = nil
        generationTask?.cancel()
        let profile = vm.buildProfile(userId: "ios-dev-user")
        session.completeOnboarding(with: profile)
    }

    private func enterLockedIn() {
        focusedField = nil
        if let syncedProfile {
            session.setProfile(syncedProfile)
            return
        }
        completeOnboarding()
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
