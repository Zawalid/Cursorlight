import BeaconCore
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark().frame(width: 24, height: 24)
                Text(Branding.appName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Pill(text: model.isPaused ? "Paused" : "On", tint: model.isPaused ? Theme.warn : Theme.ok)
            }
            Text("NOW").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.faint).padding(.top, 16).padding(.bottom, 8)
            HStack(spacing: 8) {
                quick("Highlight", .highlight)
                quick("Laser", .laser)
                quick("Ink", .ink)
            }
            .opacity(model.isPaused ? 0.45 : 1)
            .allowsHitTesting(!model.isPaused)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "rectangle.on.rectangle").foregroundStyle(Theme.dim).font(.system(size: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share the whole screen").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                    Text("Viewers only see effects when you share a full display, not one window.")
                        .font(.system(size: 11)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .padding(.top, 14)

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
        .preferredColorScheme(.dark)
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
