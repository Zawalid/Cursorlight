import AppKit
import CursorlightCore
import SwiftUI

enum GuideStep: Int, CaseIterable {
    case intro, shake, laser, ink, done

    var isCoach: Bool { self == .shake || self == .laser || self == .ink }

    /// The card without its shadow margin.
    var cardSize: CGSize {
        switch self {
        case .intro: CGSize(width: 540, height: 320)
        case .shake, .laser, .ink: CGSize(width: 640, height: 120)
        case .done: CGSize(width: 440, height: 338)
        }
    }

    var panelSize: CGSize {
        CGSize(width: cardSize.width + GuideView.margin * 2, height: cardSize.height + GuideView.margin * 2)
    }
}

/// Shared between the panel controller and the view: where the caret under the menu bar points.
final class GuideState: ObservableObject {
    @Published var caretFromRight: CGFloat = 80
}

/// The welcome guide is not a window with slides. It is a small card that floats over your real screen and asks you to do the
/// real thing: shake, press the laser key, press the ink key. Each one runs the real feature, and the card moves on when it
/// sees it work.
struct GuideView: View {
    static let margin: CGFloat = 28

    enum Phase { case waiting, success }

    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var state: GuideState
    @State private var step: GuideStep
    @State private var phase: Phase
    @State private var inkSeen: Bool
    let autonomous: Bool
    let stepChanged: (GuideStep) -> Void
    let finish: () -> Void

    init(
        startAt step: GuideStep = .intro, phase: Phase = .waiting, inkSeen: Bool = false, autonomous: Bool = true,
        state: GuideState = GuideState(), stepChanged: @escaping (GuideStep) -> Void = { _ in }, finish: @escaping () -> Void
    ) {
        _step = State(initialValue: step)
        _phase = State(initialValue: phase)
        _inkSeen = State(initialValue: inkSeen)
        self.autonomous = autonomous
        self.state = state
        self.stepChanged = stepChanged
        self.finish = finish
    }

    var body: some View {
        ZStack {
            Group {
                switch step {
                case .intro: introCard
                case .done: doneCard
                default: coachCard
                }
            }
            .id(step)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 10)),
                removal: .opacity
            ))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(card)
        .overlay(alignment: .bottom) { if step.isCoach { progressLine } }
        .overlay(alignment: .topTrailing) { if step == .done { caret } }
        .padding(Self.margin)
        .preferredColorScheme(.dark)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in tick() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshInputMonitoring() }
        .onAppear { if autonomous, model.isPaused { model.setPaused(false) } }
    }

    // MARK: Card chrome

    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(WelcomeStyle.base)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 26, y: 14)
    }

    private var progressLine: some View {
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= step.rawValue ? WelcomeStyle.ember : Color.white.opacity(0.14))
                    .frame(height: 2)
            }
        }
        .padding(.horizontal, 22).padding(.bottom, 9)
        .animation(WelcomeStyle.ease, value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue) of 3")
    }

    private var caret: some View {
        ZStack {
            CaretShape().fill(WelcomeStyle.base)
            CaretShape().stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .frame(width: 22, height: 11)
        .offset(x: -(state.caretFromRight - 11), y: -10.5)
    }

    // MARK: Flow

    private func go(to next: GuideStep) {
        stepChanged(next)
        withAnimation(WelcomeStyle.ease) {
            step = next
            phase = .waiting
            inkSeen = false
        }
        if autonomous { stopEffects() }
    }

    private func advance() {
        guard let next = GuideStep(rawValue: step.rawValue + 1) else { return }
        go(to: next)
    }

    private func end() {
        if autonomous {
            stopEffects()
            model.markWelcomeSeen()
        }
        finish()
    }

    private func stopEffects() {
        for effect in [EffectKind.highlight, .laser] where model.isOn(effect) { model.toggle(effect) }
    }

    private func tick() {
        guard autonomous, phase == .waiting else { return }
        switch step {
        case .shake: if model.isOn(.highlight) { succeed() }
        case .laser: if model.isOn(.laser) { succeed() }
        case .ink:
            if model.isOn(.ink) {
                if !inkSeen { withAnimation(WelcomeStyle.ease) { inkSeen = true } }
            } else if inkSeen {
                succeed()
            }
        default: break
        }
    }

    private func succeed() {
        let current = step
        withAnimation(WelcomeStyle.ease) { phase = .success }
        NSSound(named: "Tink")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if step == current { advance() }
        }
    }

    // MARK: Intro

    private var introCard: some View {
        VStack(spacing: 0) {
            Image(nsImage: WelcomeStyle.icon)
                .resizable().interpolation(.high)
                .frame(width: 84, height: 84).scaleEffect(1.24)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
                .reveal(0)
                .padding(.bottom, 24)
            Text("Cursorlight")
                .font(.system(size: 30, weight: .semibold)).tracking(-0.5)
                .foregroundStyle(WelcomeStyle.text)
                .reveal(1)
            Text("Let's make your pointer impossible to miss. You will try each thing for real, on your own screen.")
                .font(.system(size: 15)).lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(WelcomeStyle.dim)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .reveal(2)
            HStack(spacing: 6) {
                Button("Not now", action: end).buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button { advance() } label: { Text("Show me") }
                    .buttonStyle(EmberButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(.top, 26)
            .reveal(3)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Coach

    private var coachCard: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                instruction
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(WelcomeStyle.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            orb
        }
        .padding(.horizontal, 28).padding(.top, 4).padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button("Skip guide", action: end)
                .buttonStyle(QuietButtonStyle())
                .font(.system(size: 12))
                .padding(.top, 2).padding(.trailing, 8)
        }
    }

    @ViewBuilder private var instruction: some View {
        switch (step, phase) {
        case (.shake, .waiting): big("Shake your mouse.")
        case (.shake, .success): big("There it is.")
        case (.laser, .waiting): keys("Press", ["⌃", "⌥", "L"])
        case (.laser, .success): big("A laser, in every app.")
        case (.ink, .waiting): if inkSeen { big("Now draw something.") } else { keys("Press", ["⌃", "⌥", "I"]) }
        case (.ink, .success): big("Drawings fade by themselves.")
        default: EmptyView()
        }
    }

    private var detail: String {
        switch (step, phase) {
        case (.shake, .waiting): "Side to side, quickly, anywhere on your screen. A light finds your pointer."
        case (.shake, .success): "Shake again any time to hide it. Next: the laser."
        case (.laser, .waiting): "Then move your pointer. Press it again to turn the laser off."
        case (.laser, .success): "Hold it for a moment when you want people to look. Last one: ink."
        case (.ink, .waiting): inkSeen ? "Press the same keys again when you are done." : "Draw on top of anything. Press the same keys again to stop."
        case (.ink, .success): "That is everything. One more look around."
        default: ""
        }
    }

    private func big(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .semibold)).tracking(-0.4)
            .foregroundStyle(WelcomeStyle.text)
            .lineLimit(1).minimumScaleFactor(0.8)
    }

    private func keys(_ prefix: String, _ keys: [String]) -> some View {
        HStack(spacing: 12) {
            big(prefix)
            HStack(spacing: 5) { ForEach(keys, id: \.self) { WKey(text: $0, large: true) } }
        }
    }

    /// Waiting: a quiet pulse that says the app is listening. Success: a check that lands.
    private var orb: some View {
        ZStack {
            if phase == .success {
                Circle().fill(WelcomeStyle.ok)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 18, weight: .bold)).foregroundStyle(Color(red: 0.05, green: 0.16, blue: 0.09)))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                    let phase = (timeline.date.timeIntervalSinceReferenceDate * 0.8).truncatingRemainder(dividingBy: 1)
                    ZStack {
                        Circle().strokeBorder(WelcomeStyle.ember.opacity((1 - phase) * 0.7), lineWidth: 2)
                            .frame(width: 22 + phase * 30, height: 22 + phase * 30)
                        Circle().fill(WelcomeStyle.ember).frame(width: 14, height: 14)
                    }
                }
            }
        }
        .frame(width: 46, height: 46)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: phase)
        .accessibilityLabel(phase == .success ? "Done" : "Waiting for you")
    }

    // MARK: Done

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("That is the tour.")
                .font(.system(size: 28, weight: .semibold)).tracking(-0.5)
                .foregroundStyle(WelcomeStyle.text)
                .reveal(0)
            Text("Cursorlight lives up here in your menu bar: scenes, tools and settings.")
                .font(.system(size: 14.5)).lineSpacing(3)
                .foregroundStyle(WelcomeStyle.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .reveal(1)
            VStack(spacing: 0) {
                note(symbol: "rectangle.on.rectangle", title: "When you share, pick the entire screen.", body: "A single window hides every effect from viewers.")
                Rectangle().fill(WelcomeStyle.hairline).frame(height: 1)
                permission
            }
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WelcomeStyle.hairline, lineWidth: 1))
            .padding(.top, 18)
            .reveal(2)
            Spacer(minLength: 14)
            HStack {
                Spacer()
                Button(action: end) { Text("Start using \(Branding.appName)") }
                    .buttonStyle(EmberButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .reveal(3)
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func note(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(WelcomeStyle.warn).frame(width: 20).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(WelcomeStyle.text)
                Text(body).font(.system(size: 12)).foregroundStyle(WelcomeStyle.dim)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var permission: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard").font(.system(size: 14, weight: .semibold)).foregroundStyle(WelcomeStyle.dim).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("Point by holding a key").font(.system(size: 13, weight: .semibold)).foregroundStyle(WelcomeStyle.text)
                Text("Optional. Needs Input Monitoring.").font(.system(size: 12)).foregroundStyle(WelcomeStyle.dim)
            }
            Spacer(minLength: 0)
            if model.needsInputMonitoring {
                Button("Allow") { model.requestInputMonitoring() }
                    .buttonStyle(QuietButtonStyle()).font(.system(size: 12))
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Label("Allowed", systemImage: "checkmark.circle.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(WelcomeStyle.ok)
            }
        }
        .padding(12)
    }
}

private struct CaretShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
