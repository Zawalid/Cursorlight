import AppKit

/// Source of the connected displays and of change events (injectable for tests).
@MainActor
public protocol ScreenProviding: AnyObject {
    var displayIDs: [CGDirectDisplayID] { get }
    var changes: AsyncStream<Void> { get }
    /// Frame of a display in global screen coordinates.
    func frame(for displayID: CGDirectDisplayID) -> CGRect
}

extension ScreenProviding {
    public func frame(for displayID: CGDirectDisplayID) -> CGRect {
        NSScreen.screens.first(where: { $0.displayID == displayID })?.frame
            ?? CGRect(x: 0, y: 0, width: 800, height: 600)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Real displays, with a change stream fed by the screen-parameter notification.
@MainActor
public final class SystemScreens: ScreenProviding {
    public let changes: AsyncStream<Void>
    private let token: NSObjectProtocol

    public init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        changes = stream
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in continuation.yield() }
    }

    public var displayIDs: [CGDirectDisplayID] { NSScreen.screens.compactMap(\.displayID) }
}

/// Keeps exactly one click-through overlay window per connected display.
@MainActor
public final class OverlayManager {
    public private(set) var windows: [CGDirectDisplayID: OverlayWindow] = [:]

    private let screens: ScreenProviding
    private var changeTask: Task<Void, Never>?
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var isRunning = false

    public init(screens: ScreenProviding) {
        self.screens = screens
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        rebuild()

        let stream = screens.changes
        changeTask = Task { [weak self] in
            for await _ in stream {
                self?.sync()
            }
        }

        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let triggers: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didWakeNotification),
            (workspace, NSWorkspace.screensDidWakeNotification),
            (distributed, Notification.Name("com.apple.screenIsLocked")),
            (distributed, Notification.Name("com.apple.screenIsUnlocked")),
        ]
        for (center, name) in triggers {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            }
            observers.append((center, token))
        }
    }

    public func stop() {
        isRunning = false
        changeTask?.cancel()
        changeTask = nil
        for observer in observers { observer.center.removeObserver(observer.token) }
        observers.removeAll()
        closeAll()
    }

    /// Closes every window and recreates one per current display, so nothing stale survives a wake or reconfiguration.
    public func rebuild() {
        closeAll()
        for id in screens.displayIDs { makeWindow(for: id) }
    }

    /// Cheaper reconcile: drops windows for removed displays, adds new ones, re-frames the rest.
    private func sync() {
        let current = screens.displayIDs
        for id in windows.keys where !current.contains(id) {
            windows[id]?.close()
            windows[id] = nil
        }
        for id in current {
            if let window = windows[id] {
                window.setFrame(screens.frame(for: id), display: false)
            } else {
                makeWindow(for: id)
            }
        }
    }

    private func makeWindow(for id: CGDirectDisplayID) {
        let window = OverlayWindow(displayID: id, frame: screens.frame(for: id))
        window.orderFrontRegardless()
        windows[id] = window
    }

    private func closeAll() {
        for window in windows.values { window.close() }
        windows.removeAll()
    }
}
