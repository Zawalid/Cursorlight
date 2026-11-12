import Foundation

/// The things a trigger can switch on.
public enum EffectKind: String, CaseIterable, Codable, Sendable {
    case highlight, laser, ink, none

    public var displayName: String {
        switch self {
        case .highlight: "Highlight"
        case .laser: "Laser"
        case .ink: "Ink"
        case .none: "Nothing"
        }
    }
}

/// A modifier key, told apart left from right by its key code.
public enum ModifierKey: UInt16, CaseIterable, Codable, Sendable {
    case leftCommand = 55, rightCommand = 54
    case leftShift = 56, rightShift = 60
    case leftOption = 58, rightOption = 61
    case leftControl = 59, rightControl = 62

    public var displayName: String {
        switch self {
        case .leftCommand: "Left Command"
        case .rightCommand: "Right Command"
        case .leftShift: "Left Shift"
        case .rightShift: "Right Shift"
        case .leftOption: "Left Option"
        case .rightOption: "Right Option"
        case .leftControl: "Left Control"
        case .rightControl: "Right Control"
        }
    }

    /// The device-independent modifier flag bit that this key sets (NSEvent.ModifierFlags raw values).
    var flag: UInt {
        switch self {
        case .leftShift, .rightShift: 1 << 17
        case .leftControl, .rightControl: 1 << 18
        case .leftOption, .rightOption: 1 << 19
        case .leftCommand, .rightCommand: 1 << 20
        }
    }

    static let allFlags: UInt = (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)
}

/// A global shortcut registered the Carbon way, which needs no permission. Modifiers use Carbon's masks.
public struct HotKey: Codable, Equatable, Sendable {
    public static let command: UInt32 = 256
    public static let shift: UInt32 = 512
    public static let option: UInt32 = 2048
    public static let control: UInt32 = 4096

    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var displayString: String {
        var text = ""
        if modifiers & Self.control != 0 { text += "⌃" }
        if modifiers & Self.option != 0 { text += "⌥" }
        if modifiers & Self.shift != 0 { text += "⇧" }
        if modifiers & Self.command != 0 { text += "⌘" }
        return text + (Self.keyNames[keyCode] ?? "key \(keyCode)")
    }

    private static let keyNames: [UInt32: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M",
        45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc", 123: "Left", 124: "Right", 125: "Down", 126: "Up",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        27: "-", 24: "=", 33: "[", 30: "]", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 42: "\\", 50: "`",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
    ]

    private static let functionKeys: Set<UInt32> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    /// Builds a shortcut from a key press: the key code and `NSEvent.ModifierFlags` raw bits. nil when the combination
    /// would hijack normal typing: it needs Control, Option or Command, unless it is a function key.
    public static func from(keyCode: UInt16, cocoaModifiers: UInt) -> HotKey? {
        var mods: UInt32 = 0
        if cocoaModifiers & (1 << 18) != 0 { mods |= control }
        if cocoaModifiers & (1 << 19) != 0 { mods |= option }
        if cocoaModifiers & (1 << 17) != 0 { mods |= shift }
        if cocoaModifiers & (1 << 20) != 0 { mods |= command }
        let key = UInt32(keyCode)
        guard keyNames[key] != nil else { return nil }
        let strong = mods & (control | option | command) != 0
        guard strong || functionKeys.contains(key) else { return nil }
        return HotKey(keyCode: key, modifiers: mods)
    }
}

/// What a global shortcut does.
public enum HotKeyAction: String, CaseIterable, Codable, Sendable {
    case highlight, laser, ink, pause, nextScene, clearInk, toggleToolbar, spotlight, whiteboard

    public var displayName: String {
        switch self {
        case .highlight: "Toggle highlight"
        case .laser: "Toggle laser"
        case .ink: "Toggle ink"
        case .pause: "Pause or resume"
        case .nextScene: "Next scene"
        case .clearInk: "Clear drawings"
        case .toggleToolbar: "Show or hide the bar"
        case .spotlight: "Spotlight a region"
        case .whiteboard: "Whiteboard"
        }
    }
}

/// How the user summons effects. Defaults: shake toggles the highlight, double-tap Left Option toggles the laser,
/// holding Right Option draws ink. The modifier gestures need Input Monitoring; the shortcuts and shake do not.
public struct TriggerSettings: Codable, Equatable, Sendable {
    public var shakeEnabled = true
    public var shakeAction: EffectKind = .highlight
    public var doubleTapEnabled = true
    public var doubleTapKey: ModifierKey = .leftOption
    public var doubleTapAction: EffectKind = .laser
    public var holdEnabled = true
    public var holdKey: ModifierKey = .rightOption
    public var holdAction: EffectKind = .ink
    public var hotkeysEnabled = true
    public var hotkeys: [String: HotKey] = Self.defaultHotkeys

    public static let defaultHotkeys: [String: HotKey] = {
        let mods = HotKey.control | HotKey.option
        return [
            HotKeyAction.highlight.rawValue: HotKey(keyCode: 4, modifiers: mods),
            HotKeyAction.laser.rawValue: HotKey(keyCode: 37, modifiers: mods),
            HotKeyAction.ink.rawValue: HotKey(keyCode: 34, modifiers: mods),
            HotKeyAction.pause.rawValue: HotKey(keyCode: 35, modifiers: mods),
            HotKeyAction.nextScene.rawValue: HotKey(keyCode: 45, modifiers: mods),
            HotKeyAction.clearInk.rawValue: HotKey(keyCode: 7, modifiers: mods),
            HotKeyAction.toggleToolbar.rawValue: HotKey(keyCode: 11, modifiers: mods),
            HotKeyAction.spotlight.rawValue: HotKey(keyCode: 1, modifiers: mods),
            HotKeyAction.whiteboard.rawValue: HotKey(keyCode: 13, modifiers: mods),
        ]
    }()

    public static let defaults = TriggerSettings()

    public init() {}

    public func hotkey(for action: HotKeyAction) -> HotKey? { hotkeys[action.rawValue] }

    /// Another action that already uses `key`, if any.
    public func conflict(for key: HotKey, excluding action: HotKeyAction) -> HotKeyAction? {
        HotKeyAction.allCases.first { $0 != action && hotkeys[$0.rawValue] == key }
    }

    private enum CodingKeys: String, CodingKey {
        case shakeEnabled, shakeAction, doubleTapEnabled, doubleTapKey, doubleTapAction
        case holdEnabled, holdKey, holdAction, hotkeysEnabled, hotkeys
    }

    /// Tolerant: a missing or unreadable field takes its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TriggerSettings()
        shakeEnabled = (try? c.decode(Bool.self, forKey: .shakeEnabled)) ?? d.shakeEnabled
        shakeAction = (try? c.decode(EffectKind.self, forKey: .shakeAction)) ?? d.shakeAction
        doubleTapEnabled = (try? c.decode(Bool.self, forKey: .doubleTapEnabled)) ?? d.doubleTapEnabled
        doubleTapKey = (try? c.decode(ModifierKey.self, forKey: .doubleTapKey)) ?? d.doubleTapKey
        doubleTapAction = (try? c.decode(EffectKind.self, forKey: .doubleTapAction)) ?? d.doubleTapAction
        holdEnabled = (try? c.decode(Bool.self, forKey: .holdEnabled)) ?? d.holdEnabled
        holdKey = (try? c.decode(ModifierKey.self, forKey: .holdKey)) ?? d.holdKey
        holdAction = (try? c.decode(EffectKind.self, forKey: .holdAction)) ?? d.holdAction
        hotkeysEnabled = (try? c.decode(Bool.self, forKey: .hotkeysEnabled)) ?? d.hotkeysEnabled
        hotkeys = (try? c.decode([String: HotKey].self, forKey: .hotkeys)) ?? d.hotkeys
    }
}

public enum TriggerEvent: Equatable, Sendable {
    case shake
    case doubleTap(ModifierKey)
    case holdBegan(ModifierKey)
    case holdEnded(ModifierKey)
    case hotkey(HotKeyAction)
}

public enum TriggerCommand: Equatable, Sendable {
    case toggle(EffectKind)
    case set(EffectKind, Bool)
    case togglePause
    case nextScene
    case clearInk
    case toggleToolbar
    case spotlight
    case whiteboard
}

/// Which effects are running right now; the router uses it to keep drawing from setting off the shake.
public struct ActiveEffects: Equatable, Sendable {
    public var inkActive = false
    public var laserOn = false
    public init(inkActive: Bool = false, laserOn: Bool = false) {
        self.inkActive = inkActive
        self.laserOn = laserOn
    }
}

/// Turns trigger events into commands. Pure: no permission checks of its own; the caller only feeds modifier
/// events when Input Monitoring is granted.
public struct TriggerRouter: Equatable, Sendable {
    public var settings: TriggerSettings
    public var isPaused = false

    public init(settings: TriggerSettings) {
        self.settings = settings
    }

    public func route(_ event: TriggerEvent, active: ActiveEffects) -> [TriggerCommand] {
        // The pause shortcut works while paused; everything else is ignored.
        if case .hotkey(.pause) = event, settings.hotkeysEnabled { return [.togglePause] }
        guard !isPaused else { return [] }
        switch event {
        case .shake:
            // Drawing and laser pointing shake the mouse on purpose; that must not toggle the highlight.
            guard settings.shakeEnabled, !active.inkActive, !active.laserOn, settings.shakeAction != .none else { return [] }
            return [.toggle(settings.shakeAction)]
        case let .doubleTap(key):
            guard settings.doubleTapEnabled, key == settings.doubleTapKey, settings.doubleTapAction != .none else { return [] }
            return [.toggle(settings.doubleTapAction)]
        case let .holdBegan(key):
            guard settings.holdEnabled, key == settings.holdKey, settings.holdAction != .none else { return [] }
            return [.set(settings.holdAction, true)]
        case let .holdEnded(key):
            // Always release what a hold started, even if the setting changed meanwhile.
            guard key == settings.holdKey, settings.holdAction != .none else { return [] }
            return [.set(settings.holdAction, false)]
        case let .hotkey(action):
            guard settings.hotkeysEnabled else { return [] }
            switch action {
            case .highlight: return [.toggle(.highlight)]
            case .laser: return [.toggle(.laser)]
            case .ink: return [.toggle(.ink)]
            case .pause: return [.togglePause]
            case .nextScene: return [.nextScene]
            case .clearInk: return [.clearInk]
            case .toggleToolbar: return [.toggleToolbar]
            case .spotlight: return [.spotlight]
            case .whiteboard: return [.whiteboard]
            }
        }
    }
}
