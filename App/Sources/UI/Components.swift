import SwiftUI

/// A page header: title and one line of plain explanation.
struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 22, weight: .semibold)).tracking(-0.3).foregroundStyle(Theme.text)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small caption above a card.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold)).tracking(0.6)
            .foregroundStyle(Theme.faint)
            .padding(.leading, 4)
    }
}

/// A rounded card holding rows separated by hairlines. Flat: a near-white fill and a hairline edge, no shadow.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line))
    }
}

struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var showsDivider = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.dim)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .frame(minHeight: 44)
        .padding(.vertical, subtitle == nil ? 0 : 6)
        .overlay(alignment: .bottom) {
            if showsDivider { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }
}

/// The three controls below are the native ones, tinted with the accent, so they behave and feel like the system's.
struct BeaconToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().tint(Theme.accent)
    }
}

struct BeaconSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var width: CGFloat = 190

    var body: some View {
        Slider(value: $value, in: range).tint(Theme.accent).frame(width: width)
    }
}

struct BeaconSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    /// Kept for old call sites; the control sizes itself.
    var fills = false
    @Namespace private var thumb
    @State private var hovered: Int?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let on = options[index].value == selection
                Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { selection = options[index].value } } label: {
                    Text(options[index].title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(on || hovered == index ? Theme.text : Theme.dim)
                        .lineLimit(1)
                        .padding(.horizontal, 12).frame(height: 26)
                        .background {
                            if on {
                                Capsule().fill(Color.white.opacity(0.98))
                                    .overlay(Capsule().stroke(Theme.line))
                                    .matchedGeometryEffect(id: "seg", in: thumb)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? index : (hovered == index ? nil : hovered) }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.06), in: Capsule())
    }
}

/// A dropdown that shows its current value.
struct BeaconMenu<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var width: CGFloat = 140

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options.indices, id: \.self) { Text(options[$0].title).tag(options[$0].value) }
        }
        .pickerStyle(.menu).labelsHidden().fixedSize()
    }
}

struct Keycap: View {
    let text: String
    var dark = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(dark ? Color.white.opacity(0.9) : Theme.text)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 5)
            .background(dark ? Color.white.opacity(0.14) : Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(dark ? Color.white.opacity(0.18) : Theme.line))
    }
}

struct Pill: View {
    let text: String
    var tint: Color = Theme.dim

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 9).padding(.vertical, 2)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

/// A selectable tile: a thumbnail above a name.
struct ChoiceCard<Thumb: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var thumbnail: Thumb
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                thumbnail
                    .frame(height: 54).frame(maxWidth: .infinity)
                    .background(Theme.stage, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(isSelected ? Theme.text : Theme.dim)
            }
            .padding(8)
            .background(isSelected ? Theme.raised : (hovering ? Theme.cardHover : Theme.card), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(isSelected ? Theme.accent : Theme.line, lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SwatchButton: View {
    let fill: AnyShapeStyle
    let isSelected: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle().fill(fill).frame(width: 20, height: 20)
                .overlay(Circle().stroke(Theme.fillMid, lineWidth: 1))
                .padding(3)
                .overlay(Circle().stroke(isSelected ? Theme.text : .clear, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(label)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Color.black.opacity(configuration.isPressed ? 0.12 : 0.06), in: Capsule())
    }
}
