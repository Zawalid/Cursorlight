import BeaconCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State var page: SettingsPage
    /// False only for offscreen snapshots, where ScrollView does not render.
    var scrolls = true

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.line).frame(width: 1)
            pageContainer {
                Group {
                    switch page {
                    case .highlight: HighlightPage()
                    case .ink: InkPage()
                    case .triggers: TriggersPage()
                    case .profiles: ProfilesPage()
                    case .displays: DisplaysPage()
                    case .about: AboutPage()
                    }
                }
                .padding(.horizontal, 32).padding(.top, 38).padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .id(page)
                .transition(.opacity)
            }
        }
        .frame(minWidth: 860, minHeight: 600)
        .background(Theme.window)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func pageContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if scrolls {
            ScrollView { content() }
        } else {
            content().frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                BrandMark().frame(width: 26, height: 26)
                Text(Branding.appName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 10).padding(.top, 34).padding(.bottom, 18)
            ForEach(SettingsPage.allCases.filter { $0 != .about }) { item in navButton(item) }
            Spacer()
            navButton(.about)
            ShareNote().padding(.top, 8)
        }
        .padding(10)
        .frame(width: 210)
        .background(Theme.sidebar)
    }

    private func navButton(_ item: SettingsPage) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { page = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol).font(.system(size: 13)).frame(width: 18)
                Text(item.title).font(.system(size: 13))
                Spacer()
            }
            .foregroundStyle(page == item ? Theme.text : Theme.dim)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(page == item ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(page == item ? .isSelected : [])
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

    init(_ status: ShareSafeStatus) {
        switch status {
        case .idle:
            symbol = "rectangle.on.rectangle"; tint = Theme.dim
            title = "Sharing your screen?"
            body = "Viewers only see effects when you share the whole screen, not one window."
            short = "Share the whole screen so viewers can see effects."
        case .ok:
            symbol = "checkmark.circle"; tint = Theme.ok
            title = "Viewers can see your effects"
            body = "You said you are sharing the whole screen."
            short = "Whole screen shared: viewers can see effects."
        case .warnSingleWindow:
            symbol = "exclamationmark.triangle"; tint = Theme.warn
            title = "Viewers will not see effects"
            body = "You said you are sharing one window. Share the whole screen instead."
            short = "One window shared: viewers will not see effects."
        case let .reminder(app):
            symbol = "info.circle"; tint = Theme.warn
            title = "\(app) is open"
            body = "Share the whole screen, not one window, so viewers see effects."
            short = "\(app) is open. Share the whole screen."
        case .notSharing:
            symbol = "rectangle.on.rectangle.slash"; tint = Theme.dim
            title = "Not sharing"
            body = "Tell Beacon when you start sharing and it will check."
            short = "Not sharing."
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
