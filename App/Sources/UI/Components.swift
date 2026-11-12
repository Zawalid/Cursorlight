import SwiftUI

/// A page header: title and one line of plain explanation.
struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.text)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A rounded card holding rows separated by hairlines.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 18)
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
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.dim)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if showsDivider { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }
}

struct BeaconToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Theme.accent : Color.white.opacity(0.16)).frame(width: 38, height: 22)
                Circle().fill(.white).frame(width: 18, height: 18).padding(2)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct BeaconSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var width: CGFloat = 190

    var body: some View {
        let span = range.upperBound - range.lowerBound
        let fraction = span > 0 ? (value - range.lowerBound) / span : 0
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.14)).frame(height: 4)
            Capsule().fill(Theme.accent).frame(width: max(width * fraction, 0), height: 4)
            Circle().fill(.white).frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .offset(x: width * fraction - 8)
        }
        .frame(width: width, height: 22)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { drag in
                let f = min(max(drag.location.x / width, 0), 1)
                value = range.lowerBound + span * f
            }
        )
        .accessibilityRepresentation {
            Slider(value: $value, in: range)
        }
    }
}

struct BeaconSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selection == option.value ? Theme.text : Theme.dim)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selection == option.value ? Color.white.opacity(0.14) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.well, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.line))
    }
}

/// A dropdown that shows its current value.
struct BeaconMenu<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var width: CGFloat = 140

    var body: some View {
        Menu {
            ForEach(options.indices, id: \.self) { index in
                Button(options[index].title) { selection = options[index].value }
            }
        } label: {
            HStack {
                Text(options.first { $0.value == selection }?.title ?? "")
                    .font(.system(size: 13)).foregroundStyle(Theme.text)
                Spacer(minLength: 6)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(width: width)
            .background(Theme.well, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.line))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct Keycap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(white: 0.9))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.1)))
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
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [Color(white: 0.17), Color(white: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
            }
            .padding(10)
            .background(hovering ? Theme.cardHover : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Theme.line, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Theme.accent.opacity(0.18) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isSelected)
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
            Circle().fill(fill).frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                .padding(2)
                .overlay(Circle().stroke(isSelected ? Color.white : .clear, lineWidth: 2))
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
            .background(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
