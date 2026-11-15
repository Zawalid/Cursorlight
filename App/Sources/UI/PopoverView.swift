import CursorlightCore
import SwiftUI

/// The menu bar popover: a master switch, the tools you reach for mid-call, the scene, and a share warning only when it matters.
struct PopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            tools
            sceneRow
            if model.shareStatus.needsAttention || !model.conferencingApps.isEmpty {
                ShareStatusCard()
            }
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: Header

    private var statusLine: (text: String, tint: Color) {
        if model.isPaused { return ("Paused", Theme.warn) }
        if model.isOffForApp { return (model.hideReason.map { "Off: \($0.displayName.lowercased())" } ?? "Off in this app", Theme.warn) }
        if model.anyEffectRunning { return ("Running", Theme.ok) }
        return ("Ready", Theme.dim)
    }

    private var header: some View {
        HStack(spacing: 11) {
            BrandMark().frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(Branding.appName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                HStack(spacing: 5) {
                    Circle().fill(statusLine.tint).frame(width: 6, height: 6)
                    Text(statusLine.text).font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
            }
            Spacer()
            Toggle("Cursorlight is on", isOn: Binding(get: { !model.isPaused }, set: { model.setPaused(!$0) }))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                .help(model.isPaused ? "Resume Cursorlight" : "Pause Cursorlight")
        }
    }

    // MARK: Tools

    private var tools: some View {
        HStack(spacing: 8) {
            tile("Highlight", symbol: "circle.dashed", keys: "⌃⌥H", on: model.isOn(.highlight)) { model.toggle(.highlight) }
            tile("Laser", symbol: "scope", keys: "⌃⌥L", on: model.isOn(.laser)) { model.toggle(.laser) }
            tile("Ink", symbol: "scribble.variable", keys: "⌃⌥I", on: model.isOn(.ink)) { model.toggle(.ink) }
            tile("Spotlight", symbol: "flashlight.on.fill", keys: "⌃⌥S", on: model.spotlightState != .idle) { model.cycleSpotlight() }
        }
        .opacity(model.isPaused ? 0.45 : 1)
        .allowsHitTesting(!model.isPaused)
    }

    private func tile(_ title: String, symbol: String, keys: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).frame(height: 22)
                Text(title).font(.system(size: 11.5, weight: .medium))
                Text(keys).font(.system(size: 9.5, weight: .medium)).opacity(0.55)
            }
            .foregroundStyle(on ? Theme.accent : Theme.text)
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(on ? Theme.accent.opacity(0.15) : Theme.fillSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? Theme.accent.opacity(0.55) : Color.clear, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Scene

    private var currentScene: Profile? { model.profiles.first { $0.id == model.appliedProfileID } }

    private var sceneRow: some View {
        Menu {
            ForEach(model.profiles) { profile in
                Button {
                    model.chooseProfile(profile.id)
                } label: {
                    if profile.id == model.appliedProfileID { Label("\(profile.name)  \(profile.snapshot.highlightStyle.displayName)", systemImage: "checkmark") }
                    else { Text("\(profile.name)  \(profile.snapshot.highlightStyle.displayName)") }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("Scene").font(.system(size: 12)).foregroundStyle(Theme.dim)
                Spacer()
                Text(currentScene.map { "\($0.name)  ·  \($0.snapshot.highlightStyle.displayName)" } ?? "None")
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.fillSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
        .accessibilityLabel("Scene")
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            PopoverLink(title: "Settings", symbol: "gearshape") { model.openSettings(.highlight) }
            Spacer()
            PopoverLink(title: "Quit", symbol: "power") { model.quit() }
        }
        .padding(.top, 2)
    }
}

private struct PopoverLink: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11.5, weight: .semibold))
                Text(title).font(.system(size: 12.5))
            }
            .foregroundStyle(hovering ? Theme.text : Theme.dim)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(hovering ? Theme.fillMid : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
