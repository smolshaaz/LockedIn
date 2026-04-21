import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            LockGridBackground()

            VStack(alignment: .leading, spacing: 22) {
                Spacer()

                Text("Meet LOCK")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(LockPalette.textPrimary)

                Text("Your blunt, strategic AI friend for execution. No fluff. No fake hype.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(LockPalette.textSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Physique, focus, money, social edge", systemImage: "target")
                    Label("Weekly LifeScore reflection", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Daily action logging with evidence", systemImage: "checklist")
                }
                .font(.headline)
                .foregroundStyle(LockPalette.textPrimary)

                Spacer()

                Button(action: onStart) {
                    Text("Start Quick Setup")
                }
                .buttonStyle(LockPrimaryButtonStyle())
            }
            .padding(22)
            .lockCard()
            .padding(20)
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}
