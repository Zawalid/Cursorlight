import AppKit
import CursorlightCore
import SwiftUI

/// The welcome guide: five short steps on one persistent stage. Text on the left changes with each step, the stage on the
/// right is playable where it can be (shake, laser, ink, spotlight), so people learn by doing it once.
struct FirstRunView: View {
    static let size = CGSize(width: 840, height: 580)
    static let stepCount = 5

    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Int
    @State private var forward = true
    @State private var tool: DemoMode = .laser
    @State private var demo = DemoPointer()
    let finish: () -> Void

    init(startAt step: Int = 0, finish: @escaping () -> Void) {
        _step = State(initialValue: step)
        self.finish = finish
    }

    var body: some View {
        ZStack {
            WelcomeBackdrop(step: step)
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 40) {
                    copyColumn
                    stage
                }
                .padding(.top, 56).padding(.horizontal, 44)
                .frame(maxHeight: .infinity)
                bottomBar.padding(.horizontal, 44).padding(.bottom, 30)
            }
            keyboardShortcuts
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshInputMonitoring()
        }
    }

    // MARK: Navigation

    private func advance() {
        if step >= Self.stepCount - 1 {
            model.markWelcomeSeen()
            finish()
        } else {
            forward = true
            withAnimation(WelcomeStyle.ease) { step += 1 }
        }
    }

    private func goBack() {
        guard step > 0 else { return }
        forward = false
        withAnimation(WelcomeStyle.ease) { step -= 1 }
    }

    private var keyboardShortcuts: some View {
        HStack {
            Button("Back", action: goBack).keyboardShortcut(.leftArrow, modifiers: [])
            Button("Next", action: advance).keyboardShortcut(.rightArrow, modifiers: [])
        }
        .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<Self.stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? WelcomeStyle.ember : Color.white.opacity(i < step ? 0.4 : 0.16))
                        .frame(width: i == step ? 26 : 6, height: 6)
                }
            }
            .animation(WelcomeStyle.ease, value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step + 1) of \(Self.stepCount)")
            Spacer()
            if step > 0 {
                Button("Back", action: goBack).buttonStyle(QuietButtonStyle()).transition(.opacity)
            }
            Button(action: advance) { Text(primaryTitle).frame(minWidth: 68) }
                .buttonStyle(EmberButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
    }

    private var primaryTitle: String {
        switch step {
        case 0: "Get started"
        case Self.stepCount - 1: "Start using \(Branding.appName)"
        default: "Continue"
        }
    }

    // MARK: Stage

    private var stage: some View {
        ZStack {
            switch step {
            case 0: IntroStage().id("intro").transition(stageTransition)
            case 1: DemoStage(demo: demo, mode: .aura).id("demo").transition(stageTransition)
            case 2: DemoStage(demo: demo, mode: tool).id("demo").transition(stageTransition)
            case 3: ShareStage().id("share").transition(stageTransition)
            default: MenuBarStage().id("menubar").transition(stageTransition)
            }
        }
        .frame(width: 400, height: 400)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.09, blue: 0.2).opacity(0.78), Color(red: 0.06, green: 0.045, blue: 0.11).opacity(0.86)], startPoint: .top, endPoint: .bottom))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 40, y: 24)
    }

    private var stageTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity)
    }

    // MARK: Copy

    private var copyColumn: some View {
        ZStack(alignment: .leading) {
            Group {
                switch step {
                case 0: introCopy
                case 1: shakeCopy
                case 2: toolsCopy
                case 3: shareCopy
                default: doneCopy
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .opacity,
                removal: reduceMotion ? .opacity : .modifier(active: Drift(x: forward ? -26 : 26, blur: 8, opacity: 0), identity: Drift(x: 0, blur: 0, opacity: 1))
            ))
        }
        .frame(width: 340, alignment: .leading)
    }

    private func heading(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(WelcomeStyle.text)
                .fixedSize(horizontal: false, vertical: true)
                .reveal(0)
            Text(body)
                .font(.system(size: 15.5))
                .lineSpacing(3)
                .foregroundStyle(WelcomeStyle.dim)
                .fixedSize(horizontal: false, vertical: true)
                .reveal(1)
        }
    }

    private var introCopy: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(Branding.appName.uppercased())
                .font(.system(size: 12, weight: .semibold)).tracking(1.6)
                .foregroundStyle(WelcomeStyle.ember)
                .reveal(0)
            VStack(alignment: .leading, spacing: 12) {
                Text("Be seen wherever you point.")
                    .font(.system(size: 38, weight: .semibold)).tracking(-0.8)
                    .foregroundStyle(WelcomeStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .reveal(1)
                Text("On a call, in a recording or on a stage, your pointer should never get lost. This takes about a minute.")
                    .font(.system(size: 15.5)).lineSpacing(3)
                    .foregroundStyle(WelcomeStyle.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .reveal(2)
            }
        }
    }

    private var shakeCopy: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Shake to find your cursor", "Lost it on a big display? Shake the mouse and a soft light finds your pointer. Shake again and it goes away.")
            HStack(spacing: 10) {
                Image(systemName: "hand.point.up.left.fill").foregroundStyle(WelcomeStyle.emberLight)
                Text("Try it on the stage. It works on your whole screen too.")
                    .font(.system(size: 13)).foregroundStyle(WelcomeStyle.dim)
            }
            .reveal(2)
        }
    }

    private var toolsCopy: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Point, draw, spotlight", "Pick a tool and try it on the stage. Each one has a shortcut that works in every app.")
            VStack(spacing: 6) {
                toolRow(.laser, symbol: "scope", title: "Laser", note: "A bright dot with a trail", keys: ["⌃", "⌥", "L"]).reveal(2)
                toolRow(.ink, symbol: "scribble.variable", title: "Ink", note: "Draw, then it fades away", keys: ["⌃", "⌥", "I"]).reveal(3)
                toolRow(.spotlight, symbol: "flashlight.on.fill", title: "Spotlight", note: "Dim all but one place", keys: ["⌃", "⌥", "S"]).reveal(4)
            }
        }
    }

    private func toolRow(_ mode: DemoMode, symbol: String, title: String, note: String, keys: [String]) -> some View {
        let selected = tool == mode
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { tool = mode }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? WelcomeStyle.emberLight : WelcomeStyle.dim)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(selected ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(WelcomeStyle.text)
                    Text(note).font(.system(size: 12)).foregroundStyle(WelcomeStyle.dim)
                }
                Spacer(minLength: 4)
                HStack(spacing: 3) { ForEach(keys, id: \.self) { WKey(text: $0) } }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(selected ? 0.085 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(selected ? WelcomeStyle.ember.opacity(0.55) : Color.clear, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var shareCopy: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Share the whole screen", "Cursorlight draws on your display. Viewers see it when you share the entire screen, not when you share a single window.")
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hold a key to point").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(WelcomeStyle.text)
                        Text("Optional. Lets Cursorlight see a double-tapped key while another app is in front.")
                            .font(.system(size: 12)).foregroundStyle(WelcomeStyle.dim).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if model.needsInputMonitoring {
                        Button("Allow") { model.requestInputMonitoring() }
                            .buttonStyle(QuietButtonStyle())
                            .background(Color.white.opacity(0.08), in: Capsule())
                    } else {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(WelcomeStyle.ok)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(WelcomeStyle.hairline, lineWidth: 1))
            }
            .reveal(2)
        }
    }

    private var doneCopy: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("You are all set", "Cursorlight lives in your menu bar. Click its icon for scenes, tools and settings.")
            VStack(spacing: 0) {
                shortcutRow("Highlight on or off", keys: ["⌃", "⌥", "H"])
                Rectangle().fill(WelcomeStyle.hairline).frame(height: 1)
                shortcutRow("Pause everything", keys: ["⌃", "⌥", "P"])
            }
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(WelcomeStyle.hairline, lineWidth: 1))
            .reveal(2)
        }
    }

    private func shortcutRow(_ title: String, keys: [String]) -> some View {
        HStack {
            Text(title).font(.system(size: 13.5)).foregroundStyle(WelcomeStyle.text)
            Spacer()
            HStack(spacing: 3) { ForEach(keys, id: \.self) { WKey(text: $0) } }
        }
        .padding(.vertical, 11)
    }
}
