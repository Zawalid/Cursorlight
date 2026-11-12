import BeaconCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State var page: SettingsPage
    /// False only for offscreen snapshots, where ScrollView does not render.
    var scrolls = true

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(page: $page)
            Rectangle().fill(Theme.line).frame(width: 1)
            content
        }
        .frame(minWidth: 940, minHeight: 620)
        .background(Theme.window)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        if page == .highlight {
            LookPage()
                .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 28)
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
                .frame(maxWidth: 760, alignment: .topLeading)
                .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 32)
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

/// The left column: the scene, the sections, and the two things that belong to every page, whether Beacon is on and whether
/// viewers can see it.
struct Sidebar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var page: SettingsPage
    @State private var hovered: SettingsPage?
    private let sections: [SettingsPage] = [.highlight, .ink, .triggers, .profiles, .displays]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SceneMenu().padding(.top, 46)
            Text("SETTINGS")
                .font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(Theme.faint)
                .padding(.top, 22).padding(.bottom, 6).padding(.leading, 10)
            ForEach(sections) { item in row(item) }
            Spacer(minLength: 12)
            row(.about)
            StatusBlock().padding(.top, 10)
        }
        .padding(.horizontal, 12).padding(.bottom, 14)
        .frame(width: 228)
        .frame(maxHeight: .infinity)
        .background(Theme.sidebar)
    }

    private func row(_ item: SettingsPage) -> some View {
        let on = page == item
        return Button { page = item } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol).font(.system(size: 13)).frame(width: 18)
                    .foregroundStyle(on ? Theme.accent : Theme.dim)
                Text(item.title).font(.system(size: 13, weight: on ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(on ? Theme.text : (hovered == item ? Theme.text : Theme.dim))
            .padding(.horizontal, 10).frame(height: 34)
            .background(on ? Theme.raised : (hovered == item ? Color.white.opacity(0.05) : .clear), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? item : (hovered == item ? nil : hovered) }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The current scene as one menu at the top of the sidebar.
struct SceneMenu: View {
    @EnvironmentObject private var model: AppModel
    @State private var open = false
    @State private var renaming = false
    @State private var draft = ""

    private var current: Profile? { model.profiles.first { $0.id == model.appliedProfileID } }

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 10) {
                BrandMark().frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Scene").font(.system(size: 10)).foregroundStyle(Theme.faint)
                    Text(current?.name ?? "Stream").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 10).frame(height: 46)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCENES").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary).padding(.bottom, 4)
                ForEach(model.profiles) { profile in
                    Button { model.chooseProfile(profile.id); open = false } label: {
                        HStack {
                            Text(profile.name)
                            Spacer(minLength: 20)
                            if profile.id == model.appliedProfileID { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)) }
                        }
                        .padding(.vertical, 5).padding(.horizontal, 8).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Divider().padding(.vertical, 4)
                if renaming {
                    TextField("Name", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if let id = current?.id { model.renameProfile(id, to: draft) }
                            renaming = false
                        }
                } else {
                    item("New scene from this look") { model.addProfile(); open = false }
                    item("Rename \(current?.name ?? "scene")") { draft = current?.name ?? ""; renaming = true }
                    if model.profiles.count > 1, let id = current?.id {
                        item("Delete \(current?.name ?? "scene")") { model.deleteProfile(id); open = false }
                    }
                }
            }
            .font(.system(size: 13))
            .padding(12).frame(width: 240)
        }
    }

    private func item(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5).padding(.horizontal, 8).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Whether the highlight is on, with a switch, and what viewers can see. At the bottom of the sidebar on every page.
struct StatusBlock: View {
    @EnvironmentObject private var model: AppModel
    @State private var open = false

    var body: some View {
        let on = model.isOn(.highlight)
        let info = ShareStatusInfo(model.shareStatus)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(on ? Theme.accent : Theme.faint).frame(width: 7, height: 7)
                    .shadow(color: on ? Theme.accent.opacity(0.9) : .clear, radius: 4)
                Text(on ? "Highlight on" : "Highlight off").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                Spacer()
                Toggle("", isOn: Binding(get: { on }, set: { _ in model.toggle(.highlight) }))
                    .toggleStyle(.switch).labelsHidden().controlSize(.small).tint(Theme.accent)
            }
            .padding(.horizontal, 10).frame(height: 38)
            Rectangle().fill(Theme.line).frame(height: 1)
            Button { open.toggle() } label: {
                HStack(spacing: 8) {
                    Circle().fill(info.chipTint).frame(width: 7, height: 7)
                    Text(info.pill).font(.system(size: 12)).foregroundStyle(Theme.dim).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 10).frame(height: 34).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $open, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(info.title).font(.system(size: 13, weight: .semibold))
                    Text(info.body).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text("I am sharing").font(.system(size: 11)).foregroundStyle(.tertiary)
                    Picker("", selection: Binding(get: { model.declaredShare }, set: { model.declareShare($0); open = false })) {
                        Text("Nothing").tag(DeclaredShare?.some(.notSharing))
                        Text("Screen").tag(DeclaredShare?.some(.wholeScreen))
                        Text("A window").tag(DeclaredShare?.some(.singleWindow))
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                .padding(14).frame(width: 280)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.line))
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
