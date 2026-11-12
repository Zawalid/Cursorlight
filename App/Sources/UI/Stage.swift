import BeaconCore
import SwiftUI

/// The top of the window: a miniature desktop that runs the effect you are editing. Move the real mouse over it and the
/// effect follows it; leave it and a looping pointer takes over. Three small chips float on it: the scene, the share
/// status and whether the highlight is on.
struct Stage: View {
    @EnvironmentObject private var model: AppModel
    let style: HighlightStyle
    let look: HighlightLook
    @State private var hover: CGPoint?
    @State private var history = PreviewCanvas.PointerHistory()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                PreviewCanvas.draw(
                    &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate, style: style, look: look,
                    pointer: hover, history: history
                )
            }
        }
        .background(Theme.stage)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.3), lineWidth: 0.5))
        .overlay(alignment: .topLeading) { SceneChip().padding(24) }
        .overlay(alignment: .topTrailing) { ShareChip().padding(24) }
        .overlay(alignment: .bottomLeading) { OnChip().padding(14) }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) { Keycap(text: "⌃", dark: true); Keycap(text: "⌥", dark: true); Keycap(text: "H", dark: true) }
                .padding(14)
        }
        .onContinuousHover { phase in
            switch phase {
            case let .active(point): hover = point
            case .ended: hover = nil
            }
        }
        .accessibilityLabel("\(style.displayName) preview")
    }
}

/// Dark glass chip used on the Stage.
struct StageChip<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 12).frame(height: 28)
            .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
            .background(Color.black.opacity(0.42), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            .environment(\.colorScheme, .dark)
    }
}

/// The current scene. Click to switch scenes, make a new one from the current look, rename or delete.
struct SceneChip: View {
    @EnvironmentObject private var model: AppModel
    @State private var open = false
    @State private var renaming = false
    @State private var draft = ""

    private var current: Profile? { model.profiles.first { $0.id == model.appliedProfileID } }

    var body: some View {
        Button { open.toggle() } label: {
            StageChip {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 11))
                    Text(current?.name ?? "Scene")
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).opacity(0.7)
                }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
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
                    menuButton("New scene from this look") { model.addProfile(); open = false }
                    menuButton("Rename \(current?.name ?? "scene")") { draft = current?.name ?? ""; renaming = true }
                    if model.profiles.count > 1, let id = current?.id {
                        menuButton("Delete \(current?.name ?? "scene")") { model.deleteProfile(id); open = false }
                    }
                }
            }
            .font(.system(size: 13))
            .padding(12).frame(width: 240)
        }
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5).padding(.horizontal, 8).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The share status, short. Click to say what you are sharing.
struct ShareChip: View {
    @EnvironmentObject private var model: AppModel
    @State private var open = false

    var body: some View {
        let info = ShareStatusInfo(model.shareStatus)
        Button { open.toggle() } label: {
            StageChip {
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
}

/// Whether the highlight is on right now. Click to turn it on or off.
struct OnChip: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let on = model.isOn(.highlight)
        Button { model.toggle(.highlight) } label: {
            StageChip {
                HStack(spacing: 7) {
                    Circle().fill(on ? Theme.accent : Color.white.opacity(0.4)).frame(width: 7, height: 7)
                        .shadow(color: on ? Theme.accent : .clear, radius: 4)
                    Text(on ? "Highlight is on" : "Highlight is off")
                }
            }
        }
        .buttonStyle(.plain)
        .help("Shake the pointer, or press Control Option H")
    }
}
