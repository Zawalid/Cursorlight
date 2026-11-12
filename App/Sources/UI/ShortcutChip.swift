import AppKit
import BeaconCore
import SwiftUI

/// The shortcut for what the canvas is showing, read from the real settings: Toggle highlight on Look, Toggle ink on
/// Draw. The keys press down while you hold them in this window, so it doubles as a way to learn the shortcut.
/// Clicking it opens the Keys page, where the shortcuts can be changed.
struct ShortcutChip: View {
    @EnvironmentObject private var model: AppModel
    let action: HotKeyAction
    let openKeys: () -> Void
    @StateObject private var watcher = KeyPressWatcher()

    var body: some View {
        let triggers = model.settings.triggers
        let key = triggers.hotkey(for: action)
        let caps = key == nil ? [] : TriggersPage.caps(for: key)
        let enabled = triggers.hotkeysEnabled && key != nil
        let down = enabled && !caps.isEmpty && caps.allSatisfy { watcher.held.contains($0.uppercased()) }
        Button(action: openKeys) {
            CanvasChip {
                HStack(spacing: 9) {
                    Text(enabled ? action.displayName : "No shortcut")
                        .foregroundStyle(Color.white.opacity(0.62))
                    if enabled {
                        HStack(spacing: 3) {
                            ForEach(caps, id: \.self) { cap in
                                MiniKey(text: cap, pressed: watcher.held.contains(cap.uppercased()))
                            }
                        }
                    }
                }
            }
            .overlay(Capsule().stroke(Theme.accent.opacity(down ? 0.9 : 0), lineWidth: 1.5))
            .animation(.easeOut(duration: 0.12), value: down)
        }
        .buttonStyle(.plain)
        .help(enabled ? "\(action.displayName) works in every app. Click to change it." : "Shortcuts are off. Click to turn them on in Keys.")
        .accessibilityLabel(enabled ? "\(action.displayName), shortcut \(caps.joined(separator: " "))" : "No shortcut set")
        .onAppear { watcher.start() }
        .onDisappear { watcher.stop() }
    }
}

/// A small keycap that sinks and lights up while its key is held.
struct MiniKey: View {
    let text: String
    let pressed: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(pressed ? Color.white : Color.white.opacity(0.9))
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(pressed ? Theme.accent : Color.white.opacity(0.11))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(pressed ? 0.0 : 0.16), lineWidth: 1)
            )
            .offset(y: pressed ? 1 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// Watches the keys held while this app is in front. It sees only events delivered to Beacon itself, so it needs no
/// permission. It reads key characters only from key events, never from mouse events.
@MainActor
final class KeyPressWatcher: ObservableObject {
    @Published private(set) var held: Set<String> = []
    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            let type = event.type
            let flags = event.modifierFlags
            let isKey = type == .keyDown || type == .keyUp
            let character = isKey ? event.charactersIgnoringModifiers?.uppercased() : nil
            let repeated = type == .keyDown && event.isARepeat
            MainActor.assumeIsolated { self?.handle(type: type, flags: flags, character: character, repeated: repeated) }
            return event
        }
        resignObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.held = [] }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        monitor = nil
        resignObserver = nil
        held = []
    }

    private func handle(type: NSEvent.EventType, flags: NSEvent.ModifierFlags, character: String?, repeated: Bool) {
        var next = held.filter { !"⌃⌥⇧⌘".contains($0) }
        if flags.contains(.control) { next.insert("⌃") }
        if flags.contains(.option) { next.insert("⌥") }
        if flags.contains(.shift) { next.insert("⇧") }
        if flags.contains(.command) { next.insert("⌘") }
        if let character, !character.isEmpty, !repeated {
            if type == .keyDown { next.insert(character) } else { next.remove(character) }
        }
        if next != held { held = next }
    }
}
