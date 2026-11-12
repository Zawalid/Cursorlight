import BeaconCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State var page: SettingsPage
    /// False only for offscreen snapshots, where scroll views do not render.
    var scrolls = true
    private let sections: [SettingsPage] = [.highlight, .ink, .triggers, .profiles, .displays]

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<SettingsPage?>(get: { page }, set: { if let value = $0 { page = value } })) {
                Section {
                    ForEach(sections) { item in Label(item.title, systemImage: item.symbol).tag(item) }
                }
                Section {
                    Label(SettingsPage.about.title, systemImage: SettingsPage.about.symbol).tag(SettingsPage.about)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 212, max: 240)
            .safeAreaInset(edge: .bottom, spacing: 0) { StatusBlock() }
        } detail: {
            detail
                .navigationTitle(page.title)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { SceneMenu() }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private var detail: some View {
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

/// The current scene as a standard toolbar menu: pick a scene, make a new one from the current look, rename or delete.
struct SceneMenu: View {
    @EnvironmentObject private var model: AppModel
    @State private var renaming = false
    @State private var draft = ""

    private var current: Profile? { model.profiles.first { $0.id == model.appliedProfileID } }

    var body: some View {
        Menu {
            Picker("Scene", selection: Binding(get: { model.appliedProfileID }, set: { model.chooseProfile($0) })) {
                ForEach(model.profiles) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.inline)
            Divider()
            Button("New Scene from This Look") { model.addProfile() }
            Button("Rename Scene…") { draft = current?.name ?? ""; renaming = true }
            if model.profiles.count > 1, let id = current?.id {
                Button("Delete Scene", role: .destructive) { model.deleteProfile(id) }
            }
        } label: {
            Label(current?.name ?? "Scene", systemImage: "square.stack.3d.up")
        }
        .help("Scene")
        .alert("Rename Scene", isPresented: $renaming) {
            TextField("Name", text: $draft)
            Button("Rename") { if let id = current?.id { model.renameProfile(id, to: draft) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// Whether the highlight is on, and what viewers can see. At the bottom of the sidebar on every page.
struct StatusBlock: View {
    @EnvironmentObject private var model: AppModel
    @State private var open = false

    var body: some View {
        let on = model.isOn(.highlight)
        let info = ShareStatusInfo(model.shareStatus)
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Toggle(isOn: Binding(get: { on }, set: { _ in model.toggle(.highlight) })) {
                Text("Highlight").font(.system(size: 13))
            }
            .toggleStyle(.switch)
            Button { open.toggle() } label: {
                HStack(spacing: 6) {
                    Circle().fill(info.tint).frame(width: 7, height: 7)
                    Text(info.pill).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $open, arrowEdge: .trailing) {
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
        .padding(.horizontal, 14).padding(.bottom, 12)
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
