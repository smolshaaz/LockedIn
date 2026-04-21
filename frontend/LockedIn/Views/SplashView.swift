import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            LockGridBackground()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(LockPalette.accent)

                Text("LOCKEDIN")
                    .font(.system(.largeTitle, design: .rounded).weight(.black))
                    .foregroundStyle(LockPalette.textPrimary)
                    .tracking(2)

                Text("LOCK loading your week")
                    .font(.subheadline)
                    .foregroundStyle(LockPalette.textSecondary)

                ProgressView()
                    .tint(LockPalette.accent)
                    .padding(.top, 6)
            }
            .padding(30)
            .lockCard()
            .padding(.horizontal, 38)
        }
    }
}

#Preview {
    SplashView()
}
