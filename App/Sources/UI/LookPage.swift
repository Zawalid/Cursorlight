import BeaconCore
import SwiftUI

/// The first page: the Stage, then the style tiles and the controls that tune the chosen style.
struct LookPage: View {
    @EnvironmentObject private var model: AppModel
    private var settings: BeaconSettings { model.settings }

    var body: some View {
        VStack(spacing: 14) {
            Stage(style: settings.highlightStyle, look: settings.look)
                .frame(minHeight: 240, maxHeight: .infinity)
            HStack(alignment: .top, spacing: 14) {
                stylePane
                tunePane
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stylePane: some View {
        Pane(title: "Style") {
            HStack(spacing: 8) {
                ForEach(HighlightStyle.allCases, id: \.self) { style in
                    StyleTile(style: style, isSelected: settings.highlightStyle == style) { model.setStyle(style) }
                }
            }
            Text(Self.blurb(settings.highlightStyle))
                .font(.system(size: 12)).foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            if settings.highlightStyle == .lens {
                Divider().overlay(Theme.line).padding(.vertical, 4)
                labeled("Screen dim") {
                    Slider(value: Binding(get: { settings.lensDim }, set: { model.setLensDim($0) }), in: HighlightLook.dimRange)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var tunePane: some View {
        Pane(title: "Tune") {
            labeled("Color") {
                HStack(spacing: 2) {
                    ForEach(AccentChoice.allCases, id: \.self) { accent in
                        SwatchButton(fill: HighlightPage.fill(for: accent), isSelected: settings.accent == accent, label: accent.displayName) {
                            model.setAccent(accent)
                        }
                    }
                }
            }
            labeled("Size") {
                Slider(value: Binding(get: { settings.highlightSize }, set: { model.setSize($0) }), in: HighlightLook.sizeRange).frame(width: 200)
            }
            labeled("Intensity") {
                Slider(value: Binding(get: { settings.highlightIntensity }, set: { model.setIntensity($0) }), in: HighlightLook.intensityRange)
                    .frame(width: 200)
                    .disabled(settings.accent == .highContrast)
            }
            labeled("Click ripples") {
                Toggle("", isOn: Binding(get: { settings.clickRipples }, set: { model.setRipples($0) }))
                    .toggleStyle(.switch).labelsHidden()
            }
            labeled("Pointer size") {
                Picker("", selection: Binding(get: { Self.nearest(model.cursorScale) }, set: { model.setCursorScale($0) })) {
                    Text("1x").tag(1.0); Text("1.5x").tag(1.5); Text("2x").tag(2.0); Text("3x").tag(3.0)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 170)
            }
        }
        .frame(width: 360, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func labeled<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.text)
            Spacer(minLength: 12)
            content().tint(Theme.accent)
        }
        .frame(minHeight: 26)
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

struct Pane<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.dim)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
    }
}

struct StyleTile: View {
    let style: HighlightStyle
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                StyleThumbnail(style: style)
                    .frame(height: 52).frame(maxWidth: .infinity)
                    .background(Theme.stage, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(style.displayName).font(.system(size: 12, weight: .medium)).foregroundStyle(isSelected ? Theme.text : Theme.dim)
            }
            .padding(7)
            .background(hovering ? Theme.cardHover : Theme.raised, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Theme.line, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Theme.accent.opacity(0.22) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
