import BeaconCore
import SwiftUI

struct FirstRunView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step: Int
    let finish: () -> Void

    init(startAt step: Int = 0, finish: @escaping () -> Void) {
        _step = State(initialValue: step)
        self.finish = finish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i <= step ? Theme.accent : Theme.fillMid).frame(height: 3)
                }
            }
            .padding(.bottom, 26)
            Group {
                switch step {
                case 0: shakeStep
                case 1: extrasStep
                default: doneStep
                }
            }
            .id(step)
            .transition(.opacity)
            Spacer(minLength: 18)
            HStack {
                Text("\(step + 1) of 3").font(.system(size: 12)).foregroundStyle(Theme.faint)
                Spacer()
                if step == 1 {
                    Button("Skip") { advance() }.buttonStyle(GhostButtonStyle())
                }
                Button(step == 2 ? "Start using \(Branding.appName)" : "Continue") { advance() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 38).padding(.vertical, 32)
        .frame(width: 580, height: 520)
        .background(Theme.window)
        .preferredColorScheme(.dark)
    }

    private func advance() {
        if step >= 2 {
            model.markWelcomeSeen()
            finish()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { step += 1 }
        }
    }

    private func heading(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 24, weight: .semibold)).foregroundStyle(Theme.text)
            Text(body).font(.system(size: 14)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 22)
    }

    private var shakeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Shake your pointer", "Move it side to side, quickly. A soft light finds your cursor on any screen, and stays until you shake again.")
            PreviewCanvas(style: .aura, look: .standard, height: 190)
            Text("Try it now: the real effect appears on your screen too.").font(.system(size: 12)).foregroundStyle(Theme.faint).padding(.top, 12)
        }
    }

    private var extrasStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Two optional extras", "Everything works without asking for anything. These unlock more, and you can skip them.")
            perm(
                title: "Double-tap and hold a key",
                body: "Needs Input Monitoring so Beacon can see the key while another app is in front.",
                tag: "Optional",
                action: model.needsInputMonitoring ? ("Allow", { model.requestInputMonitoring() }) : nil,
                done: !model.needsInputMonitoring
            )
            perm(
                title: "Share the whole screen",
                body: "Viewers only see effects when you share a full display, not a single window.",
                tag: "Good to know", action: nil, done: false
            )
        }
    }

    private func perm(title: String, body: String, tag: String, action: (String, () -> Void)?, done: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                Text(body).font(.system(size: 12)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if done { Pill(text: "Allowed", tint: Theme.ok) } else { Pill(text: tag) }
            if let action { Button(action.0, action: action.1).buttonStyle(GhostButtonStyle()) }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line))
        .padding(.bottom, 10)
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("You are set", "Beacon lives in the menu bar. These are the ways to summon it.")
            SettingsGroup {
                SettingRow(title: "Shake the pointer", subtitle: "Highlight on or off") { EmptyView() }
                SettingRow(title: "Highlight, laser, ink", subtitle: "Keyboard shortcuts work in every app") {
                    HStack(spacing: 4) { Keycap(text: "⌃"); Keycap(text: "⌥"); Keycap(text: "H / L / I") }
                }
                SettingRow(title: "Pause everything", showsDivider: false) {
                    HStack(spacing: 4) { Keycap(text: "⌃"); Keycap(text: "⌥"); Keycap(text: "P") }
                }
            }
        }
    }
}
