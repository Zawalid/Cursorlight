import CursorlightCore
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark().frame(width: 24, height: 24)
                Text(Branding.appName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Pill(text: model.isPaused ? "Paused" : (model.isOffForApp ? "Off here" : "On"), tint: (model.isPaused || model.isOffForApp) ? Theme.warn : Theme.ok)
            }
            if model.isOffForApp {
                Text(model.hideReason.map { "Hidden: \($0.displayName.lowercased()) in front." } ?? "Cursorlight is off for the frontmost app.").font(.system(size: 12)).foregroundStyle(Theme.warn).padding(.top, 12)
            }
            Text("PROFILE").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.faint).padding(.top, 16).padding(.bottom, 8)
            HStack(spacing: 8) {
                ForEach(model.profiles.prefix(4)) { profile in
                    let active = model.appliedProfileID == profile.id
                    Button { model.chooseProfile(profile.id) } label: {
                        VStack(spacing: 2) {
                            Text(profile.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                            Text(profile.snapshot.highlightStyle.displayName).font(.system(size: 10)).foregroundStyle(Theme.dim)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(active ? Theme.accent : Theme.line, lineWidth: active ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            Text("NOW").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.faint).padding(.top, 16).padding(.bottom, 8)
            HStack(spacing: 8) {
                quick("Highlight", .highlight)
                quick("Laser", .laser)
                quick("Ink", .ink)
            }
            .opacity(model.isPaused ? 0.45 : 1)
            .allowsHitTesting(!model.isPaused)

            ShareStatusCard().padding(.top, 14)

            Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 14)
            HStack {
                footer("Settings...") { model.openSettings(.highlight) }
                Spacer()
                footer(model.isPaused ? "Resume" : "Pause") { model.setPaused(!model.isPaused) }
                Spacer()
                footer("Quit") { model.quit() }
            }
            .padding(.top, 10)
        }
        .padding(16)
        .frame(width: 320)
        .background(Theme.window)
    }

    private func quick(_ title: String, _ effect: EffectKind) -> some View {
        let on = model.isOn(effect)
        return Button { model.toggle(effect) } label: {
            Text(title).font(.system(size: 12, weight: .medium))
                .foregroundStyle(on ? Theme.text : Theme.dim)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(on ? Theme.accent.opacity(0.18) : Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(on ? Theme.accent.opacity(0.55) : Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func footer(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.dim).padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
