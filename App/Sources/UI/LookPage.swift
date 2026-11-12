import BeaconCore
import SwiftUI

/// The first page: a title, the Stage (the one framed object), the five styles, then settings as plain rows.
struct LookPage: View {
    @EnvironmentObject private var model: AppModel
    private var settings: BeaconSettings { model.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Look", subtitle: "How your pointer is highlighted while you share.")

            Stage(style: settings.highlightStyle, look: settings.look)
                .frame(minHeight: 180, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ForEach(HighlightStyle.allCases, id: \.self) { style in
                        StyleTile(style: style, isSelected: settings.highlightStyle == style) { model.setStyle(style) }
                    }
                }
                Text(Self.blurb(settings.highlightStyle))
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
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
                            BeaconSlider(value: Binding(get: { settings.highlightSize }, set: { model.setSize($0) }), range: HighlightLook.sizeRange, width: 170)
                        }
                        if settings.highlightStyle == .lens {
                            SettingRow(title: "Screen dim") {
                                BeaconSlider(value: Binding(get: { settings.lensDim }, set: { model.setLensDim($0) }), range: HighlightLook.dimRange, width: 170)
                            }
                        } else {
                            SettingRow(title: "Intensity") {
                                BeaconSlider(value: Binding(get: { settings.highlightIntensity }, set: { model.setIntensity($0) }), range: HighlightLook.intensityRange, width: 170)
                                    .disabled(settings.accent == .highContrast)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Behavior")
                    SettingsGroup {
                        SettingRow(title: "Click ripples") {
                            BeaconToggle(isOn: Binding(get: { settings.clickRipples }, set: { model.setRipples($0) }))
                        }
                        SettingRow(title: "Pointer size") {
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

/// One of the five styles: a live thumbnail and its name. Selected is an Ember ring on the thumbnail, nothing else.
struct StyleTile: View {
    let style: HighlightStyle
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                StyleThumbnail(style: style)
                    .frame(height: 64).frame(maxWidth: .infinity)
                    .background(Theme.stage, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Theme.accent : (hovering ? Color.white.opacity(0.22) : Theme.line), lineWidth: isSelected ? 2 : 1)
                    )
                Text(style.displayName).font(.system(size: 12, weight: .medium)).foregroundStyle(isSelected ? Theme.text : Theme.dim)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
