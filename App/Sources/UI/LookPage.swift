import BeaconCore
import SwiftUI

/// The first page. Top to bottom: the Stage, the five styles as a row of tiles, then two native grouped forms.
struct LookPage: View {
    @EnvironmentObject private var model: AppModel
    private var settings: BeaconSettings { model.settings }

    var body: some View {
        VStack(spacing: 14) {
            Stage(style: settings.highlightStyle, look: settings.look)
                .frame(minHeight: 200, maxHeight: .infinity)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    ForEach(HighlightStyle.allCases, id: \.self) { style in
                        StyleTile(style: style, isSelected: settings.highlightStyle == style) { model.setStyle(style) }
                    }
                }
                Text(Self.blurb(settings.highlightStyle))
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }

            HStack(alignment: .top, spacing: 14) {
                Form {
                    Section("Appearance") {
                        LabeledContent("Color") {
                            HStack(spacing: 0) {
                                ForEach(AccentChoice.allCases, id: \.self) { accent in
                                    SwatchButton(fill: HighlightPage.fill(for: accent), isSelected: settings.accent == accent, label: accent.displayName) {
                                        model.setAccent(accent)
                                    }
                                }
                            }
                        }
                        LabeledContent("Size") {
                            Slider(value: Binding(get: { settings.highlightSize }, set: { model.setSize($0) }), in: HighlightLook.sizeRange)
                                .frame(width: 190)
                        }
                        if settings.highlightStyle == .lens {
                            LabeledContent("Screen dim") {
                                Slider(value: Binding(get: { settings.lensDim }, set: { model.setLensDim($0) }), in: HighlightLook.dimRange)
                                    .frame(width: 190)
                            }
                        } else {
                            LabeledContent("Intensity") {
                                Slider(value: Binding(get: { settings.highlightIntensity }, set: { model.setIntensity($0) }), in: HighlightLook.intensityRange)
                                    .frame(width: 190)
                                    .disabled(settings.accent == .highContrast)
                            }
                        }
                    }
                }
                Form {
                    Section("Behavior") {
                        Toggle("Click ripples", isOn: Binding(get: { settings.clickRipples }, set: { model.setRipples($0) }))
                            .toggleStyle(.switch)
                        LabeledContent("Pointer size") {
                            Picker("", selection: Binding(get: { Self.nearest(model.cursorScale) }, set: { model.setCursorScale($0) })) {
                                Text("1x").tag(1.0); Text("1.5x").tag(1.5); Text("2x").tag(2.0); Text("3x").tag(3.0)
                            }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 170)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .tint(Theme.accent)
            .frame(height: 168)
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

/// One of the five styles: a live thumbnail and its name. Flat, with a ring when selected.
struct StyleTile: View {
    let style: HighlightStyle
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: { DebugLog.write("style \(style.rawValue)"); action() }) {
            VStack(spacing: 8) {
                StyleThumbnail(style: style)
                    .frame(height: 64).frame(maxWidth: .infinity)
                    .background(Theme.stage, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(style.displayName).font(.system(size: 12, weight: .medium)).foregroundStyle(isSelected ? Theme.text : Theme.dim)
            }
            .padding(8)
            .background(isSelected ? Color.white.opacity(0.7) : (hovering ? Color.black.opacity(0.06) : Color.black.opacity(0.03)),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Theme.accent : .clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
