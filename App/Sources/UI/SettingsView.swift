import BeaconCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State var page: SettingsPage
    /// False only for offscreen snapshots, where ScrollView does not render.
    var scrolls = true

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.window
            VStack(spacing: 0) {
                TopBar(page: $page)
                content
            }
            .ignoresSafeArea(.container, edges: .top)
            Dock(page: $page).padding(.bottom, 16)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 860, minHeight: 620)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        if page == .highlight {
            LookPage()
                .padding(.horizontal, 20)
                .padding(.bottom, 76)
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
                .padding(.horizontal, 32).padding(.top, 14).padding(.bottom, 96)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private func pageContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if scrolls {
            ScrollView { content() }
        } else {
            content().frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Scenes on the left, the share signal and a small menu on the right. Sits under the transparent title bar.
struct TopBar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var page: SettingsPage

    var body: some View {
        HStack(spacing: 10) {
            Spacer().frame(width: 70)
            HStack(spacing: 2) {
                ForEach(model.profiles) { profile in
                    let active = model.appliedProfileID == profile.id
                    Button { model.chooseProfile(profile.id) } label: {
                        Text(profile.name).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(active ? Theme.window : Theme.dim)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(active ? Theme.text : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                    .contextMenu {
                        if model.profiles.count > 1 { Button("Delete \(profile.name)", role: .destructive) { model.deleteProfile(profile.id) } }
                    }
                }
                Button { model.addProfile() } label: {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.dim)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .help("Save the current look as a new scene")
            }
            .padding(3)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.line))
            Spacer()
            SignalPill()
            Button { page = .about } label: {
                Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
                    .frame(width: 28, height: 28).background(Theme.card, in: Circle()).overlay(Circle().stroke(Theme.line))
            }
            .buttonStyle(.plain)
            .help("About, updates and launch at login")
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .padding(.bottom, 8)
    }
}

/// The share status as a small beacon. Click to say what you are sharing.
struct SignalPill: View {
    @EnvironmentObject private var model: AppModel
    @State private var open = false

    var body: some View {
        let info = ShareStatusInfo(model.shareStatus)
        Button { open.toggle() } label: {
            HStack(spacing: 7) {
                Circle().fill(info.tint).frame(width: 7, height: 7).shadow(color: info.tint.opacity(0.9), radius: 4)
                Text(info.pill).font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.line))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text(info.title).font(.system(size: 13, weight: .semibold))
                Text(info.body).font(.system(size: 12)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                Divider()
                Text("I am sharing").font(.system(size: 11)).foregroundStyle(Theme.faint)
                Picker("", selection: Binding(get: { model.declaredShare }, set: { model.declareShare($0); open = false })) {
                    Text("Nothing").tag(DeclaredShare?.some(.notSharing))
                    Text("Screen").tag(DeclaredShare?.some(.wholeScreen))
                    Text("A window").tag(DeclaredShare?.some(.singleWindow))
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            .padding(14).frame(width: 280)
            .preferredColorScheme(.dark)
        }
    }
}

/// A floating pill that moves between the five sections.
struct Dock: View {
    @Binding var page: SettingsPage
    private let items: [SettingsPage] = [.highlight, .ink, .triggers, .profiles, .displays]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { page = item } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbol).font(.system(size: 12))
                        Text(item.title).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(page == item ? Theme.window : Theme.dim)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(page == item ? Theme.text : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(page == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Theme.raised.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(Theme.line))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
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
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.1)))
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
    /// Very short, for the top bar.
    let pill: String

    init(_ status: ShareSafeStatus) {
        switch status {
        case .idle:
            symbol = "rectangle.on.rectangle"; tint = Theme.dim
            title = "Sharing your screen?"
            body = "Viewers only see effects when you share the whole screen, not one window."
            short = "Share the whole screen so viewers can see effects."
            pill = "Sharing?"
        case .ok:
            symbol = "checkmark.circle"; tint = Theme.ok
            title = "Viewers can see your effects"
            body = "You said you are sharing the whole screen."
            short = "Whole screen shared: viewers can see effects."
            pill = "Viewers see effects"
        case .warnSingleWindow:
            symbol = "exclamationmark.triangle"; tint = Theme.warn
            title = "Viewers will not see effects"
            body = "You said you are sharing one window. Share the whole screen instead."
            short = "One window shared: viewers will not see effects."
            pill = "Viewers will not see effects"
        case let .reminder(app):
            symbol = "info.circle"; tint = Theme.warn
            title = "\(app) is open"
            body = "Share the whole screen, not one window, so viewers see effects."
            short = "\(app) is open. Share the whole screen."
            pill = "\(app) is open"
        case .notSharing:
            symbol = "rectangle.on.rectangle.slash"; tint = Theme.dim
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
