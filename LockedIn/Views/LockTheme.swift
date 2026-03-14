import SwiftUI

enum LockPalette {
    static let background = Color(red: 0.03, green: 0.04, blue: 0.06)
    static let backgroundElevated = Color(red: 0.06, green: 0.07, blue: 0.1)
    static let card = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let cardAlt = Color(red: 0.11, green: 0.12, blue: 0.16)
    static let accent = Color(red: 0.93, green: 0.2, blue: 0.28)
    static let accentSoft = Color(red: 0.93, green: 0.2, blue: 0.28).opacity(0.2)
    static let stroke = Color.white.opacity(0.12)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.52)
}

struct LockGridBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LockPalette.background

                Path { path in
                    let spacing: CGFloat = 28
                    let width = proxy.size.width
                    let height = proxy.size.height

                    var x: CGFloat = 0
                    while x <= width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                        x += spacing
                    }

                    var y: CGFloat = 0
                    while y <= height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                        y += spacing
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
            }
            .ignoresSafeArea()
        }
    }
}

struct LockCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(LockPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LockPalette.stroke, lineWidth: 1)
            )
    }
}

struct LockPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(configuration.isPressed ? LockPalette.accent.opacity(0.75) : LockPalette.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func lockScreenBackground() -> some View {
        background(LockGridBackground())
    }

    func lockCard() -> some View {
        modifier(LockCardModifier())
    }
}
