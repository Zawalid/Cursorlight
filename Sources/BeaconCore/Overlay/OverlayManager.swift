import AppKit

/// Source of the connected displays and of change events (injectable for tests).
@MainActor
public protocol ScreenProviding: AnyObject {
    var displayIDs: [CGDirectDisplayID] { get }
    /// A fresh stream on every access, so the manager can stop and start again.
    var changes: AsyncStream<Void> { get }
    /// Frame of a display in global screen coordinates, or nil when the display is unknown.
    func frame(for displayID: CGDirectDisplayID) -> CGRect?
}

extension ScreenProviding {
    public func frame(for displayID: CGDirectDisplayID) -> CGRect? {
        NSScreen.screens.first(where: { $0.displayID == displayID })?.frame
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Real displays. Every `changes` access returns its own stream; the notification observer exists only while
/// at least one stream is active.
@MainActor
public final class SystemScreens: ScreenProviding {
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var token: NSObjectProtocol?

    public init() {}

    public var displayIDs: [CGDirectDisplayID] { NSScreen.screens.compactMap(\.displayID) }

    public var changes: AsyncStream<Void> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        continuations[id] = continuation
        installObserverIfNeeded()
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.remove(id) }
        }
        return stream
    }

    private func installObserverIfNeeded() {
        guard token == nil else { return }
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                for continuation in self.continuations.values { continuation.yield() }
            }
        }
    }

    private func remove(_ id: UUID) {
        continuations[id] = nil
        if continuations.isEmpty, let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
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
                if let frame = screens.frame(for: id) { window.setFrame(frame, display: false) }
            } else {
                makeWindow(for: id)
            }
        }
    }

    private func makeWindow(for id: CGDirectDisplayID) {
        guard let frame = screens.frame(for: id) else { return }
        let window = OverlayWindow(displayID: id, frame: frame)
        window.orderFrontRegardless()
        windows[id] = window
    }

    private func closeAll() {
        for window in windows.values { window.close() }
        windows.removeAll()
    }
}
