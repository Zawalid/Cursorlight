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
                StyleRow(selection: settings.highlightStyle, tint: settings.look.resolvedAccent.map { Color(rgba: $0) }) { model.setStyle($0) }
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
                        ForEach(AccentChoice.allCases.filter { $0 != .custom }, id: \.self) { accent in
                            SwatchButton(
                                fill: accent == .styleDefault ? AnyShapeStyle(Color(rgba: Palette.accent(for: settings.highlightStyle))) : Swatches.fill(for: accent),
                                isSelected: settings.accent == accent,
                                label: accent == .styleDefault ? "Match the style" : accent.displayName,
                                auto: accent == .styleDefault
                            ) { model.setAccent(accent) }
                        }
                        CustomSwatch(hex: settings.highlightOptions.customAccent, selected: settings.accent == .custom) { hex in
                            model.setOptions { $0.customAccent = hex }
                            if settings.accent != .custom { model.setAccent(.custom) }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Color")
                        Text(settings.accent == .styleDefault ? "Matches \(settings.highlightStyle.displayName)" : (settings.accent == .custom ? settings.highlightOptions.customAccent.uppercased() : settings.accent.displayName))
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
    var valueWidth: CGFloat = 42

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $value, in: range).frame(minWidth: 96)
            Text(format(value))
                .font(.system(size: 12).monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: valueWidth, alignment: .trailing)
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
                PenRow(selection: settings.inkStyle, rgba: settings.penColor, width: settings.inkWidth) { model.setInkStyle($0) }
                LabeledContent {
                    HStack(spacing: 0) {
                        ForEach(Array(InkColor.allCases.enumerated()), id: \.element) { index, color in
                            VStack(spacing: 0) {
                                SwatchButton(fill: AnyShapeStyle(Color(rgba: color.rgba)), isSelected: settings.inkColor == color && settings.inkCustom == nil, label: "\(color.displayName), key \(index + 1)") {
                                    model.setInkColor(color)
                                }
                                Text("\(index + 1)").font(.system(size: 9, weight: .medium).monospacedDigit()).foregroundStyle(.tertiary)
                            }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Color")
                        Text(settings.inkCustom?.uppercased() ?? settings.inkColor.displayName).font(.system(size: 11)).foregroundStyle(.secondary)
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
                        Text("Rough shapes straighten when you let go.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                if settings.inkCleanup {
                    ShapeTiles(shapes: settings.inkShapes, rgba: settings.penColor) { model.setInkShapes($0) }
                }
                Toggle(isOn: Binding(get: { settings.inkFades }, set: { model.setInkFades($0) })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Fade out")
                        Text(settings.inkFades ? "Strokes disappear on their own." : "Strokes stay until you clear them with C.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                if settings.inkFades {
                    LabeledContent("Fade after") {
                        ValueSlider(
                            value: Binding(get: { settings.inkFadeAfter }, set: { model.setInkFade(($0 * 10).rounded() / 10) }),
                            range: BeaconSettings.inkFadeRange, format: { String(format: "%.1f s", $0) }
                        )
                    }
                }
            } header: {
                Text("Behavior")
            }
            Section {
                DrawingKeys(selected: settings.inkCustom == nil ? settings.inkColor : nil) { model.setInkColor($0) }
                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
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

    private var isDefault: Bool {
        settings.inkStyle == .marker && settings.inkColor == .red && settings.inkCustom == nil && settings.inkWidth == 1 && settings.inkCleanup
            && settings.inkFadeAfter == 2 && settings.inkShapes == .all && settings.inkFades
    }

    private func resetPen() {
        model.setInkStyle(.marker)
        model.setInkColor(.red)
        model.setInkWidth(1)
        model.setInkCleanup(true)
        model.setInkFade(2)
        model.setInkShapes(.all)
        model.setInkFades(true)
    }
}

/// Which shapes cleanup may snap to: one tile per shape, drawn in the pen color. A tile that is on has a ring; one that is
/// off is dimmed.
struct ShapeTiles: View {
    let shapes: InkShapeSet
    let rgba: RGBA
    let change: (InkShapeSet) -> Void
    @State private var hovered: Int?

    private static let items: [(InkShapeSet, String)] = [
        (.ellipse, "Circle"), (.rectangle, "Box"), (.triangle, "Triangle"), (.diamond, "Diamond"),
        (.line, "Line"), (.underline, "Underline"), (.arrow, "Arrow"),
    ]

    var body: some View {
        let tint = Color(rgba: rgba)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4), spacing: 10) {
            ForEach(Self.items, id: \.0.rawValue) { shape, title in
                let on = shapes.contains(shape)
                Button {
                    var next = shapes
                    if on { next.remove(shape) } else { next.insert(shape) }
                    change(next)
                } label: {
                    VStack(spacing: 5) {
                        ShapeGlyph(shape: shape)
                            .stroke(on ? tint : Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .padding(13)
                            .frame(maxWidth: .infinity).aspectRatio(1.15, contentMode: .fit)
                            .background(Theme.stage, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(on ? tint.opacity(0.9) : Color.white.opacity(hovered == shape.rawValue ? 0.25 : 0.09), lineWidth: on ? 1.5 : 1)
                            )
                            .shadow(color: on ? tint.opacity(0.28) : .clear, radius: 6)
                        Text(title)
                            .font(.system(size: 10.5, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.text : Theme.faint)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? shape.rawValue : (hovered == shape.rawValue ? nil : hovered) }
                .animation(.easeOut(duration: 0.14), value: on)
                .accessibilityLabel(title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
    }
}

/// The outline of one shape, drawn to fill its rectangle.
struct ShapeGlyph: Shape {
    let shape: InkShapeSet

    func path(in r: CGRect) -> Path {
        var p = Path()
        switch shape {
        case .ellipse:
            p.addEllipse(in: r)
        case .rectangle:
            p.addRoundedRect(in: r.insetBy(dx: 0, dy: r.height * 0.1), cornerSize: CGSize(width: 2, height: 2))
        case .triangle:
            p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
        case .diamond:
            p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.midY)); p.closeSubpath()
        case .line:
            p.move(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        case .underline:
            p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        default:
            p.move(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.move(to: CGPoint(x: r.maxX - r.width * 0.34, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.34))
        }
        return p
    }
}

/// The keys that work while drawing, as keycaps with a caption, and the eight color keys in their own colors.
struct DrawingKeys: View {
    let selected: InkColor?
    let select: (InkColor) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                card("Undo", ["⌘", "Z"])
                card("Clear all", ["C"])
                card("Stop", ["esc"])
            }
            ColorKeys(selected: selected, select: select)
        }
    }

    private func card(_ title: String, _ keys: [String]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) { ForEach(keys, id: \.self) { Keycap(text: $0) } }
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// The pen styles in one row of tiles, each drawing a stroke in the chosen color and thickness.
struct PenRow: View {
    let selection: InkStyle
    let rgba: RGBA
    let width: Double
    let select: (InkStyle) -> Void
    @State private var hovered: InkStyle?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 5), spacing: 8) {
            ForEach(InkStyle.allCases, id: \.self) { style in
                let on = style == selection
                let tint = Color(rgba: rgba)
                Button { select(style) } label: {
                    VStack(spacing: 6) {
                        InkSwatchStroke(style: style, rgba: rgba, width: width * 0.55)
                            .padding(.horizontal, 5)
                            .frame(height: 50).frame(maxWidth: .infinity)
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
                            .lineLimit(1).minimumScaleFactor(0.75)
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
            if model.needsInputMonitoring {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill").font(.system(size: 16)).foregroundStyle(Theme.warn)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Double-tap and hold need Input Monitoring").font(.system(size: 13, weight: .semibold))
                            Text("Without it, Beacon sees those keys only while its own window is in front.")
                                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            Button("Allow Input Monitoring…") { model.requestInputMonitoring() }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                Toggle(isOn: Binding(get: { triggers.shakeEnabled }, set: { v in model.updateTriggers { $0.shakeEnabled = v } })) {
                    caption("Shake the pointer", "Wiggle the mouse to summon an effect.")
                }
                effectPicker("Does", Binding(get: { triggers.shakeAction }, set: { v in model.updateTriggers { $0.shakeAction = v } }))
                    .disabled(!triggers.shakeEnabled)
                LabeledContent("Sensitivity") {
                    ValueSlider(
                        value: Binding(get: { model.settings.shakeSensitivity / 100 }, set: { model.setShakeSensitivity($0 * 100) }),
                        range: 0...1, format: { $0 < 0.34 ? "Hard" : ($0 > 0.66 ? "Easy" : "Medium") }, valueWidth: 60
                    )
                }
                .disabled(!triggers.shakeEnabled)
            } header: { Text("Shake") }
            Section {
                Toggle(isOn: Binding(get: { triggers.doubleTapEnabled }, set: { v in model.updateTriggers { $0.doubleTapEnabled = v } })) {
                    caption("Double-tap a key", "Tap a modifier key twice, quickly.")
                }
                keyPicker("Key", Binding(get: { triggers.doubleTapKey }, set: { v in model.updateTriggers { $0.doubleTapKey = v } })).disabled(!triggers.doubleTapEnabled)
                effectPicker("Does", Binding(get: { triggers.doubleTapAction }, set: { v in model.updateTriggers { $0.doubleTapAction = v } })).disabled(!triggers.doubleTapEnabled)
            } header: { Text("Double-tap") }
            Section {
                Toggle(isOn: Binding(get: { triggers.holdEnabled }, set: { v in model.updateTriggers { $0.holdEnabled = v } })) {
                    caption("Hold a key", "Hold to use the effect, release to stop.")
                }
                keyPicker("Key", Binding(get: { triggers.holdKey }, set: { v in model.updateTriggers { $0.holdKey = v } })).disabled(!triggers.holdEnabled)
                effectPicker("Does", Binding(get: { triggers.holdAction }, set: { v in model.updateTriggers { $0.holdAction = v } })).disabled(!triggers.holdEnabled)
            } header: { Text("Hold") } footer: {
                if triggers.doubleTapEnabled, triggers.holdEnabled, triggers.doubleTapKey == triggers.holdKey {
                    Text("Double-tap and hold use the same key, so they will get in each other's way.").foregroundStyle(Theme.warn)
                }
            }
            Section {
                Toggle(isOn: Binding(get: { triggers.hotkeysEnabled }, set: { v in model.updateTriggers { $0.hotkeysEnabled = v } })) {
                    caption("Keyboard shortcuts", "Work in every app and need no permission.")
                }
                ForEach(HotKeyAction.allCases, id: \.self) { action in
                    ShortcutRecorder(action: action).opacity(triggers.hotkeysEnabled ? 1 : 0.5).disabled(!triggers.hotkeysEnabled)
                }
            } header: { Text("Shortcuts") } footer: {
                if model.failedHotkeys.isEmpty {
                    Text("Click a shortcut, then press the new keys. Esc cancels, Delete clears it.")
                } else {
                    Text("Taken by another app: \(model.failedHotkeys.map(\.displayName).joined(separator: ", ")).")
                }
            }
            Section {
                Button("Restore defaults") { model.updateTriggers { $0 = TriggerSettings() } }
                    .foregroundStyle(triggers == TriggerSettings() ? Color.secondary : Theme.accent)
                    .disabled(triggers == TriggerSettings())
            }
        }
        .page()
        .onAppear { model.refreshInputMonitoring() }
    }

    private func caption(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
        }
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

/// One shortcut row. Click the keys, press the new combination; Esc cancels and Delete clears. A combination another
/// action already uses is refused, with the reason shown under the row.
struct ShortcutRecorder: View {
    @EnvironmentObject private var model: AppModel
    let action: HotKeyAction
    @State private var recording = false
    @State private var message: String?
    @State private var monitor: Any?

    var body: some View {
        let key = model.settings.triggers.hotkey(for: action)
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(action.displayName) {
                Button(action: toggle) {
                    Group {
                        if recording {
                            Text("Press keys…").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10).frame(height: 26)
                                .background(Theme.accent.opacity(0.14), in: Capsule())
                                .overlay(Capsule().stroke(Theme.accent.opacity(0.6), lineWidth: 1))
                        } else if key == nil {
                            Text("Not set").font(.system(size: 12)).foregroundStyle(.secondary)
                                .padding(.horizontal, 10).frame(height: 26)
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        } else {
                            HStack(spacing: 3) { ForEach(TriggersPage.caps(for: key), id: \.self) { Keycap(text: $0) } }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(recording ? "Press the new shortcut. Esc cancels." : "Click to change")
            }
            if let message {
                Text(message).font(.system(size: 11)).foregroundStyle(Theme.warn)
            }
        }
        .onDisappear { stop() }
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        message = nil
        recording = true
        model.suspendHotkeys(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            let flags = event.modifierFlags.rawValue
            MainActor.assumeIsolated { handle(code: code, flags: flags) }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { model.suspendHotkeys(false) }
        recording = false
    }

    private func handle(code: UInt16, flags: UInt) {
        let plain = flags & ((1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)) == 0
        if code == 53, plain { stop(); return }
        if code == 51, plain {
            model.updateTriggers { $0.hotkeys.removeValue(forKey: action.rawValue) }
            stop()
            return
        }
        guard let key = HotKey.from(keyCode: code, cocoaModifiers: flags) else {
            message = "Use Control, Option or Command with a key, or a function key."
            return
        }
        if let other = model.settings.triggers.conflict(for: key, excluding: action) {
            message = "\(key.displayString) already runs \(other.displayName.lowercased())."
            return
        }
        model.updateTriggers { $0.hotkeys[action.rawValue] = key }
        message = nil
        stop()
    }
}

// MARK: Apps

struct ProfilesPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let rules = model.settings.appRules
        let candidates = model.runningAppCandidates()
        let calls = candidates.filter { ShareSafe.conferencingApp(for: $0.bundleID) != nil }
        Form {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "globe").font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Everywhere else")
                        Text("Apps without a rule use this scene.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    SceneMenu(selection: model.settings.baseProfileID, allowsOff: false) { id in
                        if let id { model.chooseProfile(id) }
                    }
                }
            } header: { Text("Default") }

            Section {
                if rules.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No app rules yet").font(.system(size: 13, weight: .semibold))
                        Text("Give Zoom the Meeting scene, or turn Beacon off in a video player. Beacon switches as soon as the app is in front.")
                            .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
                ForEach(rules) { rule in
                    RuleRow(rule: rule)
                }
                AddAppMenu(candidates: candidates)
            } header: {
                Text("App rules")
            } footer: {
                Text("A scene you pick by hand wins until you switch to another app.")
            }

            if !calls.filter({ call in !rules.contains { $0.bundleID == call.bundleID } }).isEmpty {
                Section {
                    ForEach(calls.filter { call in !rules.contains { $0.bundleID == call.bundleID } }, id: \.bundleID) { app in
                        HStack(spacing: 10) {
                            AppGlyph(bundleID: app.bundleID, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name)
                                Text("Open now").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Use Meeting scene") { model.addRule(bundleID: app.bundleID, name: app.name, preferring: "meeting") }
                                .controlSize(.small)
                        }
                    }
                } header: { Text("Suggested") }
            }
        }
        .page()
    }
}

/// The real icon of an app, read from this Mac, or a plain tile when it cannot be found.
struct AppGlyph: View {
    let bundleID: String
    var size: CGFloat = 30

    var body: some View {
        if let image = AppIconCache.shared.icon(for: [bundleID]) {
            Image(nsImage: image).resizable().interpolation(.high).frame(width: size, height: size)
        } else {
            Image(systemName: "app.dashed").font(.system(size: size * 0.5)).foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        }
    }
}

/// One rule: the app, what Beacon does there, and a menu to change it. The remove button shows on hover.
struct RuleRow: View {
    @EnvironmentObject private var model: AppModel
    let rule: AppRule
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            AppGlyph(bundleID: rule.bundleID)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.appName).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(rule.profileID == nil ? "Beacon stays off here" : "Switches the scene")
                    .font(.system(size: 11)).foregroundStyle(rule.profileID == nil ? Theme.warn : .secondary)
            }
            Spacer(minLength: 6)
            SceneMenu(selection: rule.profileID, allowsOff: true) { model.setRule(rule, profileID: $0) }
            Button { model.removeRule(rule) } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain).help("Remove this rule")
            .opacity(hovered ? 1 : 0.35)
        }
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

/// A compact menu that shows a scene as a small thumbnail and its name, with an option to turn Beacon off.
struct SceneMenu: View {
    @EnvironmentObject private var model: AppModel
    let selection: String?
    let allowsOff: Bool
    let choose: (String?) -> Void

    var body: some View {
        let current = model.profiles.first { $0.id == selection }
        Menu {
            ForEach(model.profiles) { profile in
                Button {
                    choose(profile.id)
                } label: {
                    Label {
                        Text(profile.id == selection ? "\(profile.name)  \u{2713}" : profile.name)
                    } icon: {
                        Image(nsImage: MenuThumbnail.style(profile.snapshot.highlightStyle, tint: Color(rgba: profile.highlightColor)))
                    }
                }
            }
            if allowsOff {
                Divider()
                Button {
                    choose(nil)
                } label: {
                    if selection == nil { Label("Beacon off", systemImage: "checkmark") } else { Text("Beacon off") }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let current {
                    StyleThumbnail(style: current.snapshot.highlightStyle, color: Color(rgba: current.highlightColor), scale: 0.3)
                        .frame(width: 22, height: 16)
                        .background(Theme.stage, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(current.name).font(.system(size: 12, weight: .medium))
                } else {
                    Image(systemName: "nosign").font(.system(size: 11)).foregroundStyle(Theme.warn)
                    Text("Off").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.warn)
                }
            }
        }
        .menuStyle(.borderlessButton).fixedSize()
    }
}

/// Add an app: ones that are open now, then any app from the Applications folder.
struct AddAppMenu: View {
    @EnvironmentObject private var model: AppModel
    let candidates: [RunningApp]

    var body: some View {
        let ruled = Set(model.settings.appRules.map(\.bundleID))
        let open = candidates.filter { !ruled.contains($0.bundleID) }
        Menu {
            if !open.isEmpty {
                Section("Open now") {
                    ForEach(open.prefix(14), id: \.bundleID) { app in
                        Button(app.name) { model.addRule(bundleID: app.bundleID, name: app.name, preferring: nil) }
                    }
                }
            }
            Button("Choose from Applications…") { model.addRuleFromPanel() }
        } label: {
            Label("Add app", systemImage: "plus")
        }
        .menuStyle(.borderlessButton).foregroundStyle(Theme.accent)
    }
}

// MARK: Screens

struct DisplaysPage: View {
    @EnvironmentObject private var model: AppModel
    private var screens: [NSScreen] { NSScreen.screens }

    var body: some View {
        let info = ShareStatusInfo(model.shareStatus)
        Form {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    Spacer(minLength: 0)
                    ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                        DisplayTile(screen: screen, isMain: index == 0, on: model.displayScope == .all || index == 0)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                if screens.count < 2 {
                    LabeledContent("Show effects on") {
                        Text("This display").foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Show effects on", selection: Binding(get: { model.displayScope }, set: { model.setDisplayScope($0) })) {
                        ForEach(DisplayScope.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Displays")
            } footer: {
                Text(screens.count < 2
                     ? "Connect a second display to choose where effects show. The main display is the one with the menu bar."
                     : "The main display is the one with the menu bar.")
            }
            Section {
                Toggle(isOn: Binding(get: { model.settings.toolbar.enabled }, set: { v in model.setToolbar { $0.enabled = v } })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Show the floating bar")
                        Text("Quick controls for highlight, laser, drawing, colors and scenes.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                if model.settings.toolbar.enabled {
                    Picker("Show", selection: Binding(get: { model.settings.toolbar.visibility }, set: { v in model.setToolbar { $0.visibility = v } })) {
                        ForEach(ToolbarVisibility.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Toggle(isOn: Binding(get: { model.settings.toolbar.hiddenFromViewers }, set: { v in model.setToolbar { $0.hiddenFromViewers = v } })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Hide it from screen sharing")
                        Text("Viewers see your effects but not the bar. Check it in your call app.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Button("Reset position") { model.setToolbar { $0.originX = nil; $0.originY = nil } }
                    .disabled(model.settings.toolbar.origin == nil)
            } header: {
                Text("Floating bar")
            } footer: {
                if let key = model.settings.triggers.hotkey(for: .toggleToolbar) {
                    Text("Show or hide it with \(key.displayString). Drag the dotted handle to move it.")
                } else {
                    Text("Set a shortcut for it in Keys. Drag the dotted handle to move it.")
                }
            }
            Section {
                HStack(alignment: .top, spacing: 12) {
                    ShareGlyph(apps: model.conferencingApps, info: info, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.title).font(.system(size: 13, weight: .semibold))
                        Text(info.body).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                HStack(spacing: 8) {
                    shareChoice(.notSharing, "Nothing", "rectangle.slash", "Not on a call")
                    shareChoice(.wholeScreen, "Screen", "display", "Viewers see effects")
                    shareChoice(.singleWindow, "A window", "macwindow", "Viewers don't")
                }
                .padding(.vertical, 2)
            } header: {
                Text("Sharing")
            } footer: {
                Text("Beacon can't tell what you share, so it asks. Click your choice again to clear it. It resets when the call app quits.")
            }
        }
        .page()
    }

    private func shareChoice(_ value: DeclaredShare, _ title: String, _ symbol: String, _ result: String) -> some View {
        let on = model.declaredShare == value
        let tint: Color = value == .singleWindow ? Theme.warn : (value == .wholeScreen ? Theme.ok : Color.white.opacity(0.7))
        return Button { model.declareShare(on ? nil : value) } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18, weight: .regular)).foregroundStyle(on ? tint : Theme.dim)
                Text(title).font(.system(size: 12, weight: on ? .semibold : .regular)).foregroundStyle(on ? Theme.text : Theme.dim)
                Text(result).font(.system(size: 10)).foregroundStyle(on ? tint : Theme.faint).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(on ? tint.opacity(0.12) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(on ? tint.opacity(0.8) : Color.white.opacity(0.08), lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// One connected display, drawn in proportion with its name and size. A display where effects are off is dimmed.
struct DisplayTile: View {
    let screen: NSScreen
    let isMain: Bool
    let on: Bool

    var body: some View {
        let aspect = screen.frame.height / max(screen.frame.width, 1)
        let width: CGFloat = 132
        VStack(spacing: 7) {
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.2), Color(red: 0.3, green: 0.12, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(red: 0.91, green: 0.39, blue: 0.24).opacity(0.5), .clear], center: .bottomTrailing, startRadius: 0, endRadius: width * 0.8)
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black.opacity(0.35)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.white.opacity(0.9))
                        .frame(width: width * 0.5, height: width * aspect * 0.5).padding(.top, 8)
                }
            }
            .frame(width: width, height: width * aspect)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(on ? Theme.accent : Color.white.opacity(0.15), lineWidth: on ? 2 : 1))
            .shadow(color: on ? Theme.accent.opacity(0.3) : .clear, radius: 7)
            .saturation(on ? 1 : 0.2).opacity(on ? 1 : 0.55)
            VStack(spacing: 2) {
                Text(screen.localizedName).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                HStack(spacing: 5) {
                    if isMain { Pill(text: "Main", tint: Theme.accent) }
                    Text(verbatim: "\(Int(screen.frame.width)) x \(Int(screen.frame.height))")
                        .font(.system(size: 10)).foregroundStyle(on ? Theme.dim : Theme.faint)
                }
                Text(on ? "Effects on" : "Effects off").font(.system(size: 10)).foregroundStyle(on ? Theme.ok : Theme.faint)
            }
        }
        .frame(width: width + 50)
    }
}

// MARK: About

struct AboutPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var confirmingReset = false
    @State private var copied = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    BrandMark().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Branding.appName).font(.system(size: 20, weight: .bold))
                        Text("Version \(version)").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                Text("Find, point and mark up your screen while you share it.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Section {
                privacyRow("lock.shield", "No accounts, no analytics", "Nothing about you leaves this Mac.", .ok)
                privacyRow("rectangle.dashed.badge.record", "Screen Recording", "Not needed. Beacon never reads your screen.", .ok)
                privacyRow("accessibility", "Accessibility", "Not needed.", .ok)
                if model.needsInputMonitoring {
                    privacyRow("keyboard", "Input Monitoring", "Optional, and off. Only double-tap and hold use it.", .warn)
                } else {
                    privacyRow("keyboard", "Input Monitoring", "Optional, and fine as it is.", .ok)
                }
            } header: {
                Text("Privacy")
            }
            Section {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { LaunchAtLogin.set($0); launchAtLogin = LaunchAtLogin.isEnabled }))
                    .disabled(!LaunchAtLogin.isAvailable)
            } header: { Text("General") }
            Section {
                Toggle("Check for updates automatically", isOn: Binding(get: { model.automaticUpdateChecks }, set: { model.setAutomaticUpdateChecks($0) }))
                    .disabled(!model.updatesConfigured)
                Button("Check now") { model.checkForUpdates() }
            } header: {
                Text("Updates")
            } footer: {
                Text(model.updatesConfigured ? "Asks GitHub once a day. Nothing installs without your OK." : "This build has no update signing key yet.")
            }
            Section {
                Button("Show welcome guide") { model.openWelcome() }
                Button(copied ? "Copied" : "Copy diagnostics") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.diagnostics(version: version), forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }
                Button("Reset all settings…", role: .destructive) { confirmingReset = true }
                    .foregroundStyle(Theme.warn)
            } header: {
                Text("Help")
            } footer: {
                Text("Diagnostics lists the version, macOS and display setup, with nothing personal, for a bug report.")
            }
        }
        .page()
        .confirmationDialog("Reset all settings?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { model.resetAllSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Scenes, app rules, shortcuts and looks go back to how Beacon starts.")
        }
    }

    private func privacyRow(_ symbol: String, _ title: String, _ detail: String, _ state: PrivacyState) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: state == .ok ? "checkmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(state == .ok ? Theme.ok : Theme.warn).font(.system(size: 14)).padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private enum PrivacyState { case ok, warn }
}

/// The eight color keys: each key is the color itself with its number on it, so the mapping needs no legend. Click one
/// to pick it; while drawing, press its number.
struct ColorKeys: View {
    let selected: InkColor?
    let select: (InkColor) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(InkColor.allCases.enumerated()), id: \.element) { index, color in
                    key(index + 1, color)
                }
            }
            HStack(spacing: 5) {
                Text("Press").foregroundStyle(.secondary)
                Keycap(text: "1")
                Text("to").foregroundStyle(.secondary)
                Keycap(text: "8")
                Text("while drawing. Now:").foregroundStyle(.secondary)
                Text(selected?.displayName ?? "Custom").fontWeight(.semibold).foregroundStyle(selected.map { Color(rgba: $0.rgba) } ?? Theme.text)
            }
            .font(.system(size: 11))
            .scaleEffect(0.88)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func key(_ number: Int, _ color: InkColor) -> some View {
        let on = color == selected
        let fill = Color(rgba: color.rgba)
        return Button { select(color) } label: {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Self.inkOn(color))
                .frame(width: 28, height: 28)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.45)).offset(y: 2)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: [fill, fill.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                        RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 1)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white, lineWidth: on ? 2 : 0).padding(-4)
                )
                .offset(y: on ? -1 : 0)
                .padding(.bottom, 2)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: on)
        .accessibilityLabel("\(color.displayName), key \(number)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Dark digits on light colors, white on dark ones.
    private static func inkOn(_ color: InkColor) -> Color {
        switch color {
        case .yellow, .white, .orange, .green, .pink: Color.black.opacity(0.78)
        case .red, .blue, .purple: Color.white
        }
    }
}
