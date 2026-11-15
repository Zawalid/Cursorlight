import CursorlightCore
import SwiftUI

/// The scenes as a strip of cards under the canvas. Each card draws the scene's real look: its style in its own color,
/// scaled by its size, with a dot for the pen color and a badge when apps are linked to it. Click to switch, drag to
/// reorder, double-click the name to rename, and the menu on a card holds the rest.
struct SceneStrip: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingID: String?
    @State private var draft = ""
    @State private var dropTarget: String?
    @State private var endTargeted = false
    @State private var deleting: Profile?
    @State private var importError: String?
    @FocusState private var nameFocused: Bool

    private let spring = Animation.spring(response: 0.3, dampingFraction: 0.86)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(model.profiles) { profile in
                            card(for: profile).id(profile.id)
                                .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                        addCard.id("new-scene")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .animation(spring, value: model.profiles.map(\.id))
                }
                .mask(edgeFade)
                .onChange(of: model.appliedProfileID) { _, id in
                    withAnimation(spring) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.35))
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
        .confirmationDialog(
            "Delete \(deleting?.name ?? "scene")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { if let id = deleting?.id { model.deleteProfile(id) }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Apps set to use it go back to the default scene.")
        }
    }

    /// Soft edges so cards slide out of view instead of being cut.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 14)
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 14)
        }
    }

    // MARK: Cards

    @ViewBuilder
    private func card(for profile: Profile) -> some View {
        let on = model.appliedProfileID == profile.id
        let linked = model.settings.appRules.filter { $0.profileID == profile.id }
        VStack(spacing: 7) {
            SceneCard(profile: profile, selected: on, linkedApps: linked.map(\.appName), onMenu: { menu(for: profile) }) {
                model.chooseProfile(profile.id)
            }
            if editingID == profile.id {
                TextField("Name", text: $draft)
                    .textFieldStyle(.plain).multilineTextAlignment(.center)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.vertical, 1).padding(.horizontal, 4)
                    .frame(width: SceneCard.width)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .focused($nameFocused)
                    .onSubmit(commitRename)
                    .onExitCommand { editingID = nil }
                    .onAppear { nameFocused = true }
                    .onChange(of: nameFocused) { _, focused in if !focused { commitRename() } }
            } else {
                Text(profile.name)
                    .font(.system(size: 11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Color.white : Color.white.opacity(0.6))
                    .lineLimit(1).frame(width: SceneCard.width)
                    .padding(.vertical, 1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { beginRename(profile) }
                    .onTapGesture { model.chooseProfile(profile.id) }
            }
        }
        .overlay(alignment: .leading) {
            Capsule().fill(Theme.accent).frame(width: 3, height: SceneCard.height)
                .offset(x: -8).opacity(dropTarget == profile.id ? 1 : 0)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .contextMenu { menu(for: profile) }
        .draggable(profile.id)
        .dropDestination(for: String.self) { ids, _ in
            guard let moved = ids.first else { return false }
            withAnimation(spring) { model.moveProfile(moved, before: profile.id) }
            return true
        } isTargeted: { targeted in
            dropTarget = targeted ? profile.id : (dropTarget == profile.id ? nil : dropTarget)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Scene \(profile.name)")
    }

    @ViewBuilder
    private func menu(for profile: Profile) -> some View {
        Button("Rename") { beginRename(profile) }
        Button("Duplicate") { model.duplicateProfile(profile.id) }
        Button("Export…") { model.exportScene(profile) }
        if model.profiles.count > 1 {
            Divider()
            Button("Delete…", role: .destructive) { deleting = profile }
        }
    }

    private var addCard: some View {
        Menu {
            Button("Save the current look as a scene") {
                model.addProfile()
                beginRename(model.profiles.first { $0.id == model.appliedProfileID })
            }
            Menu("Add a preset") {
                ForEach(ScenePresets.all, id: \.key) { preset in
                    Button {
                        model.addPreset(preset)
                    } label: {
                        Label {
                            Text("\(preset.name): \(preset.detail)")
                        } icon: {
                            Image(nsImage: MenuThumbnail.style(preset.snapshot.highlightStyle, tint: Color(rgba: Profile(id: "p", name: "p", snapshot: preset.snapshot).highlightColor)))
                        }
                    }
                }
            }
            Divider()
            Button("Import a scene file…") { importError = model.importScene() }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 14, weight: .medium))
                    .frame(width: SceneCard.width, height: SceneCard.height)
                    .background(Color.white.opacity(endTargeted ? 0.07 : 0), in: RoundedRectangle(cornerRadius: SceneCard.radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SceneCard.radius, style: .continuous)
                            .stroke(Color.white.opacity(endTargeted ? 0.4 : 0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
                Text("New scene").font(.system(size: 11)).padding(.vertical, 1)
            }
            .foregroundStyle(Color.white.opacity(endTargeted ? 0.9 : 0.55))
            .contentShape(Rectangle())
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .help("Save the current look, add a preset, or import a scene file. Drop a card here to move it to the end.")
        .dropDestination(for: String.self) { ids, _ in
            guard let moved = ids.first else { return false }
            withAnimation(spring) { model.moveProfile(moved, before: nil) }
            return true
        } isTargeted: { endTargeted = $0 }
        .alert("Could not import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: Renaming

    private func beginRename(_ profile: Profile?) {
        guard let profile else { return }
        draft = profile.name
        editingID = profile.id
    }

    private func commitRename() {
        guard let id = editingID else { return }
        editingID = nil
        model.renameProfile(id, to: draft)
    }
}

/// One scene: the thumbnail card. The name sits under it, owned by the strip so it can be edited in place.
private struct SceneCard: View {
    static let width: CGFloat = 116
    static let height: CGFloat = 70
    static let radius: CGFloat = 11

    let profile: Profile
    let selected: Bool
    let linkedApps: [String]
    let onMenu: () -> AnyView
    let action: () -> Void

    @State private var hovered = false

    init(profile: Profile, selected: Bool, linkedApps: [String], onMenu: @escaping () -> some View, action: @escaping () -> Void) {
        self.profile = profile
        self.selected = selected
        self.linkedApps = linkedApps
        self.onMenu = { AnyView(onMenu()) }
        self.action = action
    }

    var body: some View {
        let accent = Color(rgba: profile.highlightColor)
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        Button(action: action) {
            ZStack {
                StyleThumbnail(style: profile.snapshot.highlightStyle, color: accent, scale: thumbnailScale)
                    .opacity(0.55 + 0.45 * min(max(profile.snapshot.highlightIntensity, 0), 1))
                    .frame(width: Self.width, height: Self.height)
                    .clipShape(shape)
            }
            .frame(width: Self.width, height: Self.height)
            .background(shape.fill(selected ? accent.opacity(0.09) : Color.white.opacity(hovered ? 0.085 : 0.05)))
            .overlay(shape.stroke(selected ? accent : Color.white.opacity(hovered ? 0.2 : 0.11), lineWidth: selected ? 1.5 : 1))
            .shadow(color: selected ? accent.opacity(0.35) : .clear, radius: 9)
            .overlay(alignment: .bottomTrailing) { penDot }
            .overlay(alignment: .topLeading) { linkBadge }
            .overlay(alignment: .topTrailing) { menuButton }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.14), value: hovered)
        .animation(.easeOut(duration: 0.2), value: selected)
        .help(helpText)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Switch to this scene")
    }

    private var thumbnailScale: CGFloat {
        CGFloat(min(max(profile.snapshot.highlightSize, 0.7), 1.4)) * 0.95
    }

    /// The pen color of the scene, so Draw looks are visible at a glance.
    private var penDot: some View {
        Circle().fill(Color(rgba: profile.penColor))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
            .padding(7)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var linkBadge: some View {
        if !linkedApps.isEmpty {
            HStack(spacing: 3) {
                Image(systemName: "app.badge")
                Text("\(linkedApps.count)")
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.75))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.white.opacity(0.1), in: Capsule())
            .padding(6)
            .accessibilityLabel("\(linkedApps.count) apps use this scene")
        }
    }

    @ViewBuilder
    private var menuButton: some View {
        if hovered {
            Menu { onMenu() } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(Color.black.opacity(0.45), in: Circle())
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .fixedSize()
            .padding(5)
            .transition(.opacity)
        }
    }

    private var helpText: String {
        var parts = [profile.summary, "pen \(profile.snapshot.inkColor.displayName.lowercased())"]
        if !linkedApps.isEmpty { parts.append("used in " + linkedApps.joined(separator: ", ")) }
        return "\(profile.name): " + parts.joined(separator: ", ")
    }
}
