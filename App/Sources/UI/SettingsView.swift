import BeaconCore
import SwiftUI

/// The window is a canvas and an inspector. The canvas is a live miniature of a screen, full-bleed, with your real mouse
/// playing across it; a strip of scenes sits under it. The inspector on the right holds the controls for one area at a
/// time. The title bar is empty on purpose, so the canvas runs to the top edge.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State var page: SettingsPage
    /// False only for offscreen snapshots, where scroll views do not render.
    var scrolls = true

    var body: some View {
        VStack(spacing: 0) {
            Canvas_()
            SceneStrip()
        }
        .background(Theme.stage)
        .ignoresSafeArea(.container, edges: .top)
        .inspector(isPresented: .constant(true)) {
            Inspector(page: $page)
                .inspectorColumnWidth(min: 310, ideal: 340, max: 420)
        }
        .frame(minWidth: 980, minHeight: 640)
        .environment(\.inspectorPage, page)
    }

    /// The canvas: the live stage, with the share status top right and the highlight switch bottom left.
    @ViewBuilder
    private func Canvas_() -> some View {
        ZStack {
            if page == .ink {
                InkPreview(style: model.settings.inkStyle, color: model.settings.inkColor, cleanup: model.settings.inkCleanup, fade: model.settings.inkFadeAfter)
            } else {
                Stage(style: model.settings.highlightStyle, look: model.settings.look)
            }
        }
        .overlay(alignment: .topTrailing) { ShareChip().padding(.top, 14).padding(.trailing, 16) }
        .overlay(alignment: .bottomLeading) { OnChip().padding(16) }
        .overlay(alignment: .bottom) { SceneSwitcher().padding(.bottom, 20) }
        .overlay(alignment: .bottomTrailing) {
            ShortcutChip(action: page == .ink ? .ink : .highlight) { page = .triggers }.padding(16)
        }
    }
}

private struct InspectorPageKey: EnvironmentKey { static let defaultValue: SettingsPage = .highlight }
extension EnvironmentValues {
    var inspectorPage: SettingsPage {
        get { self[InspectorPageKey.self] }
        set { self[InspectorPageKey.self] = newValue }
    }
}

/// The right column: a row of tabs on top, one area's controls below.
struct Inspector: View {
    @Binding var page: SettingsPage

    var body: some View {
        VStack(spacing: 0) {
            InspectorTabs(page: $page)
            Divider().opacity(0.6)
            Group {
                switch page {
                case .highlight: LookPage()
                case .ink: InkPage()
                case .triggers: TriggersPage()
                case .profiles: ProfilesPage()
                case .displays: DisplaysPage()
                case .about: AboutPage()
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

/// Six tabs, each an icon over a label. The selected one has a soft plate that slides to it and an Ember icon; hovering a
/// tab lightens it. Every tab fills its whole slot, so there are no dead gaps between them.
struct InspectorTabs: View {
    @Binding var page: SettingsPage
    @Namespace private var plate
    @State private var hovered: SettingsPage?
    private let tabs: [SettingsPage] = [.highlight, .ink, .triggers, .profiles, .displays, .about]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { item in
                let on = page == item
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { page = item }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.accent : (hovered == item ? Theme.text : Theme.dim))
                            .frame(height: 20)
                        Text(item.title)
                            .font(.system(size: 10.5, weight: on ? .semibold : .medium))
                            .foregroundStyle(on ? Theme.text : (hovered == item ? Theme.text : Theme.dim))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.09))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.08)))
                                .matchedGeometryEffect(id: "plate", in: plate)
                        } else if hovered == item {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.05))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? item : (hovered == item ? nil : hovered) }
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 8)
    }
}

/// A dark glass chip that floats on the canvas.
struct CanvasChip<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 12).frame(height: 28)
            .background(Color.black.opacity(0.5), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

/// What viewers can see. Click to say what you are sharing.
struct ShareChip: View {
    @EnvironmentObject private var model: AppModel
    @State private var open = false

    var body: some View {
        let info = ShareStatusInfo(model.shareStatus)
        Button { open.toggle() } label: {
            CanvasChip {
                HStack(spacing: 7) {
                    Circle().fill(info.chipTint).frame(width: 7, height: 7)
                    Text(info.pill)
                }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text(info.title).font(.system(size: 13, weight: .semibold))
                Text(info.body).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Divider()
                Picker("I am sharing", selection: Binding(get: { model.declaredShare }, set: { model.declareShare($0); open = false })) {
                    Text("Nothing").tag(DeclaredShare?.some(.notSharing))
                    Text("Screen").tag(DeclaredShare?.some(.wholeScreen))
                    Text("A window").tag(DeclaredShare?.some(.singleWindow))
                }
                .pickerStyle(.segmented)
            }
            .padding(14).frame(width: 280)
        }
    }
}

/// Whether the highlight is on. Click to turn it on or off.
struct OnChip: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let on = model.isOn(.highlight)
        Button { model.toggle(.highlight) } label: {
            CanvasChip {
                HStack(spacing: 7) {
                    Circle().fill(on ? Theme.accent : Color.white.opacity(0.4)).frame(width: 7, height: 7)
                        .shadow(color: on ? Theme.accent : .clear, radius: 4)
                    Text(on ? "Highlight is on" : "Highlight is off")
                }
            }
        }
        .buttonStyle(.plain)
        .help("Click to turn the highlight on or off")
    }
}

/// The product mark: a bright core inside a glowing ring, in the accent color.
struct BrandMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.16, green: 0.08, blue: 0.06))
            .overlay(
                Circle().fill(RadialGradient(colors: [.white, Theme.accent, Theme.accent.opacity(0)], center: .center, startRadius: 0, endRadius: 13))
            )
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.line))
    }
}

/// A compact share status for the sidebar.
struct ShareNote: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let info = ShareStatusInfo(model.shareStatus)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: info.symbol).font(.system(size: 11)).foregroundStyle(info.tint).padding(.top, 1)
            Text(info.short).font(.system(size: 11)).foregroundStyle(info.tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(info.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Words and color for each share status. Never says viewers can see effects unless the user said so.
struct ShareStatusInfo {
    let symbol: String
    let tint: Color
    let title: String
    let body: String
    let short: String
    /// Very short, for the Stage chip.
    let pill: String
    /// A brighter tint for dark surfaces.
    let chipTint: Color

    init(_ status: ShareSafeStatus) {
        switch status {
        case .idle:
            symbol = "rectangle.on.rectangle"; tint = Theme.dim; chipTint = Color.white.opacity(0.45)
            title = "Sharing your screen?"
            body = "Viewers only see effects when you share the whole screen, not one window."
            short = "Share the whole screen so viewers can see effects."
            pill = "Sharing?"
        case .ok:
            symbol = "checkmark.circle"; tint = Theme.ok; chipTint = Color(red: 0.35, green: 0.86, blue: 0.5)
            title = "Viewers can see your effects"
            body = "You said you are sharing the whole screen."
            short = "Whole screen shared: viewers can see effects."
            pill = "Viewers see effects"
        case .warnSingleWindow:
            symbol = "exclamationmark.triangle"; tint = Theme.warn; chipTint = Color(red: 1, green: 0.76, blue: 0.3)
            title = "Viewers will not see effects"
            body = "You said you are sharing one window. Share the whole screen instead."
            short = "One window shared: viewers will not see effects."
            pill = "Viewers will not see effects"
        case let .reminder(app):
            symbol = "info.circle"; tint = Theme.warn; chipTint = Color(red: 1, green: 0.76, blue: 0.3)
            title = "\(app) is open"
            body = "Share the whole screen, not one window, so viewers see effects."
            short = "\(app) is open. Share the whole screen."
            pill = "\(app) is open"
        case .notSharing:
            symbol = "rectangle.on.rectangle.slash"; tint = Theme.dim; chipTint = Color.white.opacity(0.45)
            title = "Not sharing"
            body = "Tell Beacon when you start sharing and it will check."
            short = "Not sharing."
            pill = "Not sharing"
        }
    }
}

/// The share status with a control for telling Beacon what is being shared.
struct ShareStatusCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let info = ShareStatusInfo(model.shareStatus)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: info.symbol).foregroundStyle(info.tint).font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(info.body).font(.system(size: 11)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("I am sharing").font(.system(size: 11)).foregroundStyle(Theme.faint)
                BeaconSegmented(
                    options: [(DeclaredShare?.some(.notSharing), "Nothing"), (.some(.wholeScreen), "Screen"), (.some(.singleWindow), "A window")],
                    selection: Binding(get: { model.declaredShare }, set: { model.declareShare($0) }),
                    fills: true
                )
            }
        }
        .padding(12)
        .background(info.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(info.tint.opacity(0.22)))
    }
}
