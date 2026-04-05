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

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
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
