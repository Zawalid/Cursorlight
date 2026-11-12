import AppKit
import QuartzCore

/// Runs Ink on every overlay window: input windows capture the drag, one `InkModel` (global coordinates) holds the
/// strokes, renderers draw them. The display links run only while strokes are on screen.
@MainActor
public final class InkController {
    @MainActor
    private final class Host {
        let window: OverlayWindow
        let renderer: InkRenderer
        var input: InkInputWindow?
        var link: (any FrameLink)?

        init(window: OverlayWindow, renderer: InkRenderer) {
            self.window = window
            self.renderer = renderer
        }
    }

    public private(set) var model: InkModel
    public private(set) var style: InkStyle
    public private(set) var color: InkColor
    /// Pen thickness as a multiple of the style's width.
    public private(set) var widthScale: CGFloat = 1
    /// True while the input windows are up and the drag draws.
    public private(set) var isActive = false
    public var onChange: (() -> Void)?
    private var windowFilter: @MainActor (OverlayWindow) -> Bool = { _ in true }

    private let windows: @MainActor () -> [OverlayWindow]
    private let clock: @MainActor () -> TimeInterval
    private let makeLink: HighlightController.LinkFactory
    private var hosts: [ObjectIdentifier: Host] = [:]
    private var isRunning = false
    private var takesKey = false
    private var lastStep: TimeInterval = -1

    public init(
        windows: @escaping @MainActor () -> [OverlayWindow],
        style: InkStyle = .marker,
        color: InkColor = .red,
        cleanupEnabled: Bool = true,
        fadeAfter: TimeInterval = 2,
        clock: @escaping @MainActor () -> TimeInterval = { CACurrentMediaTime() },
        makeLink: @escaping HighlightController.LinkFactory = HighlightController.displayLinkFactory
    ) {
        self.windows = windows
        self.style = style
        self.color = color
        self.clock = clock
        self.makeLink = makeLink
        model = InkModel(fadeAfter: fadeAfter, cleanupEnabled: cleanupEnabled)
    }

    public convenience init(
        overlays: OverlayManager, style: InkStyle, color: InkColor, cleanupEnabled: Bool, fadeAfter: TimeInterval = 2
    ) {
        self.init(
            windows: { [weak overlays] in overlays.map { Array($0.windows.values) } ?? [] },
            style: style, color: color, cleanupEnabled: cleanupEnabled, fadeAfter: fadeAfter
        )
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        reconcile()
    }

    public func stop() {
        deactivate()
        isRunning = false
        for host in hosts.values { remove(host) }
        hosts.removeAll()
    }

    /// The overlay windows were rebuilt: follow them, and rebuild the input windows if Ink is active.
    public func windowsChanged() {
        guard isRunning else { return }
        reconcile()
        if isActive { rebuildInputs() }
    }

    /// Limits Ink to some displays and rebuilds the hosts at once.
    public func setWindowFilter(_ filter: @escaping @MainActor (OverlayWindow) -> Bool) {
        windowFilter = filter
        windowsChanged()
    }

    // MARK: Commands

    /// Starts capturing the drag. `takesKey` also takes the keyboard (Escape, undo, colors); a held-key trigger passes
    /// false so the app being shared keeps typing focus.
    public func activate(takesKey: Bool) {
        guard isRunning else { return }
        self.takesKey = takesKey
        isActive = true
        rebuildInputs()
        onChange?()
    }

    public func deactivate() {
        guard isActive else { return }
        if model.isDrawing { model.end(at: clock()) }
        isActive = false
        for host in hosts.values { closeInput(of: host) }
        wake()
        onChange?()
    }

    public func setStyle(_ style: InkStyle) {
        self.style = style
        onChange?()
    }

    public func setColor(_ color: InkColor) {
        self.color = color
        onChange?()
    }

    public func setWidthScale(_ scale: Double) {
        widthScale = CGFloat(min(max(scale, 0.3), 4))
    }

    public func setFadeAfter(_ seconds: TimeInterval) {
        model.fadeAfter = seconds
    }

    public func setCleanupEnabled(_ enabled: Bool) {
        model.cleanupEnabled = enabled
    }

    public func undo() {
        model.undo()
        redraw()
    }

    public func clearAll() {
        model.clear(at: clock())
        wake()
    }

    // MARK: Input

    func pointerDown(_ point: CGPoint) {
        model.begin(at: point, style: style, color: color, widthScale: widthScale)
        wake()
    }

    func pointerDragged(_ point: CGPoint) {
        model.append(point)
        wake()
    }

    func pointerUp(_ point: CGPoint) {
        model.append(point)
        model.end(at: clock())
        wake()
    }

    func keyDown(_ event: NSEvent) {
        let chars = event.charactersIgnoringModifiers ?? ""
        if event.keyCode == 53 {
            deactivate()
        } else if chars == "z", event.modifierFlags.contains(.command) {
            undo()
        } else if chars == "c" || event.keyCode == 51 {
            clearAll()
        } else if let digit = Int(chars), (1...InkColor.allCases.count).contains(digit) {
            setColor(InkColor.allCases[digit - 1])
        }
    }

    // MARK: Frames

    private func wake() {
        guard isRunning else { return }
        for host in hosts.values where host.link?.isPaused != false { host.link?.isPaused = false }
    }

    private func tick(time: TimeInterval) {
        let frame = model.step(time: time)
        for host in hosts.values { host.renderer.render(frame, windowOrigin: host.window.frame.origin) }
        if !model.needsFrames { for host in hosts.values { host.link?.isPaused = true } }
    }

    private func redraw() {
        let frame = model.step(time: clock())
        for host in hosts.values { host.renderer.render(frame, windowOrigin: host.window.frame.origin) }
        if model.needsFrames { wake() }
    }

    private func reconcile() {
        let current = Dictionary(windows().filter { windowFilter($0) }.map { (ObjectIdentifier($0), $0) }, uniquingKeysWith: { first, _ in first })
        let plan = HostPlan.plan(existing: Set(hosts.keys), current: Set(current.keys))
        for id in plan.remove {
            if let host = hosts.removeValue(forKey: id) { remove(host) }
        }
        for id in plan.add {
            guard let window = current[id] else { continue }
            let renderer = InkRenderer(scale: window.backingScaleFactor)
            renderer.attach(to: window.rootLayer)
            let host = Host(window: window, renderer: renderer)
            host.link = makeLink(window) { [weak self] time in
                guard let self else { return }
                // Several windows tick per frame; step the shared model once per timestamp.
                if time != self.lastStep {
                    self.lastStep = time
                    self.tick(time: time)
                }
            }
            host.link?.isPaused = !model.needsFrames
            hosts[id] = host
        }
    }

    private func remove(_ host: Host) {
        closeInput(of: host)
        host.link?.invalidate()
        host.link = nil
        host.renderer.detach()
    }

    private func rebuildInputs() {
        for host in hosts.values {
            closeInput(of: host)
            guard let screen = NSScreen.screens.first(where: { $0.displayID == host.window.displayID }) else { continue }
            let input = InkInputWindow(frame: screen.visibleFrame, takesKey: takesKey)
            input.onDown = { [weak self] in self?.pointerDown($0) }
            input.onDrag = { [weak self] in self?.pointerDragged($0) }
            input.onUp = { [weak self] in self?.pointerUp($0) }
            input.onKey = { [weak self] in self?.keyDown($0) }
            input.orderFrontRegardless()
            if takesKey { input.makeKey() }
            host.input = input
        }
    }

    private func closeInput(of host: Host) {
        host.input?.orderOut(nil)
        host.input?.close()
        host.input = nil
    }
}
