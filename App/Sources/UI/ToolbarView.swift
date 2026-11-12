import AppKit
import BeaconCore
import SwiftUI

/// The floating bar: the three effects and pause, a few quick choices for the one in use, the scene, and a handle.
/// Compact on purpose; it can shrink to a handle and one button.
struct ToolbarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let bar = model.settings.toolbar
        HStack(spacing: 6) {
            DragGrip()
                .frame(width: 14, height: 30)
                .overlay(grip)
                .help("Drag to move the bar")
            if bar.collapsed {
                ToolButton(symbol: "viewfinder.circle", label: "Highlight", on: model.isOn(.highlight)) { model.toggle(.highlight) }
                IconButton(symbol: "chevron.right", label: "Show the whole bar") { model.setToolbar { $0.collapsed = false } }
            } else {
                ToolButton(symbol: "viewfinder.circle", label: "Highlight", on: model.isOn(.highlight)) { model.toggle(.highlight) }
                ToolButton(symbol: "cursorarrow.rays", label: "Laser", on: model.isOn(.laser)) { model.toggle(.laser) }
                ToolButton(symbol: "pencil.tip", label: "Draw", on: model.isOn(.ink)) { model.toggle(.ink) }
                ToolButton(symbol: model.isPaused ? "play.fill" : "pause.fill", label: model.isPaused ? "Resume" : "Pause", on: model.isPaused) {
                    model.setPaused(!model.isPaused)
                }
                separator
                if model.isOn(.ink) { inkControls } else { highlightControls }
                separator
                SceneMenu(selection: model.appliedProfileID, allowsOff: false) { id in if let id { model.chooseProfile(id) } }
                    .tint(Color.white.opacity(0.85))
                IconButton(symbol: "chevron.left", label: "Shrink the bar") { model.setToolbar { $0.collapsed = true } }
                IconButton(symbol: "xmark", label: "Hide the bar. Bring it back with the shortcut or in Screens.") { model.setToolbar { $0.enabled = false } }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color(red: 0.085, green: 0.085, blue: 0.095), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.13), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        .padding(14)
        .fixedSize()
        .environment(\.colorScheme, .dark)
        .animation(.easeOut(duration: 0.15), value: bar.collapsed)
    }

    private var grip: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) { Circle().frame(width: 2.5, height: 2.5); Circle().frame(width: 2.5, height: 2.5) }
            }
        }
        .foregroundStyle(Color.white.opacity(0.3)).allowsHitTesting(false)
    }

    private var separator: some View {
        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 20).padding(.horizontal, 2)
    }

    private var highlightControls: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(HighlightStyle.allCases, id: \.self) { style in
                    Button {
                        model.setStyle(style)
                    } label: {
                        Label {
                            Text(style == model.settings.highlightStyle ? "\(style.displayName)  \u{2713}" : style.displayName)
                        } icon: {
                            Image(nsImage: MenuThumbnail.style(style, tint: model.settings.look.resolvedAccent.map { Color(rgba: $0) }))
                        }
                    }
                }
            } label: {
                Text(model.settings.highlightStyle.displayName).font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderlessButton).fixedSize().tint(Color.white.opacity(0.85)).help("Highlight style")
            HStack(spacing: 1) {
                ForEach(AccentChoice.allCases.filter { $0 != .custom }, id: \.self) { accent in
                    Dot(
                        fill: accent == .styleDefault ? Color(rgba: Palette.accent(for: model.settings.highlightStyle)) : Color(rgba: accent.color ?? Palette.accent(for: model.settings.highlightStyle)),
                        selected: model.settings.accent == accent, auto: accent == .styleDefault,
                        label: accent == .styleDefault ? "Match the style" : accent.displayName
                    ) { model.setAccent(accent) }
                }
                if model.settings.accent == .custom {
                    Dot(fill: Color(rgba: RGBA(hex: model.settings.highlightOptions.customAccent)), selected: true, auto: false, label: "Custom color") {}
                }
            }
        }
    }

    private var inkControls: some View {
        HStack(spacing: 6) {
            HStack(spacing: 1) {
                if let custom = model.settings.inkCustom {
                    Dot(fill: Color(rgba: RGBA(hex: custom)), selected: true, auto: false, label: "Custom color") {}
                }
                ForEach(Array(InkColor.allCases.enumerated()), id: \.element) { index, color in
                    Dot(fill: Color(rgba: color.rgba), selected: model.settings.inkColor == color && model.settings.inkCustom == nil, auto: false, label: "\(color.displayName), key \(index + 1)") {
                        model.setInkColor(color)
                    }
                }
            }
            IconButton(symbol: "arrow.uturn.backward", label: "Undo") { model.undoInk() }
            IconButton(symbol: "trash", label: "Clear drawings") { model.clearInk() }
        }
    }
}

/// A round tool button that turns Ember while its effect is on.
private struct ToolButton: View {
    let symbol: String
    let label: String
    let on: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(on ? Color.white : Color.white.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(Circle().fill(on ? Theme.accent : Color.white.opacity(hovered ? 0.12 : 0.0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A small icon-only button for secondary actions.
private struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(hovered ? 0.95 : 0.6))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(hovered ? 0.1 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// A color dot for the quick choices.
private struct Dot: View {
    let fill: Color
    let selected: Bool
    let auto: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle().fill(fill).frame(width: 15, height: 15)
                .overlay { if auto { Circle().inset(by: 3).stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1, dash: [2, 2])) } }
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                .padding(3)
                .overlay(Circle().stroke(selected ? Color.white : .clear, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Small rendered pictures of a style, for menus: a menu item can only show an image, not a live view.
@MainActor
enum MenuThumbnail {
    private static var cache: [String: NSImage] = [:]

    static func style(_ style: HighlightStyle, tint: Color?) -> NSImage {
        let components = tint.flatMap { NSColor($0).usingColorSpace(.sRGB) }.map { String(format: "%.3f-%.3f-%.3f", $0.redComponent, $0.greenComponent, $0.blueComponent) } ?? "auto"
        let key = "\(style.rawValue)-\(components)"
        if let hit = cache[key] { return hit }
        let view = StyleThumbnail(style: style, color: tint, scale: 0.5)
            .frame(width: 46, height: 30)
            .background(Theme.stage)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 46, height: 30))
        cache[key] = image
        return image
    }
}
