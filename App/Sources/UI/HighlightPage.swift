import BeaconCore
import SwiftUI

struct HighlightPage: View {
    @EnvironmentObject private var model: AppModel

    private var settings: BeaconSettings { model.settings }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Highlight", subtitle: "Shake the pointer to turn it on. It stays until you shake again.")
                .padding(.bottom, 20)
            PreviewCanvas(style: settings.highlightStyle, look: settings.look)
            HStack(spacing: 10) {
                ForEach(HighlightStyle.allCases, id: \.self) { style in
                    ChoiceCard(title: style.displayName, isSelected: settings.highlightStyle == style) {
                        model.setStyle(style)
                    } thumbnail: {
                        StyleThumbnail(style: style)
                    }
                }
            }
            .padding(.top, 16)
            SettingsGroup {
                SettingRow(title: "Color", subtitle: settings.accent.displayName) {
                    HStack(spacing: 4) {
                        ForEach(AccentChoice.allCases, id: \.self) { accent in
                            SwatchButton(fill: Self.fill(for: accent), isSelected: settings.accent == accent, label: accent.displayName) {
                                model.setAccent(accent)
                            }
                        }
                    }
                }
                SettingRow(title: "Size") {
                    BeaconSlider(value: Binding(get: { settings.highlightSize }, set: { model.setSize($0) }), range: HighlightLook.sizeRange)
                }
                SettingRow(title: "Intensity", subtitle: settings.accent == .highContrast ? "High contrast always draws at full strength" : nil) {
                    BeaconSlider(value: Binding(get: { settings.highlightIntensity }, set: { model.setIntensity($0) }), range: HighlightLook.intensityRange)
                        .opacity(settings.accent == .highContrast ? 0.4 : 1)
                        .allowsHitTesting(settings.accent != .highContrast)
                }
                SettingRow(title: "Screen dim", subtitle: "Lens only") {
                    BeaconSlider(value: Binding(get: { settings.lensDim }, set: { model.setLensDim($0) }), range: HighlightLook.dimRange)
                        .opacity(settings.highlightStyle == .lens ? 1 : 0.35)
                }
                SettingRow(title: "Click ripples", subtitle: "A ring on every click") {
                    BeaconToggle(isOn: Binding(get: { settings.clickRipples }, set: { model.setRipples($0) }))
                }
                SettingRow(title: "System cursor size", subtitle: "Makes the real pointer bigger, in every app", showsDivider: false) {
                    BeaconSegmented(
                        options: [(1.0, "1x"), (1.5, "1.5x"), (2.0, "2x"), (3.0, "3x")],
                        selection: Binding(
                            get: { Self.nearest(model.cursorScale) },
                            set: { model.setCursorScale($0) }
                        )
                    )
                }
            }
            .padding(.top, 18)
        }
    }

    private static func nearest(_ scale: Double) -> Double {
        [1.0, 1.5, 2.0, 3.0].min { abs($0 - scale) < abs($1 - scale) } ?? 1
    }

    static func fill(for accent: AccentChoice) -> AnyShapeStyle {
        if let color = accent.color { return AnyShapeStyle(Color(rgba: color)) }
        return AnyShapeStyle(AngularGradient(colors: [.purple, .orange, .red, .blue, .teal, .purple], center: .center))
    }
}
