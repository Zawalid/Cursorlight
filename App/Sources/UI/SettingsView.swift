import BeaconCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State var page: SettingsPage
    /// False only for offscreen snapshots, where ScrollView does not render.
    var scrolls = true

    var body: some View {
        ZStack(alignment: .bottom) {
            WindowBackground()
            content
            Dock(page: $page).padding(.bottom, 16)
        }
        .frame(minWidth: 920, minHeight: 660)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var content: some View {
        if page == .highlight {
            LookPage()
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 78)
        } else {
            pageContainer {
                Group {
                    switch page {
                    case .ink: InkPage()
                    case .triggers: TriggersPage()
                    case .profiles: ProfilesPage()
                    case .displays: DisplaysPage()
                    case .about: AboutPage()
                    case .highlight: EmptyView()
                    }
                }
                .padding(.horizontal, 28).padding(.top, 12).padding(.bottom, 100)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private func pageContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if scrolls {
            ScrollView { content() }.scrollIndicators(.never)
        } else {
            content().frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// The system translucent material with a faint warm wash at one corner and a faint cool one at the other, so the window
/// has depth without any shadow.
struct WindowBackground: View {
    var body: some View {
        ZStack {
            WindowGlass()
            RadialGradient(colors: [Theme.accent.opacity(0.07), .clear], center: .topLeading, startRadius: 0, endRadius: 620)
            RadialGradient(colors: [Color(red: 0.35, green: 0.5, blue: 0.95).opacity(0.06), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

struct WindowGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// A floating pill that moves between the five sections. Each item fills its whole slot: no dead gaps, and a hover state.
struct Dock: View {
    @Binding var page: SettingsPage
    @Namespace private var thumb
    @State private var hovered: SettingsPage?
    private let items: [SettingsPage] = [.highlight, .ink, .triggers, .profiles, .displays]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let on = page == item
                Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) { page = item } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbol).font(.system(size: 12, weight: .medium))
                        Text(item.title).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(on || hovered == item ? Theme.text : Theme.dim)
                    .padding(.horizontal, 16).frame(height: 34)
                    .background {
                        if on {
                            Capsule().fill(Color.white.opacity(0.95)).matchedGeometryEffect(id: "dock", in: thumb)
                        } else if hovered == item {
                            Capsule().fill(Color.black.opacity(0.07))
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? item : (hovered == item ? nil : hovered) }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Divider().frame(height: 18).padding(.horizontal, 6)
            Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) { page = .about } } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(page == .about ? Theme.text : Theme.dim)
                    .frame(width: 34, height: 34)
                    .background(page == .about ? Color.white.opacity(0.95) : (hovered == .about ? Color.black.opacity(0.07) : .clear), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 ? .about : (hovered == .about ? nil : hovered) }
            .help("About, updates and launch at login")
        }
        .padding(4)
        .modifier(DockGlass())
    }
}

/// Real Liquid Glass where the system has it, a plain material before that.
struct DockGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: 0.5))
        }
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
