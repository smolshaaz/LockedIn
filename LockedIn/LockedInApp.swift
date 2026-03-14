import SwiftUI

@main
struct LockedInApp: App {
    @StateObject private var session = AppSessionViewModel()
    @StateObject private var store = ExperienceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
