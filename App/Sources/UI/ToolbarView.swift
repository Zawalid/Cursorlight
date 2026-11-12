import AppKit
import BeaconCore
import SwiftUI

/// The floating bar: the three effects and pause, a few quick choices for the one in use, the scene, and a handle.
/// Compact on purpose; it can shrink to a handle and one button.
struct ToolbarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var hovered: String?

    var body: some View {
        let bar = model.settings.toolbar
        HStack(spacing: 6) {
            DragGrip()
                .frame(width: 14, height: 30)
                .overlay(grip)
                .barTip("grip", $hovered)
            if bar.collapsed {
                ToolButton(symbol: "viewfinder.circle", label: "Highlight", on: model.isOn(.highlight)) { model.toggle(.highlight) }.barTip("highlight", $hovered)
                IconButton(symbol: "chevron.right", label: "Show the whole bar") { model.setToolbar { $0.collapsed = false } }.barTip("expand", $hovered)
            } else {
                ToolButton(symbol: "viewfinder.circle", label: "Highlight", on: model.isOn(.highlight)) { model.toggle(.highlight) }.barTip("highlight", $hovered)
                ToolButton(symbol: "cursorarrow.rays", label: "Laser", on: model.isOn(.laser)) { model.toggle(.laser) }.barTip("laser", $hovered)
                ToolButton(symbol: "pencil.tip", label: "Draw", on: model.isOn(.ink)) { model.toggle(.ink) }.barTip("ink", $hovered)
                ToolButton(symbol: model.isPaused ? "play.fill" : "pause.fill", label: model.isPaused ? "Resume" : "Pause", on: model.isPaused) {
                    model.setPaused(!model.isPaused)
                }
                .barTip("pause", $hovered)
                separator
                if model.isOn(.ink) { inkControls } else { highlightControls }
                separator
                SceneMenu(selection: model.appliedProfileID, allowsOff: false) { id in if let id { model.chooseProfile(id) } }
                    .tint(Color.white.opacity(0.85)).barTip("scene", $hovered)
                IconButton(symbol: "chevron.left", label: "Shrink the bar") { model.setToolbar { $0.collapsed = true } }.barTip("collapse", $hovered)
                IconButton(symbol: "xmark", label: "Hide the bar") { model.setToolbar { $0.enabled = false } }.barTip("close", $hovered)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color(red: 0.085, green: 0.085, blue: 0.095), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.13), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        .overlayPreferenceValue(TipAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let id = hovered, let anchor = anchors[id] {
                    let target = proxy[anchor]
                    let width: CGFloat = 220
                    let left = min(max(target.midX - width / 2, 0), max(proxy.size.width - width, 0))
                    TipChip(tip: BarTips.tip(for: id, model: model))
                        .frame(width: width, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .alignmentGuide(.top) { $0[.bottom] }
                        .offset(x: left, y: -10)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.1), value: hovered)
        }
        .padding(.top, 64)
        .padding(.horizontal, 14).padding(.bottom, 14)
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
            .menuStyle(.borderlessButton).fixedSize().tint(Color.white.opacity(0.85)).barTip("style", $hovered)
            HStack(spacing: 1) {
                ForEach(AccentChoice.allCases.filter { $0 != .custom }, id: \.self) { accent in
                    Dot(
                        fill: accent == .styleDefault ? Color(rgba: Palette.accent(for: model.settings.highlightStyle)) : Color(rgba: accent.color ?? Palette.accent(for: model.settings.highlightStyle)),
                        selected: model.settings.accent == accent, auto: accent == .styleDefault,
                        label: accent == .styleDefault ? "Match the style" : accent.displayName
                    ) { model.setAccent(accent) }
                }
                .barTip("color", $hovered)
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
            .barTip("inkColor", $hovered)
            IconButton(symbol: "arrow.uturn.backward", label: "Undo") { model.undoInk() }.barTip("undo", $hovered)
            IconButton(symbol: "trash", label: "Clear drawings") { model.clearInk() }.barTip("clear", $hovered)
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

// MARK: Tool chips

private struct TipAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

private extension View {
    /// Marks a control as one that explains itself in a chip above the bar while the pointer is over it.
    func barTip(_ id: String, _ hovered: Binding<String?>) -> some View {
        anchorPreference(key: TipAnchorKey.self, value: .bounds) { [id: $0] }
            .onHover { inside in
                if inside { hovered.wrappedValue = id } else if hovered.wrappedValue == id { hovered.wrappedValue = nil }
            }
    }
}

struct BarTip {
    let title: String
    let detail: String
    var keys: [String] = []
}

private enum BarTips {
    @MainActor
    static func tip(for id: String, model: AppModel) -> BarTip {
        func keys(_ action: HotKeyAction) -> [String] {
            model.settings.triggers.hotkeysEnabled ? TriggersPage.caps(for: model.settings.triggers.hotkey(for: action)).filter { $0 != "Not set" } : []
        }
        switch id {
        case "highlight": return BarTip(title: "Highlight", detail: "A glow that follows your pointer.", keys: keys(.highlight))
        case "laser": return BarTip(title: "Laser", detail: "A bright trail, so viewers can follow fast movement.", keys: keys(.laser))
        case "ink": return BarTip(title: "Draw", detail: "Drag anywhere on screen. Rough shapes straighten.", keys: keys(.ink))
        case "pause": return BarTip(title: model.isPaused ? "Resume" : "Pause", detail: model.isPaused ? "Turns the effects back on." : "Turns every effect off until you resume.", keys: keys(.pause))
        case "style": return BarTip(title: "Highlight style", detail: "Aura, Lens, Comet, Keyline or Sonar.")
        case "color": return BarTip(title: "Highlight color", detail: "Changes the color of the highlight and laser.")
        case "inkColor": return BarTip(title: "Pen color", detail: "Also keys 1 to 8 while drawing.")
        case "undo": return BarTip(title: "Undo", detail: "Removes the last stroke.", keys: ["⌘", "Z"])
        case "clear": return BarTip(title: "Clear drawings", detail: "Fades everything away.", keys: keys(.clearInk))
        case "scene": return BarTip(title: "Scene", detail: "Switch the whole look at once.", keys: keys(.nextScene))
        case "collapse": return BarTip(title: "Shrink", detail: "Keep only the handle and the highlight button.")
        case "expand": return BarTip(title: "Show the whole bar", detail: "Bring back every tool.")
        case "close": return BarTip(title: "Hide the bar", detail: "Bring it back with the shortcut, or in Screens.", keys: keys(.toggleToolbar))
        case "grip": return BarTip(title: "Move", detail: "Drag to put the bar anywhere.")
        default: return BarTip(title: id, detail: "")
        }
    }
}

private struct TipChip: View {
    let tip: BarTip

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(tip.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Spacer(minLength: 4)
                HStack(spacing: 2) { ForEach(tip.keys, id: \.self) { MiniKey(text: $0, pressed: false) } }
            }
            Text(tip.detail).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.62)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color(red: 0.1, green: 0.1, blue: 0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }
}
