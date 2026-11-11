import AppKit
import QuartzCore

/// Runs the cursor highlight and click ripples on every overlay window. One `HighlightModel` (global coordinates)
/// is stepped from each window's display link with the pointer position read at that tick; each window's renderer
/// draws the frame translated into its own coordinates. Links pause whenever nothing moves and wake on input.
@MainActor
public final class HighlightController {
    @MainActor
    private final class Host {
        let window: OverlayWindow
        let renderer: HighlightRenderer
        var link: CADisplayLink?
        let target: LinkTarget

        init(window: OverlayWindow, renderer: HighlightRenderer, target: LinkTarget) {
            self.window = window
            self.renderer = renderer
            self.target = target
        }
    }

    /// Display link target; NSObject so the link can call it by selector. The link fires on the main run loop.
    @MainActor
    private final class LinkTarget: NSObject {
        weak var controller: HighlightController?
        let id: ObjectIdentifier

        init(id: ObjectIdentifier) {
            self.id = id
        }

        @objc func tick(_ link: CADisplayLink) {
            controller?.tick(id, time: link.targetTimestamp)
        }
    }

    public private(set) var model: HighlightModel
    /// Called after the on/off state or the style changes, so menus can refresh.
    public var onChange: (() -> Void)?

    private let windows: @MainActor () -> [OverlayWindow]
    private let pointer: @MainActor () -> CGPoint
    private let clock: @MainActor () -> TimeInterval
    private var hosts: [ObjectIdentifier: Host] = [:]
    private var isRunning = false

    /// - Parameters:
    ///   - windows: the current overlay windows, one per display.
    ///   - pointer: the pointer in global screen coordinates, read at every frame.
    ///   - clock: the display link's timebase (`CACurrentMediaTime`).
    public init(
        windows: @escaping @MainActor () -> [OverlayWindow],
        style: HighlightStyle,
        ripplesEnabled: Bool,
        pointer: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation },
        clock: @escaping @MainActor () -> TimeInterval = { CACurrentMediaTime() }
    ) {
        self.windows = windows
        self.pointer = pointer
        self.clock = clock
        model = HighlightModel(style: style, ripplesEnabled: ripplesEnabled, pointer: pointer())
    }

    public convenience init(overlays: OverlayManager, style: HighlightStyle, ripplesEnabled: Bool) {
        self.init(
            windows: { [weak overlays] in overlays.map { Array($0.windows.values) } ?? [] },
            style: style, ripplesEnabled: ripplesEnabled
        )
    }

    public var style: HighlightStyle { model.style }
    public var isOn: Bool { model.isOn }
    public var ripplesEnabled: Bool { model.ripplesEnabled }

    public func start() {
        isRunning = true
        reconcile()
    }

    public func stop() {
        isRunning = false
        for host in hosts.values { remove(host) }
        hosts.removeAll()
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
        guard isRunning else { return }
        reconcile()
        for host in hosts.values { host.link?.isPaused = false }
    }

    private func tick(_ id: ObjectIdentifier, time: TimeInterval) {
        guard let host = hosts[id] else { return }
        let frame = model.step(pointer: pointer(), time: time)
        var frames: [CGDirectDisplayID: CGRect] = [:]
        for other in hosts.values { frames[other.window.displayID] = other.window.frame }
        let owner = PointerGeometry.owner(of: frame.center, in: frames)
        host.renderer.render(frame, windowFrame: host.window.frame, isOwner: owner == host.window.displayID)

        let settled = hosts.values.allSatisfy { $0.renderer.isSettled }
        if !model.needsFrames && settled {
            // Every window must have drawn the final state before sleeping; pause each link after its own tick.
            host.link?.isPaused = true
        }
    }

    /// Overlay windows are rebuilt on wake and display changes: follow the current set.
    private func reconcile() {
        let current = windows()
        let ids = Set(current.map(ObjectIdentifier.init))
        for (id, host) in hosts where !ids.contains(id) {
            remove(host)
            hosts[id] = nil
        }
        for window in current where hosts[ObjectIdentifier(window)] == nil {
            let id = ObjectIdentifier(window)
            let renderer = HighlightRenderer(style: model.style, scale: window.backingScaleFactor)
            renderer.attach(to: window.rootLayer)
            let target = LinkTarget(id: id)
            target.controller = self
            let host = Host(window: window, renderer: renderer, target: target)
            if let view = window.contentView {
                let link = view.displayLink(target: target, selector: #selector(LinkTarget.tick(_:)))
                link.add(to: .main, forMode: .common)
                host.link = link
            }
            hosts[id] = host
        }
    }

    private func remove(_ host: Host) {
        host.link?.invalidate()
        host.link = nil
        host.renderer.detach()
    }
}
