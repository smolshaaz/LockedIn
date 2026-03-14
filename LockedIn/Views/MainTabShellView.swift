import SwiftUI

struct MainTabShellView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var store: ExperienceStore

    @ObservedObject var chatVM: ChatViewModel
    @ObservedObject var lifeScoreVM: LifeScoreViewModel
    @ObservedObject var profileVM: ProfileViewModel

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                HomeView(lifeScoreVM: lifeScoreVM, profileVM: profileVM)
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.icon)
            }
            .tag(AppTab.home)

            NavigationStack {
                LifeScoreView(vm: lifeScoreVM)
            }
            .tabItem {
                Label(AppTab.lifeScore.title, systemImage: AppTab.lifeScore.icon)
            }
            .tag(AppTab.lifeScore)

            NavigationStack {
                ChatView(vm: chatVM, currentObjective: session.profile?.goals.first)
            }
            .tabItem {
                Label(AppTab.lock.title, systemImage: AppTab.lock.icon)
            }
            .tag(AppTab.lock)

            NavigationStack {
                MaxxHubView()
            }
            .tabItem {
                Label(AppTab.maxx.title, systemImage: AppTab.maxx.icon)
            }
            .tag(AppTab.maxx)

            NavigationStack {
                LogsView()
            }
            .tabItem {
                Label(AppTab.logs.title, systemImage: AppTab.logs.icon)
            }
            .tag(AppTab.logs)
        }
        .tint(LockPalette.accent)
        .toolbarBackground(LockPalette.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
