import AppKit

/// Follows the pointer with global and local mouse-moved monitors. Needs no permission.
/// Positions use screen coordinates, the same convention as `NSEvent.mouseLocation`.
@MainActor
public final class CursorTracker {
    public private(set) var position: CGPoint = NSEvent.mouseLocation
    public var onMove: ((CGPoint, TimeInterval) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    public init() {}

    public func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let timestamp = event.timestamp
            Task { @MainActor in self?.handleMove(at: timestamp) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let timestamp = event.timestamp
            MainActor.assumeIsolated { self?.handleMove(at: timestamp) }
            return event
        }
        position = NSEvent.mouseLocation
    }

    public func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleMove(at timestamp: TimeInterval) {
        deliver(position: NSEvent.mouseLocation, timestamp: timestamp)
    }

    /// Single entry point for a new position; tests call it directly.
    func deliver(position: CGPoint, timestamp: TimeInterval) {
        self.position = position
        onMove?(position, timestamp)
    }
}
