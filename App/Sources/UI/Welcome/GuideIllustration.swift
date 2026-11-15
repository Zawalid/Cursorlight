import AppKit
import SwiftUI

/// Which hint is drawn in the middle of the screen. Nil means nothing.
final class IllustrationState: ObservableObject {
    @Published var step: GuideStep?
}

/// A faint, looping picture in the middle of the real screen that shows what to do, so the guide never has to explain in words.
/// It is click-through, and every loop is driven by Core Animation, so it does not cost the main thread each frame.
struct IllustrationRoot: View {
    @ObservedObject var state: IllustrationState

    var body: some View {
        ZStack {
            if let step = state.step, step.isCoach {
                ZStack {
                    RadialGradient(colors: [Color.black.opacity(0.2), Color.black.opacity(0)], center: .center, startRadius: 0, endRadius: 250)
                    switch step {
                    case .shake: ShakeIllustration()
                    case .laser: LaserIllustration()
                    default: InkIllustration()
                    }
                }
                .id(step)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeOut(duration: 0.45), value: state.step)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let unit: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1.0), CGPoint(x: 0.24, y: 0.78), CGPoint(x: 0.40, y: 1.14),
            CGPoint(x: 0.60, y: 1.05), CGPoint(x: 0.44, y: 0.70), CGPoint(x: 0.76, y: 0.70),
        ]
        let scale = rect.height / 1.14
        var path = Path()
        for (i, point) in unit.enumerated() {
            let p = CGPoint(x: rect.minX + point.x * scale, y: rect.minY + point.y * scale)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

private struct GhostCursor: View {
    var body: some View {
        ArrowShape()
            .fill(Color.white)
            .overlay(ArrowShape().stroke(Color.black.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineJoin: .round)))
            .frame(width: 44, height: 60)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

private func loop(_ duration: Double, delay: Double = 0) -> Animation {
    .easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)
}

private struct ShakeIllustration: View {
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [WelcomeStyle.ember.opacity(0.55), WelcomeStyle.ember.opacity(0)], center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 240, height: 240)
                .scaleEffect(on ? 1.12 : 0.8)
                .opacity(on ? 0.9 : 0.35)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: on)
            ForEach(0..<3, id: \.self) { i in
                GhostCursor()
                    .opacity(i == 0 ? 0.95 : 0.2 / Double(i))
                    .offset(x: reduceMotion ? 0 : (on ? 96 : -96))
                    .animation(reduceMotion ? nil : loop(0.3, delay: Double(i) * 0.045), value: on)
            }
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.4), radius: 4)
                .offset(y: 84)
        }
        .onAppear { on = true }
    }
}

private struct LaserIllustration: View {
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            HStack(spacing: 34) {
                ForEach(["⌃", "⌥", "L"], id: \.self) { WKey(text: $0, large: true).scaleEffect(1.45) }
            }
            .padding(.horizontal, 8)
            .scaleEffect(on ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: on)
            .offset(y: -62)
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color(red: 1, green: 0.55, blue: 0.42))
                        .frame(width: 16 - CGFloat(i) * 2.4, height: 16 - CGFloat(i) * 2.4)
                        .opacity(1 - Double(i) * 0.2)
                        .shadow(color: WelcomeStyle.ember, radius: i == 0 ? 10 : 0)
                        .offset(x: reduceMotion ? 0 : (on ? 150 : -150), y: reduceMotion ? 0 : (on ? 26 : -26))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.05), value: on)
                }
            }
            .offset(y: 62)
        }
        .onAppear { on = true }
    }
}

private struct DrawnStroke: Shape {
    var trim: CGFloat
    var animatableData: CGFloat {
        get { trim }
        set { trim = newValue }
    }

    static func base(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + 20))
        path.addCurve(to: CGPoint(x: rect.midX - 20, y: rect.minY + 10), control1: CGPoint(x: rect.minX + 40, y: rect.minY - 20), control2: CGPoint(x: rect.midX - 80, y: rect.minY - 10))
        path.addCurve(to: CGPoint(x: rect.midX + 40, y: rect.maxY - 10), control1: CGPoint(x: rect.midX + 40, y: rect.minY + 30), control2: CGPoint(x: rect.midX - 30, y: rect.maxY + 10))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY - 30), control1: CGPoint(x: rect.midX + 100, y: rect.maxY - 40), control2: CGPoint(x: rect.maxX - 60, y: rect.midY + 20))
        return path
    }

    func path(in rect: CGRect) -> Path { Self.base(in: rect).trimmedPath(from: 0, to: trim) }
}

private struct StrokeTip: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let point = DrawnStroke.base(in: rect).trimmedPath(from: max(0, progress - 0.002), to: max(0.002, progress)).currentPoint ?? .zero
        return Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
    }
}

private struct InkIllustration: View {
    @State private var drawn: CGFloat = 0
    @State private var faded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ZStack {
                DrawnStroke(trim: reduceMotion ? 1 : drawn)
                    .stroke(WelcomeStyle.ember.opacity(0.35), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
                DrawnStroke(trim: reduceMotion ? 1 : drawn)
                    .stroke(WelcomeStyle.emberLight, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                StrokeTip(progress: reduceMotion ? 1 : drawn)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
            .frame(width: 360, height: 150)
            .opacity(faded ? 0 : 1)
            .offset(y: 30)
            HStack(spacing: 26) {
                ForEach(["⌃", "⌥", "I"], id: \.self) { WKey(text: $0, large: true).scaleEffect(1.3) }
            }
            .offset(y: -76)
        }
        .onAppear {
            guard !reduceMotion else { return }
            // Draw the stroke, hold it, let it fade like real ink does, then start again.
            func cycle() {
                drawn = 0
                faded = false
                withAnimation(.easeInOut(duration: 1.7)) { drawn = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { withAnimation(.easeOut(duration: 0.8)) { faded = true } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) { cycle() }
            }
            cycle()
        }
    }
}
