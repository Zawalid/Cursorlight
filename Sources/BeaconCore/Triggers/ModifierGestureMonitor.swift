import AppKit

/// Optional Input Monitoring: needed only to see modifier keys and clicks while another app is frontmost.
public enum InputMonitoring {
    public static var isGranted: Bool { CGPreflightListenEventAccess() }

    /// Shows the system prompt once; afterwards the user must switch it on in System Settings.
    public static func request() {
        _ = CGRequestListenEventAccess()
    }

    public static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Feeds a `ModifierGestureRecognizer` from key and mouse events. The local monitor always runs (no permission
/// needed while Beacon itself is frontmost); the global one only runs once Input Monitoring is granted.
@MainActor
public final class ModifierGestureMonitor {
    public var onEvent: ((TriggerEvent) -> Void)?
    public private(set) var recognizer = ModifierGestureRecognizer()
    public var hasGlobalAccess: Bool { globalMonitor != nil }

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var timer: DispatchWorkItem?

    public init() {}

    public func start() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.mask) { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) }
                return event
            }
        }
        refreshAccess()
    }

    /// Installs the global monitor when access has been granted since the last call.
    public func refreshAccess() {
        guard globalMonitor == nil, InputMonitoring.isGranted else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.mask) { [weak self] event in
            let copy = Snapshot(event)
            Task { @MainActor in self?.handle(copy) }
        }
    }

    public func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        timer?.cancel()
        timer = nil
        for event in recognizer.reset() { onEvent?(event) }
    }

    private static let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]

    /// The parts of an event the recognizer needs, copied so they can cross to the main actor.
    struct Snapshot: Sendable {
        let type: NSEvent.EventType
        let keyCode: UInt16
        let flags: UInt
        let time: TimeInterval

        init(_ event: NSEvent) {
            type = event.type
            // keyCode exists only on key events; reading it on a mouse event raises an exception, which dropped every click.
            keyCode = [.flagsChanged, .keyDown, .keyUp].contains(event.type) ? event.keyCode : 0
            flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue & ModifierKey.allFlags
            time = event.timestamp
        }
    }

    private func handle(_ event: NSEvent) {
        handle(Snapshot(event))
    }

    private func handle(_ event: Snapshot) {
        var out: [TriggerEvent] = []
        switch event.type {
        case .flagsChanged: out = recognizer.flagsChanged(keyCode: event.keyCode, flags: event.flags, time: event.time)
        default: recognizer.otherInput()
        }
        scheduleHoldCheck()
        for item in out { onEvent?(item) }
    }

    private func scheduleHoldCheck() {
        timer?.cancel()
        timer = nil
        guard let deadline = recognizer.holdDeadline else { return }
        let delay = max(deadline - ProcessInfo.processInfo.systemUptime, 0)
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let events = self.recognizer.tick(time: ProcessInfo.processInfo.systemUptime)
                for item in events { self.onEvent?(item) }
            }
        }
        timer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.001, execute: work)
    }
}
