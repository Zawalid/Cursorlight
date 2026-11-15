import Foundation

/// A presenter's timer: counts down from a chosen time and keeps counting past zero, or counts up like a stopwatch.
/// Pure value; every call is given the current time.
public struct PresenterTimer: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case countdown(TimeInterval)
        case stopwatch
    }

    public enum Phase: Equatable, Sendable { case idle, running, paused }

    public enum Urgency: Equatable, Sendable {
        case normal
        /// The last fifth of the time, or the last minute, whichever is longer.
        case warning
        /// Past zero.
        case over
    }

    public private(set) var mode: Mode
    public private(set) var phase: Phase = .idle
    private var accumulated: TimeInterval = 0
    private var runningSince: TimeInterval?

    public init(mode: Mode = .countdown(300)) { self.mode = mode }

    public mutating func start(_ mode: Mode, at now: TimeInterval) {
        self.mode = mode
        accumulated = 0
        runningSince = now
        phase = .running
    }

    public mutating func pause(at now: TimeInterval) {
        guard phase == .running, let since = runningSince else { return }
        accumulated += max(0, now - since)
        runningSince = nil
        phase = .paused
    }

    public mutating func resume(at now: TimeInterval) {
        guard phase == .paused else { return }
        runningSince = now
        phase = .running
    }

    public mutating func reset() {
        accumulated = 0
        runningSince = nil
        phase = .idle
    }

    public func elapsed(at now: TimeInterval) -> TimeInterval {
        accumulated + (runningSince.map { max(0, now - $0) } ?? 0)
    }

    /// Seconds left, negative once past zero. nil for a stopwatch.
    public func remaining(at now: TimeInterval) -> TimeInterval? {
        guard case let .countdown(total) = mode else { return nil }
        return total - elapsed(at: now)
    }

    public func urgency(at now: TimeInterval) -> Urgency {
        guard case let .countdown(total) = mode, phase != .idle, let left = remaining(at: now) else { return .normal }
        if left < 0 { return .over }
        return left <= max(60, total * 0.2) ? .warning : .normal
    }

    /// What the chip shows: `05:00` counting down, `+00:12` once over, `00:42` for a stopwatch, `1:05:00` past an hour.
    public func display(at now: TimeInterval) -> String {
        let seconds: TimeInterval
        var prefix = ""
        if let left = remaining(at: now) {
            if left < 0 { prefix = "+"; seconds = -left } else { seconds = left.rounded(.up) }
        } else {
            seconds = elapsed(at: now)
        }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%@%d:%02d:%02d", prefix, h, m, s) : String(format: "%@%02d:%02d", prefix, m, s)
    }
}
