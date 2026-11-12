import AppKit
import BeaconCore
import SwiftUI

/// Every page is a native grouped Form, the same structure System Settings uses, so spacing, row heights, controls and
/// light and dark all come from the system.

enum Swatches {
    static func fill(for accent: AccentChoice) -> AnyShapeStyle {
        if let color = accent.color { return AnyShapeStyle(Color(rgba: color)) }
        return AnyShapeStyle(AngularGradient(colors: [.purple, .orange, .red, .blue, .teal, .purple], center: .center))
    }
}

/// A grid of selectable thumbnails, sized for the inspector column.
struct TileRow<Item: Hashable, Thumb: View>: View {
    let items: [Item]
    let selection: Item
    let title: (Item) -> String
    let select: (Item) -> Void
    @ViewBuilder let thumbnail: (Item) -> Thumb

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 12) {
            ForEach(items, id: \.self) { item in
                let on = item == selection
                Button { select(item) } label: {
                    VStack(spacing: 6) {
                        thumbnail(item)
                            .frame(height: 50).frame(maxWidth: .infinity)
                            .background(Theme.stage, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(on ? Theme.accent : Color.clear, lineWidth: 2.5))
                        Text(title(item)).font(.system(size: 11, weight: on ? .semibold : .regular)).foregroundStyle(on ? Theme.text : Theme.dim)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private extension View {
    /// A form row that is just content: no inset, no background.
    func bareRow() -> some View {
        self.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
    }

    func page() -> some View {
        self.formStyle(.grouped).scrollContentBackground(.hidden)
    }
}

// MARK: Look

struct LookPage: View {
    @EnvironmentObject private var model: AppModel
    private var settings: BeaconSettings { model.settings }

    var body: some View {
        Form {
            Section {
                StyleRow(selection: settings.highlightStyle, tint: settings.accent.color.map { Color(rgba: $0) }) { model.setStyle($0) }
                Text(Self.blurb(settings.highlightStyle))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Style")
            }
            styleOptions
            Section {
                LabeledContent {
                    HStack(spacing: 0) {
                        ForEach(AccentChoice.allCases, id: \.self) { accent in
                            SwatchButton(
                                fill: accent == .styleDefault ? AnyShapeStyle(Color(rgba: Palette.accent(for: settings.highlightStyle))) : Swatches.fill(for: accent),
                                isSelected: settings.accent == accent,
                                label: accent == .styleDefault ? "Match the style" : accent.displayName,
                                auto: accent == .styleDefault
                            ) { model.setAccent(accent) }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Color")
                        Text(settings.accent == .styleDefault ? "Matches \(settings.highlightStyle.displayName)" : settings.accent.displayName)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Size") {
                    ValueSlider(value: Binding(get: { settings.highlightSize }, set: { model.setSize($0) }), range: HighlightLook.sizeRange)
                }
                if settings.highlightStyle == .lens {
                    LabeledContent("Screen dim") {
                        ValueSlider(value: Binding(get: { settings.lensDim }, set: { model.setLensDim($0) }), range: HighlightLook.dimRange)
                    }
                } else {
                    LabeledContent("Intensity") {
                        ValueSlider(value: Binding(get: { settings.highlightIntensity }, set: { model.setIntensity($0) }), range: HighlightLook.intensityRange)
                            .disabled(settings.accent == .highContrast)
                    }
                }
            } header: {
                Text("Appearance")
            } footer: {
                if let hint = Self.colorHint(settings.accent) { Text(hint) }
            }
            Section {
                Toggle(isOn: Binding(get: { settings.clickRipples }, set: { model.setRipples($0) })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Click ripples")
                        Text("A ring spreads from the pointer on every click.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: Binding(
                    get: { settings.highlightOptions.fadesWhenStill },
                    set: { on in model.setOptions { $0.fadeAfterStill = on ? 3 : 0 } }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Fade when still")
                        Text("Hides the highlight when you stop, and brings it back when you move.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                if settings.highlightOptions.fadesWhenStill {
                    LabeledContent("After") {
                        ValueSlider(
                            value: Binding(get: { settings.highlightOptions.fadeAfterStill }, set: { v in model.setOptions { $0.fadeAfterStill = (v * 2).rounded() / 2 } }),
                            range: HighlightOptions.fadeRange, format: { "\(String(format: "%g", ($0 * 2).rounded() / 2)) s" }
                        )
                    }
                }
                LabeledContent {
                    Picker("Pointer size", selection: Binding(get: { Self.nearest(model.cursorScale) }, set: { model.setCursorScale($0) })) {
                        Text("1x").tag(1.0); Text("1.5x").tag(1.5); Text("2x").tag(2.0); Text("3x").tag(3.0)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 160)
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pointer size")
                        Text("Easier to follow").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Behavior")
            }
            Section {
                Toggle(isOn: Binding(get: { settings.hideRules.fullScreenApps }, set: { v in model.setHideRules { $0.fullScreenApps = v } })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Full-screen apps")
                        Text("Leave off if you present full-screen slides.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: Binding(get: { settings.hideRules.videoPlayers }, set: { v in model.setHideRules { $0.videoPlayers = v } })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Video players")
                        Text("QuickTime, TV, VLC, IINA and similar.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Hide automatically")
            } footer: {
                if let reason = model.hideReason {
                    Text("Hidden right now: \(reason.displayName.lowercased()) in front. For other apps, use the Apps tab.")
                } else {
                    Text("Effects stay out of the way in these cases. For other apps, use the Apps tab.")
                }
            }
            Section {
                Button("Reset look") { resetLook() }
                    .foregroundStyle(isDefault ? Color.secondary : Theme.accent)
                    .disabled(isDefault)
            } footer: {
                Text("Puts color, size, intensity, ripples and the style options back to their defaults. The style itself stays.")
            }
        }
        .page()
    }

    private var isDefault: Bool {
        settings.accent == .styleDefault && settings.highlightSize == 1 && settings.highlightIntensity == 1
            && settings.lensDim == 0.5 && settings.clickRipples && settings.highlightOptions == HighlightOptions()
    }

    private func resetLook() {
        model.setAccent(.styleDefault)
        model.setSize(1)
        model.setIntensity(1)
        model.setLensDim(0.5)
        model.setRipples(true)
        model.setOptions { $0 = HighlightOptions() }
    }

    /// The one or two settings that belong to the chosen style alone.
    @ViewBuilder
    private var styleOptions: some View {
        let options = settings.highlightOptions
        switch settings.highlightStyle {
        case .aura:
            Section("Aura") {
                Toggle(isOn: Binding(get: { options.auraBreathing }, set: { v in model.setOptions { $0.auraBreathing = v } })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Breathe when still")
                        Text("A slow swell while the pointer rests.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
        case .lens:
            Section("Lens") {
                LabeledContent("Soft edge") {
                    ValueSlider(value: Binding(get: { options.lensSoftness }, set: { v in model.setOptions { $0.lensSoftness = v } }), range: HighlightOptions.softnessRange)
                }
            }
        case .comet:
            Section("Comet") {
                LabeledContent("Tail length") {
                    ValueSlider(value: Binding(get: { options.cometTail }, set: { v in model.setOptions { $0.cometTail = v } }), range: HighlightOptions.tailRange)
                }
            }
        case .keyline:
            Section("Keyline") {
                LabeledContent("Ring thickness") {
                    ValueSlider(value: Binding(get: { options.keylineWidth }, set: { v in model.setOptions { $0.keylineWidth = v } }), range: HighlightOptions.lineRange)
                }
            }
        case .sonar:
            Section("Sonar") {
                LabeledContent("Rings") {
                    Picker("Rings", selection: Binding(get: { options.sonarRings }, set: { v in model.setOptions { $0.sonarRings = v } })) {
                        ForEach(Array(HighlightOptions.ringsRange), id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                }
            }
        }
    }

    private static func colorHint(_ accent: AccentChoice) -> String? {
        switch accent {
        case .white: "White can disappear on light backgrounds. High contrast stays visible on both."
        case .highContrast: "High contrast always draws at full strength, so intensity is locked."
        default: nil
        }
    }

    private static func blurb(_ style: HighlightStyle) -> String {
        switch style {
        case .aura: "A soft light that follows you and breathes when you stop."
        case .lens: "Dims the whole screen except a circle around the pointer."
        case .comet: "A bright head with a tail, so viewers can follow fast movement."
        case .keyline: "A thin two-tone ring that stays readable on any background."
        case .sonar: "Rings pulse in and lock onto the pointer, then a small dot stays."
        }
    }

    private static func nearest(_ scale: Double) -> Double {
        [1.0, 1.5, 2.0, 3.0].min { abs($0 - scale) < abs($1 - scale) } ?? 1
    }
}

/// The five highlight styles in one row of square tiles, drawn in the color you picked so each shows what it will look like.
struct StyleRow: View {
    let selection: HighlightStyle
    let tint: Color?
    let select: (HighlightStyle) -> Void
    @State private var hovered: HighlightStyle?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 5), spacing: 8) {
            ForEach(HighlightStyle.allCases, id: \.self) { style in
                let on = style == selection
                let accent = tint ?? Color(rgba: Palette.accent(for: style))
                Button { select(style) } label: {
                    VStack(spacing: 6) {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { StyleThumbnail(style: style, color: tint, scale: 0.7) }
                            .background(Theme.stage, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(on ? accent : Color.white.opacity(hovered == style ? 0.28 : 0.1), lineWidth: on ? 2 : 1)
                            )
                            .shadow(color: on ? accent.opacity(0.35) : .clear, radius: 7)
                        Text(style.displayName)
                            .font(.system(size: 11, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.text : Theme.dim)
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? style : (hovered == style ? nil : hovered) }
                .animation(.easeOut(duration: 0.14), value: hovered)
                .animation(.easeOut(duration: 0.18), value: on)
                .accessibilityLabel(style.displayName)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// A slider with its value written beside it, so "size" and "intensity" mean something.
struct ValueSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $value, in: range).frame(minWidth: 96)
            Text(format(value))
                .font(.system(size: 12).monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }
}

// MARK: Draw

struct InkPage: View {
    @EnvironmentObject private var model: AppModel
    private var settings: BeaconSettings { model.settings }

    var body: some View {
        Form {
            Section("Pen") {
                PenRow(selection: settings.inkStyle, color: settings.inkColor, width: settings.inkWidth) { model.setInkStyle($0) }
                LabeledContent {
                    HStack(spacing: 0) {
                        ForEach(Array(InkColor.allCases.enumerated()), id: \.element) { index, color in
                            VStack(spacing: 0) {
                                SwatchButton(fill: AnyShapeStyle(Color(rgba: color.rgba)), isSelected: settings.inkColor == color, label: "\(color.displayName), key \(index + 1)") {
                                    model.setInkColor(color)
                                }
                                Text("\(index + 1)").font(.system(size: 9, weight: .medium).monospacedDigit()).foregroundStyle(.tertiary)
                            }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Color")
                        Text("\(settings.inkColor.displayName). Press 1 to 5 while drawing.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Thickness") {
                    ValueSlider(value: Binding(get: { settings.inkWidth }, set: { model.setInkWidth($0) }), range: BeaconSettings.inkWidthRange)
                }
            }
            Section {
                Toggle(isOn: Binding(get: { settings.inkCleanup }, set: { model.setInkCleanup($0) })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Clean up shapes")
                        Text("Circles, boxes, lines, underlines and arrows straighten when you let go.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Fade after") {
                    ValueSlider(
                        value: Binding(get: { settings.inkFadeAfter }, set: { model.setInkFade(($0 * 10).rounded() / 10) }),
                        range: BeaconSettings.inkFadeRange, format: { String(format: "%.1f s", $0) }
                    )
                }
            } header: {
                Text("Behavior")
            }
            Section {
                ForEach(Self.drawingKeys, id: \.0) { meaning, keys in
                    LabeledContent(meaning) {
                        HStack(spacing: 3) { ForEach(keys, id: \.self) { Keycap(text: $0) } }
                    }
                }
            } header: {
                Text("While drawing")
            } footer: {
                Text("Hold the draw key, or start below, then drag anywhere on screen.")
            }
            Section {
                LabeledContent("Draw now") {
                    Button(model.isOn(.ink) ? "Stop" : "Start") { model.toggle(.ink) }
                }
                Button("Reset pen") { resetPen() }
                    .foregroundStyle(isDefault ? Color.secondary : Theme.accent)
                    .disabled(isDefault)
            }
        }
        .page()
    }

    private static let drawingKeys: [(String, [String])] = [
        ("Undo", ["⌘", "Z"]), ("Clear everything", ["C"]), ("Change color", ["1", "–", "5"]), ("Stop drawing", ["esc"]),
    ]

    private var isDefault: Bool {
        settings.inkStyle == .marker && settings.inkColor == .red && settings.inkWidth == 1 && settings.inkCleanup && settings.inkFadeAfter == 2
    }

    private func resetPen() {
        model.setInkStyle(.marker)
        model.setInkColor(.red)
        model.setInkWidth(1)
        model.setInkCleanup(true)
        model.setInkFade(2)
    }
}

/// The pen styles in one row of tiles, each drawing a stroke in the chosen color and thickness.
struct PenRow: View {
    let selection: InkStyle
    let color: InkColor
    let width: Double
    let select: (InkStyle) -> Void
    @State private var hovered: InkStyle?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 10) {
            ForEach(InkStyle.allCases, id: \.self) { style in
                let on = style == selection
                let tint = Color(rgba: color.rgba)
                Button { select(style) } label: {
                    VStack(spacing: 6) {
                        InkSwatchStroke(style: style, color: color, width: width)
                            .padding(.horizontal, 6)
                            .frame(height: 52).frame(maxWidth: .infinity)
                            .background(Theme.stage, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(on ? tint : Color.white.opacity(hovered == style ? 0.28 : 0.1), lineWidth: on ? 2 : 1)
                            )
                            .shadow(color: on ? tint.opacity(0.35) : .clear, radius: 7)
                        Text(style.displayName)
                            .font(.system(size: 11, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.text : Theme.dim)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? style : (hovered == style ? nil : hovered) }
                .animation(.easeOut(duration: 0.14), value: hovered)
                .accessibilityLabel(style.displayName)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: Keys

struct TriggersPage: View {
    @EnvironmentObject private var model: AppModel
    private var triggers: TriggerSettings { model.settings.triggers }

    var body: some View {
        Form {
            Section {
                Toggle("Shake the pointer", isOn: Binding(get: { triggers.shakeEnabled }, set: { v in model.updateTriggers { $0.shakeEnabled = v } }))
                effectPicker("Does", Binding(get: { triggers.shakeAction }, set: { v in model.updateTriggers { $0.shakeAction = v } }))
                    .disabled(!triggers.shakeEnabled)
                LabeledContent("Sensitivity") {
                    Slider(value: Binding(get: { model.settings.shakeSensitivity }, set: { model.setShakeSensitivity($0) }), in: 0...100).frame(minWidth: 110)
                }
                .disabled(!triggers.shakeEnabled)
            } header: { Text("Shake") }
            Section {
                Toggle("Double-tap a key", isOn: Binding(get: { triggers.doubleTapEnabled }, set: { v in model.updateTriggers { $0.doubleTapEnabled = v } }))
                keyPicker("Key", Binding(get: { triggers.doubleTapKey }, set: { v in model.updateTriggers { $0.doubleTapKey = v } })).disabled(!triggers.doubleTapEnabled)
                effectPicker("Does", Binding(get: { triggers.doubleTapAction }, set: { v in model.updateTriggers { $0.doubleTapAction = v } })).disabled(!triggers.doubleTapEnabled)
            } header: { Text("Double-tap") }
            Section {
                Toggle("Hold a key", isOn: Binding(get: { triggers.holdEnabled }, set: { v in model.updateTriggers { $0.holdEnabled = v } }))
                keyPicker("Key", Binding(get: { triggers.holdKey }, set: { v in model.updateTriggers { $0.holdKey = v } })).disabled(!triggers.holdEnabled)
                effectPicker("Does", Binding(get: { triggers.holdAction }, set: { v in model.updateTriggers { $0.holdAction = v } })).disabled(!triggers.holdEnabled)
            } header: { Text("Hold") } footer: {
                Text(model.needsInputMonitoring
                     ? "Double-tap and hold need Input Monitoring to see the key while another app is in front."
                     : "Double-tap and hold work in every app.")
            }
            if model.needsInputMonitoring {
                Section {
                    Button("Allow Input Monitoring…") { model.requestInputMonitoring() }
                }
            }
            Section {
                Toggle("Keyboard shortcuts", isOn: Binding(get: { triggers.hotkeysEnabled }, set: { v in model.updateTriggers { $0.hotkeysEnabled = v } }))
                ForEach(HotKeyAction.allCases, id: \.self) { action in
                    LabeledContent(action.displayName) {
                        HStack(spacing: 3) {
                            ForEach(Self.caps(for: triggers.hotkey(for: action)), id: \.self) { Keycap(text: $0) }
                        }
                    }
                    .opacity(triggers.hotkeysEnabled ? 1 : 0.5)
                }
            } header: { Text("Shortcuts") } footer: {
                Text(model.failedHotkeys.isEmpty ? "Shortcuts work in every app and need no permission." : "Taken by another app: \(model.failedHotkeys.map(\.displayName).joined(separator: ", ")).")
            }
        }
        .page()
        .onAppear { model.refreshInputMonitoring() }
    }

    private func effectPicker(_ title: String, _ selection: Binding<EffectKind>) -> some View {
        Picker(title, selection: selection) { ForEach(EffectKind.allCases, id: \.self) { Text($0.displayName).tag($0) } }
    }

    private func keyPicker(_ title: String, _ selection: Binding<ModifierKey>) -> some View {
        Picker(title, selection: selection) { ForEach(ModifierKey.allCases, id: \.self) { Text($0.displayName).tag($0) } }
    }

    static func caps(for key: HotKey?) -> [String] {
        guard let key else { return ["Not set"] }
        var caps: [String] = []
        var rest = Substring(key.displayString)
        while let first = rest.first, "⌃⌥⇧⌘".contains(first) {
            caps.append(String(first))
            rest = rest.dropFirst()
        }
        if !rest.isEmpty { caps.append(String(rest)) }
        return caps
    }
}

// MARK: Apps

struct ProfilesPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(model.settings.appRules) { rule in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rule.appName).font(.system(size: 13, weight: .medium))
                        HStack {
                            Picker("", selection: Binding(get: { rule.profileID ?? "" }, set: { model.setRule(rule, profileID: $0.isEmpty ? nil : $0) })) {
                                ForEach(model.profiles) { Text($0.name).tag($0.id) }
                                Divider()
                                Text("Beacon off").tag("")
                            }
                            .labelsHidden()
                            Button { model.removeRule(rule) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).help("Remove this rule")
                        }
                    }
                }
                Button("Add App…") { model.addRuleFromPanel() }
            } header: {
                Text("App Rules")
            } footer: {
                Text("When one of these apps is in front, Beacon switches scene or turns off. A scene you pick by hand wins until you switch to another app.")
            }
        }
        .page()
    }
}

// MARK: Screens

struct DisplaysPage: View {
    @EnvironmentObject private var model: AppModel
    private var screens: [NSScreen] { NSScreen.screens }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .bottom, spacing: 14) {
                    Spacer()
                    ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                        let aspect = screen.frame.height / max(screen.frame.width, 1)
                        let shown = model.displayScope == .all || index == 0
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.stage)
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(shown ? Theme.accent : Theme.line, lineWidth: 2))
                                .frame(width: 110, height: 110 * aspect)
                            Text(index == 0 ? "\(screen.localizedName) (main)" : screen.localizedName)
                                .font(.system(size: 11)).foregroundStyle(Theme.dim)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                Picker("Show effects on", selection: Binding(get: { model.displayScope }, set: { model.setDisplayScope($0) })) {
                    ForEach(DisplayScope.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Displays")
            } footer: {
                Text("The main display is the one with the menu bar.")
            }
            Section {
                let info = ShareStatusInfo(model.shareStatus)
                Label { Text(info.title) } icon: { Image(systemName: info.symbol).foregroundStyle(info.tint) }
                Text(info.body).foregroundStyle(Theme.dim)
                Picker("I am sharing", selection: Binding(get: { model.declaredShare }, set: { model.declareShare($0) })) {
                    Text("Not set").tag(DeclaredShare?.none)
                    Text("Nothing").tag(DeclaredShare?.some(.notSharing))
                    Text("The whole screen").tag(DeclaredShare?.some(.wholeScreen))
                    Text("One window").tag(DeclaredShare?.some(.singleWindow))
                }
            } header: {
                Text("Sharing")
            } footer: {
                Text("Beacon cannot tell what you share, so it asks. Viewers only see effects when you share the whole screen.")
            }
        }
        .page()
    }
}

// MARK: About

struct AboutPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { LaunchAtLogin.set($0); launchAtLogin = LaunchAtLogin.isEnabled }))
                    .disabled(!LaunchAtLogin.isAvailable)
            } header: {
                Text(Branding.appName)
            }
            Section {
                Toggle("Check for updates automatically", isOn: Binding(get: { model.automaticUpdateChecks }, set: { model.setAutomaticUpdateChecks($0) }))
                    .disabled(!model.updatesConfigured)
                Button("Check Now") { model.checkForUpdates() }
            } header: {
                Text("Updates")
            } footer: {
                Text(model.updatesConfigured ? "Asks GitHub once a day. Nothing installs without your OK." : "This build has no update signing key yet.")
            }
            Section {
                Button("Show Welcome Guide") { model.openWelcome() }
            } footer: {
                Text("No accounts and no analytics. The network is used only for update checks, once they exist.")
            }
        }
        .page()
    }
}
