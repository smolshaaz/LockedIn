import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: AppSessionViewModel

    @StateObject private var chatVM: ChatViewModel
    @StateObject private var lifeScoreVM: LifeScoreViewModel
    @StateObject private var profileVM: ProfileViewModel

    init() {
        let api = LockedInAPIService()
        _chatVM = StateObject(wrappedValue: ChatViewModel(api: api))
        _lifeScoreVM = StateObject(wrappedValue: LifeScoreViewModel(api: api))
        _profileVM = StateObject(wrappedValue: ProfileViewModel(api: api))
    }

    var body: some View {
        Group {
            switch session.launchPhase {
            case .splash:
                SplashView()

            case .welcome:
                WelcomeView {
                    session.markWelcomeSeen()
                }

            case .onboarding:
                OnboardingView()

            case .ready:
                MainTabShellView(
                    chatVM: chatVM,
                    lifeScoreVM: lifeScoreVM,
                    profileVM: profileVM
                )
            }
        }
        .task {
            await session.bootstrap()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSessionViewModel())
        .environmentObject(ExperienceStore())
}
