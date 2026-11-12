import BeaconCore
import SwiftUI

/// The first page. Top to bottom: the Stage, the five styles as a row of tiles with a line about the chosen one, then two
/// cards of native controls.
struct LookPage: View {
    @EnvironmentObject private var model: AppModel
    private var settings: BeaconSettings { model.settings }

    var body: some View {
        VStack(spacing: 18) {
            Stage(style: settings.highlightStyle, look: settings.look)
                .frame(minHeight: 200, maxHeight: .infinity)

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ForEach(HighlightStyle.allCases, id: \.self) { style in
                        StyleTile(style: style, isSelected: settings.highlightStyle == style) { model.setStyle(style) }
                    }
                }
                Text(Self.blurb(settings.highlightStyle))
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Appearance")
                    SettingsGroup {
                        SettingRow(title: "Color") {
                            HStack(spacing: 0) {
                                ForEach(AccentChoice.allCases, id: \.self) { accent in
                                    SwatchButton(fill: HighlightPage.fill(for: accent), isSelected: settings.accent == accent, label: accent.displayName) {
                                        model.setAccent(accent)
                                    }
                                }
                            }
                        }
                        SettingRow(title: "Size") {
                            BeaconSlider(value: Binding(get: { settings.highlightSize }, set: { model.setSize($0) }), range: HighlightLook.sizeRange, width: 200)
                        }
                        if settings.highlightStyle == .lens {
                            SettingRow(title: "Screen dim", showsDivider: false) {
                                BeaconSlider(value: Binding(get: { settings.lensDim }, set: { model.setLensDim($0) }), range: HighlightLook.dimRange, width: 200)
                            }
                        } else {
                            SettingRow(title: "Intensity", showsDivider: false) {
                                BeaconSlider(value: Binding(get: { settings.highlightIntensity }, set: { model.setIntensity($0) }), range: HighlightLook.intensityRange, width: 200)
                                    .disabled(settings.accent == .highContrast)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Behavior")
                    SettingsGroup {
                        SettingRow(title: "Click ripples", subtitle: "A ring on every click") {
                            BeaconToggle(isOn: Binding(get: { settings.clickRipples }, set: { model.setRipples($0) }))
                        }
                        SettingRow(title: "Pointer size", subtitle: "Makes the real pointer bigger", showsDivider: false) {
                            BeaconSegmented(
                                options: [(1.0, "1x"), (1.5, "1.5x"), (2.0, "2x"), (3.0, "3x")],
                                selection: Binding(get: { Self.nearest(model.cursorScale) }, set: { model.setCursorScale($0) })
                            )
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
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

/// One of the five styles: a live thumbnail and its name. Flat, with an Ember ring when selected.
struct StyleTile: View {
    let style: HighlightStyle
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                StyleThumbnail(style: style)
                    .frame(height: 60).frame(maxWidth: .infinity)
                    .background(Theme.stage, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text(style.displayName).font(.system(size: 12, weight: .medium)).foregroundStyle(isSelected ? Theme.text : Theme.dim)
            }
            .padding(8)
            .background(isSelected ? Theme.raised : (hovering ? Theme.cardHover : Theme.card), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(isSelected ? Theme.accent : Theme.line, lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
