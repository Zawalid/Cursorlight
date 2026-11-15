import Foundation

/// Recognizes a double-tap and a hold of a lone modifier key. Pure: the caller passes event times, and a timer
/// calls `tick` at `holdDeadline`. A modifier used as part of a shortcut (another key or a click while it is
/// pressed, or another modifier already down) is never a gesture.
public struct ModifierGestureRecognizer: Equatable, Sendable {
    public var holdThreshold: TimeInterval = 0.3
    public var doubleTapWindow: TimeInterval = 0.35

    private var down: Set<ModifierKey> = []
    private var pending: (key: ModifierKey, time: TimeInterval)?
    private var holding: ModifierKey?
    private var lastTap: (key: ModifierKey, time: TimeInterval)?

    public init() {}

    public static func == (a: Self, b: Self) -> Bool {
        a.down == b.down && a.holding == b.holding && a.pending?.key == b.pending?.key && a.pending?.time == b.pending?.time
            && a.lastTap?.key == b.lastTap?.key && a.lastTap?.time == b.lastTap?.time
            && a.holdThreshold == b.holdThreshold && a.doubleTapWindow == b.doubleTapWindow
    }

    /// When `tick` should be called next, or nil when nothing is waiting.
    public var holdDeadline: TimeInterval? { pending.map { $0.time + holdThreshold } }
    public var isHolding: Bool { holding != nil }

    /// A modifier key changed. `flags` is the event's device-independent modifier flag set (raw).
    public mutating func flagsChanged(keyCode: UInt16, flags: UInt, time: TimeInterval) -> [TriggerEvent] {
        guard let key = ModifierKey(rawValue: keyCode) else { return [] }
        // Each event is one transition; the flag lets us recover if an earlier event was missed.
        let isDown = (flags & key.flag != 0) && !down.contains(key)
        if !isDown { down.remove(key) } else { down.insert(key) }

        if isDown {
            // A shortcut: some other modifier is already down.
            let others = down.subtracting([key]).filter { $0.flag != key.flag }
            if !others.isEmpty || holding != nil {
                pending = nil
                lastTap = nil
                return []
            }
            pending = (key, time)
            return []
        }

        if holding == key {
            holding = nil
            return [.holdEnded(key)]
        }
        guard let started = pending, started.key == key else { return [] }
        pending = nil
        guard time - started.time < holdThreshold else { return [] }
        if let previous = lastTap, previous.key == key, time - previous.time <= doubleTapWindow {
            lastTap = nil
            return [.doubleTap(key)]
        }
        lastTap = (key, time)
        return []
    }

    /// A key (not a modifier) or a mouse button went down: the pending modifier was part of a shortcut or a click.
    /// A hold already running is left alone, so drawing with the mouse while holding keeps working.
    public mutating func otherInput() {
        pending = nil
        lastTap = nil
    }

    /// Call at `holdDeadline`.
    public mutating func tick(time: TimeInterval) -> [TriggerEvent] {
        guard let started = pending, time - started.time >= holdThreshold else { return [] }
        pending = nil
        lastTap = nil
        holding = started.key
        return [.holdBegan(started.key)]
    }

    /// Forgets everything, for when monitoring stops or restarts. Returns a release if a hold was running.
    public mutating func reset() -> [TriggerEvent] {
        let release: [TriggerEvent] = holding.map { [.holdEnded($0)] } ?? []
        self = ModifierGestureRecognizer()
        return release
    }
}
