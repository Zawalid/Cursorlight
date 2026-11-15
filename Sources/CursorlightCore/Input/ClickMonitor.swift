import AppKit

/// Watches left and right mouse buttons with global and local monitors. Mouse button events need no permission.
@MainActor
public final class ClickMonitor {
    /// (button, isDown, position in global screen coordinates).
    public var onButton: ((MouseButton, Bool, CGPoint) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    public init() {}

    public func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            guard let (button, isDown) = Self.decode(event.type) else { return }
            Task { @MainActor in self?.deliver(button, isDown: isDown) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if let (button, isDown) = Self.decode(event.type) {
                MainActor.assumeIsolated { self?.deliver(button, isDown: isDown) }
            }
            return event
        }
    }

    public func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func deliver(_ button: MouseButton, isDown: Bool) {
        onButton?(button, isDown, NSEvent.mouseLocation)
    }

    nonisolated static func decode(_ type: NSEvent.EventType) -> (MouseButton, Bool)? {
        switch type {
        case .leftMouseDown: (.left, true)
        case .leftMouseUp: (.left, false)
        case .rightMouseDown: (.right, true)
        case .rightMouseUp: (.right, false)
        default: nil
        }
    }
}
