import SwiftUI
import UIKit

enum LockPalette {
    static let background = Color(red: 0.03, green: 0.04, blue: 0.06)
    static let backgroundElevated = Color(red: 0.06, green: 0.07, blue: 0.1)
    static let card = Color.black.opacity(0.56)
    static let cardAlt = Color.black.opacity(0.42)
    static let accent = Color(red: 0.93, green: 0.2, blue: 0.28)
    static let accentSoft = Color(red: 0.93, green: 0.2, blue: 0.28).opacity(0.2)
    static let stroke = Color.white.opacity(0.12)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.52)

    static let glassBase = Color.black.opacity(0.56)
    static let glassHighlight = Color.white.opacity(0.1)
    static let glassEdge = Color.white.opacity(0.2)
    static let glassShadow = Color.black.opacity(0.5)
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
            .lockGlassCard(cornerRadius: 16, tint: LockPalette.card)
    }
}

struct LockGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var tint: Color = LockPalette.glassBase

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(LockPalette.glassEdge.opacity(0.95), lineWidth: 1)
                    )
                    .shadow(color: LockPalette.glassShadow, radius: 30, x: 0, y: 14)
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

private struct SubtleAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity((isActive || reduceMotion) ? 1 : 0.001)
            .offset(y: (isActive || reduceMotion) ? 0 : 8)
            .animation(
                reduceMotion
                    ? nil
                    : .smooth(duration: 0.42, extraBounce: 0).delay(delay),
                value: isActive
            )
    }
}

extension View {
    func lockScreenBackground() -> some View {
        background(LockGridBackground())
    }

    func lockCard() -> some View {
        modifier(LockCardModifier())
    }

    func lockGlassCard(cornerRadius: CGFloat = 16, tint: Color = LockPalette.glassBase) -> some View {
        modifier(LockGlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func enableInteractiveSwipeBack() -> some View {
        background(InteractiveSwipeBackEnabler())
    }

    func subtleAppear(_ isActive: Bool, delay: Double = 0) -> some View {
        modifier(SubtleAppearModifier(isActive: isActive, delay: delay))
    }
}

private struct InteractiveSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.enableIfNeeded()
    }

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableIfNeeded()
        }

        func enableIfNeeded() {
            guard let nav = navigationController else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = nav.viewControllers.count > 1
        }
    }
}
