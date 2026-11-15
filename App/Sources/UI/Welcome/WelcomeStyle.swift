import AppKit
import CursorlightCore
import SwiftUI

/// Look of the welcome guide. It is always dark: it is a small stage, not a settings page, and it shares the icon's palette.
enum WelcomeStyle {
    static let text = Color(red: 0.97, green: 0.95, blue: 0.98)
    static let dim = Color(red: 0.97, green: 0.95, blue: 0.98).opacity(0.68)
    static let faint = Color(red: 0.97, green: 0.95, blue: 0.98).opacity(0.46)
    static let hairline = Color.white.opacity(0.09)
    static let base = Color(red: 0.078, green: 0.072, blue: 0.098)
    static let panel = Color(red: 0.108, green: 0.1, blue: 0.133)
    static let ember = Color(red: 1.0, green: 0.353, blue: 0.212)
    static let emberLight = Color(red: 1.0, green: 0.62, blue: 0.46)
    static let ok = Color(red: 0.42, green: 0.86, blue: 0.58)
    static let warn = Color(red: 1.0, green: 0.74, blue: 0.34)

    /// A strong ease-out: quick to respond, long soft landing.
    static let ease = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.55)
    static let easeLong = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.9)

    static var icon: NSImage { NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage }
}

/// Fades, lifts and unblurs an element in, a beat after the one before it.
struct Reveal: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(WelcomeStyle.ease.delay(reduceMotion ? 0 : 0.08 + Double(index) * 0.075)) { shown = true }
            }
    }
}

extension View {
    func reveal(_ index: Int) -> some View { modifier(Reveal(index: index)) }
}

/// What the previous step's text does as it leaves.
struct Drift: ViewModifier {
    var x: CGFloat
    var blur: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: x).blur(radius: blur).opacity(opacity)
    }
}

struct EmberButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.93, green: 0.31, blue: 0.17).opacity(configuration.isPressed ? 0.88 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(configuration.isPressed ? WelcomeStyle.text : WelcomeStyle.dim)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A keyboard key, drawn for the dark stage.
struct WKey: View {
    let text: String
    var large = false

    var body: some View {
        Text(text)
            .font(.system(size: large ? 17 : 12, weight: .semibold, design: .rounded))
            .foregroundStyle(WelcomeStyle.text)
            .frame(minWidth: large ? 36 : 24, minHeight: large ? 36 : 24)
            .padding(.horizontal, text.count > 1 ? 5 : 0)
            .background(
                RoundedRectangle(cornerRadius: large ? 9 : 7, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.07)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: large ? 9 : 7, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 0, y: 1.5)
    }
}
