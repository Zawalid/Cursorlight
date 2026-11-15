import CursorlightCore
import SwiftUI

/// The menu bar popover: everything you reach for mid-call, in one glance. A master switch, the tools, the scene, a quick look
/// (color and size), the extras (keys, clicks, bar, timer, board), and a share warning only when it matters.
struct PopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            tools
            group("Scene") { scenes }
            group("Look") { look }
            group("Also") { extras }
            if model.shareStatus.needsAttention || !model.conferencingApps.isEmpty {
                ShareStatusCard()
            }
            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.dim)
            content()
        }
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
            BrandMark().frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(Branding.appName).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
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
                Text(title).font(.system(size: 11.5, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
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

    private var scenes: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.profiles) { profile in
                    let active = profile.id == model.appliedProfileID
                    Button { model.chooseProfile(profile.id) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                            Text(profile.snapshot.highlightStyle.displayName).font(.system(size: 10.5)).foregroundStyle(Theme.dim).lineLimit(1)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(minWidth: 88, alignment: .leading)
                        .background(active ? Theme.accent.opacity(0.14) : Theme.fillSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(active ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: Look

    private static let swatches: [AccentChoice] = [.styleDefault, .coral, .iris, .amber, .blue, .teal, .white]

    private var look: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                ForEach(Self.swatches, id: \.self) { choice in swatch(choice) }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Image(systemName: "circle").font(.system(size: 8)).foregroundStyle(Theme.faint)
                Slider(value: Binding(get: { model.settings.highlightSize }, set: { model.setSize($0) }), in: HighlightLook.sizeRange)
                    .controlSize(.small).tint(Theme.accent)
                Image(systemName: "circle").font(.system(size: 15)).foregroundStyle(Theme.faint)
                Text(String(format: "%.1f×", model.settings.highlightSize))
                    .font(.system(size: 11.5, weight: .medium)).monospacedDigit().foregroundStyle(Theme.dim).frame(width: 32, alignment: .trailing)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Highlight size")
        }
        .padding(12)
        .background(Theme.fillSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func swatch(_ choice: AccentChoice) -> some View {
        let selected = model.settings.accent == choice
        return Button { model.setAccent(choice) } label: {
            ZStack {
                if let rgba = choice.color {
                    Circle().fill(Color(rgba: rgba))
                } else {
                    Circle().fill(AngularGradient(colors: [Theme.accent, .purple, .blue, Theme.accent], center: .center))
                        .overlay(Image(systemName: "sparkles").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
                }
            }
            .frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.22), lineWidth: 0.5))
            .padding(3)
            .overlay(Circle().strokeBorder(selected ? Theme.text : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .help(choice == .styleDefault ? "The style's own color" : choice.displayName)
        .accessibilityLabel(choice.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Extras

    private var extras: some View {
        HStack(spacing: 8) {
            chip("Keys", symbol: "keyboard", on: model.settings.keystrokes.enabled) { model.setKeystrokes { $0.enabled.toggle() } }
            chip("Clicks", symbol: "cursorarrow.click.2", on: model.settings.clickRipples) { model.setRipples(!model.settings.clickRipples) }
            chip("Bar", symbol: "dock.rectangle", on: model.settings.toolbar.enabled) { model.setToolbar { $0.enabled.toggle() } }
            chip("Timer", symbol: "timer", on: false) { model.toggleTimer() }
            chip("Board", symbol: "rectangle.and.pencil.and.ellipsis", on: model.isOn(.ink) && model.inkBoard != .none) { model.toggleWhiteboard(.white) }
        }
    }

    private func chip(_ title: String, symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).frame(height: 16)
                Text(title).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(on ? Theme.accent : Theme.dim)
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(on ? Theme.accent.opacity(0.14) : Theme.fillSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            PopoverLink(title: "Settings", symbol: "gearshape") { model.openSettings(.highlight) }
            Spacer()
            PopoverLink(title: "Quit", symbol: "power") { model.quit() }
        }
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
