import AppKit
import Foundation

/// Where the keystroke display sits on the main display.
public enum KeystrokePosition: String, CaseIterable, Codable, Sendable {
    case bottomCenter, bottomLeft, bottomRight

    public var displayName: String {
        switch self {
        case .bottomCenter: "Bottom center"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }
}

/// The keystroke display and what else listens to the keyboard. Everything here needs optional Input Monitoring.
public struct KeystrokeSettings: Codable, Equatable, Sendable {
    public var enabled = false
    /// Only show shortcuts such as ⌘K, not every letter typed.
    public var shortcutsOnly = true
    public var position: KeystrokePosition = .bottomCenter
    /// A soft tick on every key press.
    public var sound = false

    public init() {}

    private enum CodingKeys: String, CodingKey { case enabled, shortcutsOnly, position, sound }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KeystrokeSettings()
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? d.enabled
        shortcutsOnly = (try? c.decode(Bool.self, forKey: .shortcutsOnly)) ?? d.shortcutsOnly
        position = (try? c.decode(KeystrokePosition.self, forKey: .position)) ?? d.position
        sound = (try? c.decode(Bool.self, forKey: .sound)) ?? d.sound
    }
}

/// One key press, copied out of an event so it can cross to the main actor.
public struct KeyPress: Equatable, Sendable {
    public var keyCode: UInt16
    public var flags: UInt
    public var characters: String
    public var isRepeat: Bool

    public init(keyCode: UInt16, flags: UInt, characters: String, isRepeat: Bool = false) {
        self.keyCode = keyCode
        self.flags = flags
        self.characters = characters
        self.isRepeat = isRepeat
    }
}

public enum KeystrokeFormatter {
    private static let control: UInt = 1 << 18, option: UInt = 1 << 19, shift: UInt = 1 << 17, command: UInt = 1 << 20

    private static let names: [UInt16: String] = [
        36: "Return", 76: "Enter", 48: "Tab", 49: "Space", 51: "Delete", 117: "Fwd Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑", 116: "Page Up", 121: "Page Down", 115: "Home", 119: "End",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
    ]

    public static func isShortcut(_ press: KeyPress) -> Bool {
        press.flags & (control | option | command) != 0
    }

    /// The key as it should be shown: modifiers first (⌃⌥⇧⌘), then the key. nil when there is nothing to show.
    public static func label(for press: KeyPress) -> String? {
        var text = ""
        if press.flags & control != 0 { text += "⌃" }
        if press.flags & option != 0 { text += "⌥" }
        if press.flags & shift != 0 { text += "⇧" }
        if press.flags & command != 0 { text += "⌘" }
        let key = names[press.keyCode] ?? press.characters.uppercased()
        guard !key.isEmpty else { return nil }
        return isShortcut(press) || key.count > 1 ? text + (text.isEmpty ? "" : " ") + key : key
    }

    /// The character a plain key types, for joining into words.
    public static func typedCharacter(for press: KeyPress) -> String? {
        guard !isShortcut(press), names[press.keyCode] == nil, press.characters.count == 1,
              let scalar = press.characters.unicodeScalars.first, !CharacterSet.controlCharacters.contains(scalar) else { return nil }
        return press.characters
    }
}

/// What the keystroke display shows right now: shortcuts as chips, plain typing joined into a growing word.
public struct KeystrokeBuffer: Equatable, Sendable {
    public struct Entry: Equatable, Sendable, Identifiable {
        public var id: Int
        public var text: String
        public var isCombo: Bool
        public var time: TimeInterval
    }

    public static let lifetime: TimeInterval = 1.8
    public static let maxEntries = 4
    public static let maxWordLength = 28

    public private(set) var entries: [Entry] = []
    private var nextID = 0

    public init() {}

    /// Adds a key press. In shortcuts-only mode, plain typing is ignored.
    public mutating func push(_ press: KeyPress, shortcutsOnly: Bool, at time: TimeInterval) {
        guard !press.isRepeat || KeystrokeFormatter.isShortcut(press) == false else { return }
        let shortcut = KeystrokeFormatter.isShortcut(press)
        if shortcutsOnly, !shortcut { return }
        prune(at: time)
        if !shortcut, let typed = KeystrokeFormatter.typedCharacter(for: press), let last = entries.last, !last.isCombo,
           last.text.count < Self.maxWordLength, time - last.time < Self.lifetime {
            entries[entries.count - 1].text += typed
            entries[entries.count - 1].time = time
            return
        }
        guard let label = KeystrokeFormatter.label(for: press) else { return }
        let word = KeystrokeFormatter.typedCharacter(for: press) != nil
        entries.append(Entry(id: nextID, text: word ? (press.characters) : label, isCombo: shortcut || !word, time: time))
        nextID += 1
        if entries.count > Self.maxEntries { entries.removeFirst(entries.count - Self.maxEntries) }
    }

    /// Entries still on screen, with how visible each is (1 fully, fading to 0 over the last third).
    public func visible(at time: TimeInterval) -> [(entry: Entry, opacity: Double)] {
        entries.compactMap { entry in
            let age = time - entry.time
            guard age < Self.lifetime else { return nil }
            let fadeStart = Self.lifetime * 2 / 3
            return (entry, age <= fadeStart ? 1 : max(0, 1 - (age - fadeStart) / (Self.lifetime - fadeStart)))
        }
    }

    public mutating func prune(at time: TimeInterval) {
        entries.removeAll { time - $0.time >= Self.lifetime }
    }

    public mutating func clear() { entries.removeAll() }
}

/// Listens to key presses in every app once Input Monitoring is granted, and in Beacon's own windows always. Secure
/// text fields such as passwords never reach it: the system withholds those keys.
@MainActor
public final class KeyActivityMonitor {
    public var onKey: ((KeyPress) -> Void)?
    public var hasGlobalAccess: Bool { globalMonitor != nil }
    private var globalMonitor: Any?
    private var localMonitor: Any?

    public init() {}

    public func start() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let press = Self.press(event)
                MainActor.assumeIsolated { self?.onKey?(press) }
                return event
            }
        }
        refreshAccess()
    }

    public func refreshAccess() {
        guard globalMonitor == nil, InputMonitoring.isGranted else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let press = Self.press(event)
            Task { @MainActor in self?.onKey?(press) }
        }
    }

    public func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private static func press(_ event: NSEvent) -> KeyPress {
        KeyPress(
            keyCode: event.keyCode, flags: event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue,
            characters: event.charactersIgnoringModifiers ?? "", isRepeat: event.isARepeat
        )
    }
}
