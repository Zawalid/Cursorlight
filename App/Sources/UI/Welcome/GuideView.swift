import AppKit
import CursorlightCore
import SwiftUI

enum GuideStep: Int, CaseIterable {
    case intro, shake, laser, ink, done

    var isCoach: Bool { self == .shake || self == .laser || self == .ink }

    var panelSize: CGSize {
        switch self {
        case .intro: CGSize(width: 480, height: 292)
        case .shake, .laser, .ink: CGSize(width: 580, height: 84)
        case .done: CGSize(width: 420, height: 318)
        }
    }
}

/// The welcome guide is not a window with slides. It is a small native HUD that floats over your real screen and asks you to
/// do the real thing: shake, press the laser key, press the ink key. Each one runs the real feature, and the guide moves on when
/// it sees the feature work. The HUD material and rounded corners come from the controller; this view is only the content.
struct GuideView: View {
    enum Phase { case waiting, success }

    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: GuideStep
    @State private var phase: Phase
    @State private var inkSeen: Bool
    @State private var stepStartedAt = Date()
    @State private var stuck = false
    let autonomous: Bool
    let stepChanged: (GuideStep) -> Void
    let succeeded: () -> Void
    let finish: () -> Void

    init(
        startAt step: GuideStep = .intro, phase: Phase = .waiting, inkSeen: Bool = false, autonomous: Bool = true,
        stepChanged: @escaping (GuideStep) -> Void = { _ in }, succeeded: @escaping () -> Void = {}, finish: @escaping () -> Void
    ) {
        _step = State(initialValue: step)
        _phase = State(initialValue: phase)
        _inkSeen = State(initialValue: inkSeen)
        self.autonomous = autonomous
        self.stepChanged = stepChanged
        self.succeeded = succeeded
        self.finish = finish
    }

    var body: some View {
        ZStack {
            switch step {
            case .intro: introCard.id(step).transition(.opacity)
            case .done: doneCard.id(step).transition(.opacity)
            default: coachBar.id(step).transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1).allowsHitTesting(false))
        .preferredColorScheme(.dark)
        .onReceive(Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()) { _ in tick() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshInputMonitoring() }
        .onAppear { if autonomous, model.isPaused { model.setPaused(false) } }
    }

    // MARK: Flow

    private func go(to next: GuideStep) {
        stepChanged(next)
        withAnimation(.easeOut(duration: 0.25)) {
            step = next
            phase = .waiting
            inkSeen = false
            stuck = false
        }
        stepStartedAt = Date()
        if autonomous {
            stopEffects()
            if next == .done { model.pingStatusItem() }
        }
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
                if !inkSeen { withAnimation(.easeOut(duration: 0.2)) { inkSeen = true } }
            } else if inkSeen {
                succeed()
            }
        default: break
        }
        if step.isCoach, !stuck, !inkSeen, Date().timeIntervalSince(stepStartedAt) > 14 { withAnimation { stuck = true } }
    }

    private func succeed() {
        let current = step
        withAnimation(.easeOut(duration: 0.25)) { phase = .success }
        NSSound(named: "Tink")?.play()
        succeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            if step == current { advance() }
        }
    }

    // MARK: Intro

    private var introCard: some View {
        VStack(spacing: 0) {
            Image(nsImage: WelcomeStyle.icon)
                .resizable().interpolation(.high)
                .frame(width: 72, height: 72).scaleEffect(1.24)
                .reveal(0)
                .padding(.bottom, 22)
            Text("Cursorlight")
                .font(.system(size: 26, weight: .semibold)).tracking(-0.4)
                .foregroundStyle(WelcomeStyle.text)
                .reveal(1)
            Text("Let's make your pointer impossible to miss. You will try each thing for real, on your own screen.")
                .font(.system(size: 14)).lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(WelcomeStyle.dim)
                .frame(maxWidth: 340)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .reveal(2)
            HStack(spacing: 6) {
                Button("Not now", action: end).buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button { advance() } label: { Text("Show me") }
                    .buttonStyle(EmberButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(.top, 24)
            .reveal(3)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Coach

    private var coachBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                ForEach(1...3, id: \.self) { i in
                    Circle().fill(i <= step.rawValue ? WelcomeStyle.ember : Color.white.opacity(0.22)).frame(width: 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step.rawValue) of 3")
            VStack(alignment: .leading, spacing: 3) {
                instruction
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(WelcomeStyle.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusMark(done: phase == .success)
            Button(stuck ? "Skip step" : "Skip", action: advance)
                .buttonStyle(QuietButtonStyle()).font(.system(size: 12))
            Button(action: end) {
                Image(systemName: "xmark").font(.system(size: 10.5, weight: .bold)).foregroundStyle(WelcomeStyle.dim)
                    .frame(width: 22, height: 22).background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain).accessibilityLabel("Close the guide")
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var instruction: some View {
        switch (step, phase) {
        case (.shake, .waiting): title("Shake your mouse")
        case (.shake, .success): title("There it is")
        case (.laser, .waiting): keys("Press", ["⌃", "⌥", "L"])
        case (.laser, .success): title("A laser, in every app")
        case (.ink, .waiting): if inkSeen { title("Now draw something") } else { keys("Press", ["⌃", "⌥", "I"]) }
        case (.ink, .success): title("Drawings fade by themselves")
        default: EmptyView()
        }
    }

    private var detail: String {
        let taken = "Another app already uses this shortcut. Change it in Settings."
        switch (step, phase) {
        case (.shake, .waiting):
            return stuck ? "Quick, side to side. Make sure shake is on in Settings." : "Side to side, quickly, anywhere on your screen."
        case (.shake, .success):
            return "Shake again any time to hide it."
        case (.laser, .waiting):
            return model.failedHotkeys.contains(.laser) ? taken : "Then move your pointer. Press again to stop."
        case (.laser, .success):
            return "Hold it for a moment when you want people to look."
        case (.ink, .waiting):
            if inkSeen { return "Press the same keys again when you are done." }
            return model.failedHotkeys.contains(.ink) ? taken : "Draw on top of anything. Press again to stop."
        case (.ink, .success):
            return "That is everything. One more look around."
        default:
            return ""
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold)).tracking(-0.2)
            .foregroundStyle(WelcomeStyle.text)
            .lineLimit(1)
    }

    private func keys(_ prefix: String, _ keys: [String]) -> some View {
        HStack(spacing: 9) {
            title(prefix)
            HStack(spacing: 4) { ForEach(keys, id: \.self) { WKey(text: $0) } }
        }
    }

    // MARK: Done

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("That is the tour")
                .font(.system(size: 24, weight: .semibold)).tracking(-0.4)
                .foregroundStyle(WelcomeStyle.text)
                .reveal(0)
            Text("Cursorlight lives in your menu bar, where the icon just blinked: scenes, tools and settings.")
                .font(.system(size: 14)).lineSpacing(3)
                .foregroundStyle(WelcomeStyle.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
                .reveal(1)
            VStack(spacing: 0) {
                note(symbol: "rectangle.on.rectangle", title: "When you share, pick the entire screen", body: "A single window hides every effect from viewers.")
                Rectangle().fill(WelcomeStyle.hairline).frame(height: 1)
                permission
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WelcomeStyle.hairline, lineWidth: 1))
            .padding(.top, 16)
            .reveal(2)
            Spacer(minLength: 12)
            HStack {
                Spacer()
                Button { end(); if autonomous { model.openSettings(.highlight) } } label: { Text("Start using \(Branding.appName)") }
                    .buttonStyle(EmberButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .reveal(3)
        }
        .padding(24)
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

/// Waiting: a soft ping, driven by Core Animation so it costs the main thread nothing. Done: a green check.
private struct StatusMark: View {
    let done: Bool
    @State private var ping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if done {
                Circle().fill(WelcomeStyle.ok)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(red: 0.05, green: 0.16, blue: 0.09)))
                    .frame(width: 26, height: 26)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else {
                Circle().strokeBorder(WelcomeStyle.ember, lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                    .scaleEffect(ping ? 1.0 : 0.45)
                    .opacity(ping ? 0 : 0.9)
                Circle().fill(WelcomeStyle.ember).frame(width: 9, height: 9)
            }
        }
        .frame(width: 30, height: 30)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: done)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) { ping = true }
        }
        .accessibilityLabel(done ? "Done" : "Waiting for you")
    }
}
