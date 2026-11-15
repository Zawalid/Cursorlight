import AppKit
import QuartzCore

/// Runs the spotlight on every overlay window. Three states: off, editing (input windows capture the drag so you can
/// draw, move or resize the region) and shown (the region stays lit and the dim lets every click through).
@MainActor
public final class SpotlightController {
    public enum State: Equatable, Sendable { case idle, editing, shown }

    @MainActor
    private final class Host {
        let window: OverlayWindow
        let renderer = SpotlightRenderer()
        var input: InkInputWindow?
        init(window: OverlayWindow) { self.window = window }
    }

    public private(set) var state: State = .idle
    public private(set) var model = SpotlightModel()
    public private(set) var style = SpotlightStyle()
    public var onChange: (() -> Void)?

    private let windows: @MainActor () -> [OverlayWindow]
    private var windowFilter: @MainActor (OverlayWindow) -> Bool = { _ in true }
    private var hosts: [ObjectIdentifier: Host] = [:]
    private var isRunning = false
    private var regionBeforeEdit: CGRect?

    public init(windows: @escaping @MainActor () -> [OverlayWindow]) {
        self.windows = windows
    }

    public convenience init(overlays: OverlayManager) {
        self.init(windows: { [weak overlays] in overlays.map { Array($0.windows.values) } ?? [] })
    }

    public var isOn: Bool { state != .idle }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        reconcile()
    }

    public func stop() {
        clear()
        isRunning = false
        for host in hosts.values { remove(host) }
        hosts.removeAll()
    }

    public func windowsChanged() {
        guard isRunning else { return }
        reconcile()
        render()
        if state == .editing { rebuildInputs() }
    }

    public func setWindowFilter(_ filter: @escaping @MainActor (OverlayWindow) -> Bool) {
        windowFilter = filter
        windowsChanged()
    }

    public func setStyle(_ style: SpotlightStyle) {
        guard style != self.style else { return }
        self.style = style
        render()
    }

    // MARK: Commands

    /// The one shortcut: off becomes editing, editing is confirmed, shown turns off.
    public func cycle() {
        switch state {
        case .idle: beginEditing()
        case .editing: commit()
        case .shown: clear()
        }
    }

    /// Back into editing a region that is already shown.
    public func edit() {
        if state == .shown { beginEditing() }
    }

    public func clear() {
        guard state != .idle || model.region != nil else { return }
        closeInputs()
        model.clear()
        state = .idle
        render()
        onChange?()
    }

    private func beginEditing() {
        guard isRunning else { return }
        regionBeforeEdit = model.region
        state = .editing
        rebuildInputs()
        render()
        onChange?()
    }

    private func commit() {
        closeInputs()
        state = model.region == nil ? .idle : .shown
        render()
        onChange?()
    }

    /// Escape: leave editing and put back whatever was there before.
    private func cancel() {
        closeInputs()
        model.setRegion(regionBeforeEdit)
        state = regionBeforeEdit == nil ? .idle : .shown
        render()
        onChange?()
    }

    // MARK: Input

    private func pointerDown(_ p: CGPoint) { model.pointerDown(p); render() }
    private func pointerDragged(_ p: CGPoint) { model.pointerDragged(p); render() }
    private func pointerUp(_ p: CGPoint) { model.pointerUp(p); render() }

    private func keyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 53: cancel()
        case 36, 76: commit()
        case 51, 117: clear()
        default: break
        }
    }

    // MARK: Hosts

    private func render() {
        for host in hosts.values {
            host.renderer.render(
                region: model.region, windowFrame: host.window.frame, style: style, editing: state == .editing, visible: state != .idle
            )
        }
    }

    private func reconcile() {
        let current = Dictionary(windows().filter { windowFilter($0) }.map { (ObjectIdentifier($0), $0) }, uniquingKeysWith: { first, _ in first })
        let plan = HostPlan.plan(existing: Set(hosts.keys), current: Set(current.keys))
        for id in plan.remove {
            if let host = hosts.removeValue(forKey: id) { remove(host) }
        }
        for id in plan.add {
            guard let window = current[id] else { continue }
            let host = Host(window: window)
            host.renderer.attach(to: window.rootLayer)
            hosts[id] = host
        }
    }

    private func remove(_ host: Host) {
        closeInput(of: host)
        host.renderer.detach()
    }

    private func rebuildInputs() {
        for host in hosts.values {
            closeInput(of: host)
            guard let screen = NSScreen.screens.first(where: { $0.displayID == host.window.displayID }) else { continue }
            let input = InkInputWindow(frame: screen.visibleFrame, takesKey: true)
            input.onDown = { [weak self] in self?.pointerDown($0) }
            input.onDrag = { [weak self] in self?.pointerDragged($0) }
            input.onUp = { [weak self] in self?.pointerUp($0) }
            input.onKey = { [weak self] in self?.keyDown($0) }
            input.orderFrontRegardless()
            input.makeKey()
            host.input = input
        }
    }

    private func closeInputs() { for host in hosts.values { closeInput(of: host) } }

    private func closeInput(of host: Host) {
        host.input?.orderOut(nil)
        host.input?.close()
        host.input = nil
    }
}
