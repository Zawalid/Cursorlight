import AppKit
import CursorlightCore
import SwiftUI

/// Look of the welcome guide. It is always dark: it is a small stage, not a settings page, and it shares the icon's palette.
enum WelcomeStyle {
    static let text = Color(red: 0.97, green: 0.95, blue: 0.98)
    static let dim = Color(red: 0.97, green: 0.95, blue: 0.98).opacity(0.68)
    static let faint = Color(red: 0.97, green: 0.95, blue: 0.98).opacity(0.46)
    static let hairline = Color.white.opacity(0.09)
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
            .blur(radius: shown || reduceMotion ? 0 : 6)
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
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(
                Capsule().fill(LinearGradient(
                    colors: [Color(red: 1, green: 0.45, blue: 0.28), Color(red: 0.92, green: 0.29, blue: 0.15)],
                    startPoint: .top, endPoint: .bottom
                ))
            )
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.0)], startPoint: .top, endPoint: .center), lineWidth: 1))
            .shadow(color: WelcomeStyle.ember.opacity(0.38), radius: 14, y: 5)
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
            .contentShape(Capsule())
    }
}

/// A keyboard key, drawn for the dark stage.
struct WKey: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(WelcomeStyle.text)
            .frame(minWidth: 24, minHeight: 24)
            .padding(.horizontal, text.count > 1 ? 5 : 0)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.07)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 0, y: 1.5)
    }
}

/// Ambient background: deep violet with slow ember and violet light that moves to a new place on every step.
struct WelcomeBackdrop: View {
    let step: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Light { let color: Color; let radius: CGFloat; let positions: [CGPoint]; let drift: CGFloat; let speed: Double }

    private let lights: [Light] = [
        Light(color: Color(red: 1, green: 0.34, blue: 0.2).opacity(0.5), radius: 300,
              positions: [CGPoint(x: 630, y: 290), CGPoint(x: 600, y: 250), CGPoint(x: 620, y: 330), CGPoint(x: 560, y: 220), CGPoint(x: 650, y: 120)], drift: 26, speed: 0.22),
        Light(color: Color(red: 0.42, green: 0.28, blue: 0.95).opacity(0.55), radius: 360,
              positions: [CGPoint(x: 150, y: 110), CGPoint(x: 190, y: 470), CGPoint(x: 120, y: 190), CGPoint(x: 230, y: 420), CGPoint(x: 170, y: 480)], drift: 34, speed: 0.17),
        Light(color: Color(red: 0.86, green: 0.22, blue: 0.5).opacity(0.28), radius: 260,
              positions: [CGPoint(x: 420, y: 560), CGPoint(x: 760, y: 520), CGPoint(x: 380, y: 60), CGPoint(x: 760, y: 80), CGPoint(x: 420, y: 540)], drift: 20, speed: 0.27),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.085, green: 0.055, blue: 0.16), Color(red: 0.03, green: 0.024, blue: 0.065)], startPoint: .top, endPoint: .bottom)
            ForEach(lights.indices, id: \.self) { index in
                let light = lights[index]
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate * light.speed + Double(index) * 2.1
                    Circle()
                        .fill(RadialGradient(colors: [light.color, light.color.opacity(0.35), light.color.opacity(0)], center: .center, startRadius: 0, endRadius: light.radius))
                        .frame(width: light.radius * 2, height: light.radius * 2)
                        .offset(x: CGFloat(sin(t)) * light.drift, y: CGFloat(cos(t * 0.8)) * light.drift)
                }
                .position(light.positions[min(step, light.positions.count - 1)])
                .animation(WelcomeStyle.easeLong, value: step)
            }
            // Hold the corners down so the text keeps its contrast.
            RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center, startRadius: 260, endRadius: 620)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
