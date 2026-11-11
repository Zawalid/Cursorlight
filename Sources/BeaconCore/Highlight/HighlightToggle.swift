import Foundation

/// On/off state of the highlight with its entrance and exit. A shake toggles it; nothing turns it off on its own.
public struct HighlightToggle: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case off
        /// Entrance running since `start`.
        case appearing(start: TimeInterval)
        /// Fully shown. Keeps the entrance start so the summon pulse can outlive the entrance.
        case on(appearedAt: TimeInterval)
        /// Exit running since `start`, from visible level `from`.
        case disappearing(start: TimeInterval, from: Double)
    }

    public private(set) var phase: Phase = .off
    public var appearDuration: TimeInterval
    public var disappearDuration: TimeInterval

    public init(appearDuration: TimeInterval, disappearDuration: TimeInterval) {
        self.appearDuration = max(appearDuration, 0.001)
        self.disappearDuration = max(disappearDuration, 0.001)
    }

    /// The logical state: true from the moment it is turned on until it is turned off.
    public var isOn: Bool {
        switch phase {
        case .appearing, .on: true
        case .off, .disappearing: false
        }
    }

    /// Anything on screen (including a running exit).
    public var isVisible: Bool { phase != .off }

    /// Start time of the current entrance, while on.
    public var appearStart: TimeInterval? {
        switch phase {
        case .appearing(let start), .on(let start): start
        case .off, .disappearing: nil
        }
    }

    public var isAnimating: Bool {
        switch phase {
        case .appearing, .disappearing: true
        case .off, .on: false
        }
    }

    public mutating func toggle(at time: TimeInterval) {
        if isOn { turnOff(at: time) } else { turnOn(at: time) }
    }

    public mutating func turnOn(at time: TimeInterval) {
        guard !isOn else { return }
        phase = .appearing(start: time)
    }

    public mutating func turnOff(at time: TimeInterval) {
        guard isOn else { return }
        phase = .disappearing(start: time, from: level(at: time))
    }

    /// Replays the entrance (used when the style changes while on, so the new look is introduced).
    public mutating func replayEntrance(at time: TimeInterval) {
        guard isOn else { return }
        phase = .appearing(start: time)
    }

    /// Moves finished transitions to their resting phase.
    public mutating func advance(to time: TimeInterval) {
        switch phase {
        case .appearing(let start) where time - start >= appearDuration - 1e-9:
            phase = .on(appearedAt: start)
        case .disappearing(let start, _) where time - start >= disappearDuration - 1e-9:
            phase = .off
        default:
            break
        }
    }

    /// Normalized progress of the running transition (entrance or exit), 0...1.
    public func progress(at time: TimeInterval) -> Double {
        switch phase {
        case .appearing(let start): min(max((time - start) / appearDuration, 0), 1)
        case .disappearing(let start, _): min(max((time - start) / disappearDuration, 0), 1)
        case .on: 1
        case .off: 0
        }
    }

    /// Visible amount 0...1: out-expo in, ease-in out.
    public func level(at time: TimeInterval) -> Double {
        switch phase {
        case .off: 0
        case .on: 1
        case .appearing: Easing.outExpo(progress(at: time))
        case .disappearing(_, let from): from * (1 - Easing.easeIn(progress(at: time)))
        }
    }
}
