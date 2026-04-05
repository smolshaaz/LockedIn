import SwiftUI

struct MainTabShellView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var store: ExperienceStore

    @ObservedObject var chatVM: ChatViewModel
    @ObservedObject var lifeScoreVM: LifeScoreViewModel
    @ObservedObject var profileVM: ProfileViewModel
    @State private var lastLockGestureAt: Date = .distantPast

    var body: some View {
        ZStack {
            TabView(selection: $store.selectedTab) {
                NavigationStack {
                    HomeView(
                        lifeScoreVM: lifeScoreVM,
                        profileVM: profileVM,
                        onOpenLock: openLock
                    )
                }
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)

                NavigationStack {
                    ProtocolsView()
                }
                .tabItem {
                    Label(AppTab.protocols.title, systemImage: AppTab.protocols.icon)
                }
                .tag(AppTab.protocols)

                NavigationStack {
                    LifeScoreView(vm: lifeScoreVM)
                }
                .tabItem {
                    Label(AppTab.lifeScore.title, systemImage: AppTab.lifeScore.icon)
                }
                .tag(AppTab.lifeScore)
            }
            .disabled(store.isLockPresented)

            if store.isLockPresented {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        closeLock()
                    }

                LockChatOverlay(
                    chatVM: chatVM,
                    currentObjective: lockObjective
                ) {
                    closeLock()
                }
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }
        }
        .tint(LockPalette.accent)
        .toolbarBackground(LockPalette.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .simultaneousGesture(lockOpenGesture)
        .onChange(of: store.isLockPresented) { _, isPresented in
            guard isPresented else { return }
            guard let domain = store.lockContextDomain else { return }

            chatVM.selectedDomain = domain
            chatVM.wantsProtocol = true
        }
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.88), value: store.isLockPresented)
    }

    private var lockObjective: String? {
        if let domain = store.lockContextDomain {
            return store.protocolDetail(for: domain).objective
        }
        return session.profile?.goals.first
    }

    private var lockOpenGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onEnded { value in
                guard !store.isLockPresented else { return }
                let cooldownActive = Date().timeIntervalSince(lastLockGestureAt) < 0.7
                if LockGestureRules.shouldOpen(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation,
                    cooldownActive: cooldownActive
                ) {
                    lastLockGestureAt = Date()
                    openLock()
                }
            }
    }

    private func openLock() {
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
            store.presentLock()
        }
    }

    private func closeLock() {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.9)) {
            store.dismissLock()
        }
    }
}

private struct LockChatOverlay: View {
    @ObservedObject var chatVM: ChatViewModel
    let currentObjective: String?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ChatView(vm: chatVM, currentObjective: currentObjective, showContextToggle: false)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Label("Swipe right to close", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LockPalette.accent)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            onClose()
                        }
                        .foregroundStyle(LockPalette.textSecondary)
                        .accessibilityIdentifier("lock.closeButton")
                    }
                }
        }
        .background(LockPalette.background.ignoresSafeArea())
        .simultaneousGesture(
            DragGesture(minimumDistance: 14, coordinateSpace: .global)
                .onEnded { value in
                    if LockGestureRules.shouldClose(
                        translation: value.translation,
                        predictedEndTranslation: value.predictedEndTranslation
                    ) {
                        onClose()
                    }
                }
        )
        .tint(LockPalette.accent)
    }
}
