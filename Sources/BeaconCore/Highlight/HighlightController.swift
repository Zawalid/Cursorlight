import AppKit
import QuartzCore

/// A display-synchronized frame callback. `CADisplayLink` in the app; a fake in tests.
@MainActor
public protocol FrameLink: AnyObject {
    var isPaused: Bool { get set }
    func invalidate()
}

extension CADisplayLink: FrameLink {}

/// Which hosts to tear down and which to build when the overlay windows change. Pure.
public enum HostPlan {
    public static func plan<ID: Hashable>(existing: Set<ID>, current: Set<ID>) -> (remove: Set<ID>, add: Set<ID>) {
        (existing.subtracting(current), current.subtracting(existing))
    }
}

/// Runs the cursor highlight and click ripples on every overlay window. One `HighlightModel` (global coordinates)
/// is stepped from each window's display link with the pointer position read at that tick; each window's renderer
/// draws the frame translated into its own coordinates. Links pause whenever nothing moves and wake on input.
/// Window membership is followed through `windowsChanged()`, which the overlay manager calls after every rebuild.
@MainActor
public final class HighlightController {
    /// Builds a link for a window that calls `tick` with each frame's target timestamp.
    public typealias LinkFactory = @MainActor (OverlayWindow, @escaping @MainActor (TimeInterval) -> Void) -> (any FrameLink)?

    @MainActor
    private final class Host {
        let window: OverlayWindow
        let renderer: HighlightRenderer
        var link: (any FrameLink)?

        init(window: OverlayWindow, renderer: HighlightRenderer) {
            self.window = window
            self.renderer = renderer
        }
    }

    /// Display link target; NSObject so the link can call it by selector. The link fires on the main run loop.
    @MainActor
    private final class LinkTarget: NSObject {
        let handler: @MainActor (TimeInterval) -> Void

        init(handler: @escaping @MainActor (TimeInterval) -> Void) {
            self.handler = handler
        }

        @objc func tick(_ link: CADisplayLink) {
            handler(link.targetTimestamp)
        }
    }

    /// The real display link of the window's view (macOS 14+). The link retains its target.
    public static let displayLinkFactory: LinkFactory = { window, tick in
        guard let view = window.contentView else { return nil }
        let target = LinkTarget(handler: tick)
        let link = view.displayLink(target: target, selector: #selector(LinkTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        return link
    }

    public private(set) var model: HighlightModel
    /// Called after the on/off state or the style changes, so menus can refresh.
    public var onChange: (() -> Void)?

    private let windows: @MainActor () -> [OverlayWindow]
    private let pointer: @MainActor () -> CGPoint
    private let clock: @MainActor () -> TimeInterval
    private let makeLink: LinkFactory
    private var hosts: [ObjectIdentifier: Host] = [:]
    private var isRunning = false
    private var isAsleep = false
    private var sleepObservers: [NSObjectProtocol] = []

    /// - Parameters:
    ///   - windows: the current overlay windows, one per display.
    ///   - pointer: the pointer in global screen coordinates, read at every frame.
    ///   - clock: the display link's timebase (`CACurrentMediaTime`).
    ///   - makeLink: builds the per-window frame link.
    public init(
        windows: @escaping @MainActor () -> [OverlayWindow],
        style: HighlightStyle,
        ripplesEnabled: Bool,
        pointer: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation },
        clock: @escaping @MainActor () -> TimeInterval = { CACurrentMediaTime() },
        makeLink: @escaping LinkFactory = HighlightController.displayLinkFactory
    ) {
        self.windows = windows
        self.pointer = pointer
        self.clock = clock
        self.makeLink = makeLink
        model = HighlightModel(style: style, ripplesEnabled: ripplesEnabled, pointer: pointer())
    }

    /// Follows `overlays`: its `onWindowsChanged` is taken over to reconcile hosts after every rebuild.
    public convenience init(overlays: OverlayManager, style: HighlightStyle, ripplesEnabled: Bool) {
        self.init(
            windows: { [weak overlays] in overlays.map { Array($0.windows.values) } ?? [] },
            style: style, ripplesEnabled: ripplesEnabled
        )
        overlays.onWindowsChanged = { [weak self] in self?.windowsChanged() }
    }

    public var style: HighlightStyle { model.style }
    public var isOn: Bool { model.isOn }
    public var ripplesEnabled: Bool { model.ripplesEnabled }
    /// Number of windows currently hosting the highlight.
    public var hostCount: Int { hosts.count }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        let center = NSWorkspace.shared.notificationCenter
        sleepObservers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.systemWillSleep() }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.systemDidWake() }
            },
        ]
        reconcile()
        wake()
    }

    public func stop() {
        isRunning = false
        for observer in sleepObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        sleepObservers = []
        for host in hosts.values { remove(host) }
        hosts.removeAll()
    }

    /// The overlay windows were rebuilt (display change, wake, lock): drop hosts for closed windows, build hosts for
    /// new ones, and draw the current state on them at once.
    public func windowsChanged() {
        guard isRunning else { return }
        reconcile()
        redraw()
        wake()
    }

    func systemWillSleep() {
        isAsleep = true
        for host in hosts.values { host.link?.isPaused = true }
    }

    func systemDidWake() {
        isAsleep = false
        wake()
    }

    // MARK: Commands

    /// Shake or menu: turns the highlight on or off.
    public func toggle() {
        model.toggleHighlight(at: clock(), pointer: pointer())
        wake()
        onChange?()
    }

    public func setOn(_ on: Bool) {
        model.setHighlight(on, at: clock(), pointer: pointer())
        wake()
        onChange?()
    }

    public func setStyle(_ style: HighlightStyle) {
        model.setStyle(style, at: clock())
        for host in hosts.values { host.renderer.configure(style: style) }
        wake()
        onChange?()
    }

    public func setRipplesEnabled(_ enabled: Bool) {
        model.ripplesEnabled = enabled
        onChange?()
    }

    /// The pointer moved: frames read the position themselves; this only wakes paused links.
    public func pointerMoved() {
        guard model.isOn || model.toggle.isVisible else { return }
        wake()
    }

    public func mouseButton(_ button: MouseButton, isDown: Bool, at point: CGPoint) {
        let time = clock()
        if isDown {
            model.mouseDown(button, at: time)
        } else {
            model.mouseUp(button, at: point, time: time)
        }
        wake()
    }

    // MARK: Frames

    private func wake() {
        guard isRunning, !isAsleep else { return }
        for host in hosts.values where host.link?.isPaused != false { host.link?.isPaused = false }
    }

    func tick(_ id: ObjectIdentifier, time: TimeInterval) {
        guard let host = hosts[id] else { return }
        let frame = model.step(pointer: pointer(), time: time)
        render(frame, on: host)
        let settled = hosts.values.allSatisfy { $0.renderer.isSettled }
        if !model.needsFrames && settled {
            // Every window must have drawn the final state before sleeping; pause each link after its own tick.
            host.link?.isPaused = true
        }
    }

    /// Draws the current state on every window without waiting for a frame.
    private func redraw() {
        guard !hosts.isEmpty else { return }
        let frame = model.step(pointer: pointer(), time: clock())
        for host in hosts.values { render(frame, on: host) }
    }

    private func render(_ frame: HighlightFrame, on host: Host) {
        var frames: [CGDirectDisplayID: CGRect] = [:]
        for other in hosts.values { frames[other.window.displayID] = other.window.frame }
        let owner = PointerGeometry.owner(of: frame.center, in: frames)
        host.renderer.render(frame, windowFrame: host.window.frame, isOwner: owner == host.window.displayID)
    }

    /// Follows the current overlay windows. Called on start and when the window set changes, never per event.
    private func reconcile() {
        let current = Dictionary(windows().map { (ObjectIdentifier($0), $0) }, uniquingKeysWith: { first, _ in first })
        let plan = HostPlan.plan(existing: Set(hosts.keys), current: Set(current.keys))
        for id in plan.remove {
            if let host = hosts.removeValue(forKey: id) { remove(host) }
        }
        for id in plan.add {
            guard let window = current[id] else { continue }
            let renderer = HighlightRenderer(style: model.style, scale: window.backingScaleFactor)
            renderer.attach(to: window.rootLayer)
            let host = Host(window: window, renderer: renderer)
            host.link = makeLink(window) { [weak self] time in self?.tick(id, time: time) }
            host.link?.isPaused = isAsleep
            hosts[id] = host
        }
    }

    private func remove(_ host: Host) {
        host.link?.invalidate()
        host.link = nil
        host.renderer.detach()
    }
}
