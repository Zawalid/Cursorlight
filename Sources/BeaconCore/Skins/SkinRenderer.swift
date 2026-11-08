import AppKit
import QuartzCore

/// Draws the active skin where the pointer is, in place of the hidden system cursor.
///
/// One skin layer lives in every overlay window, each with an image rendered at that display's scale, so a
/// skin crossing a Retina and a non-Retina display is sharp on both and its hotspot stays on the pointer.
@MainActor
public final class SkinRenderer {
    /// Where the skin goes, relative to the pointer, when the system cursor could not be hidden (fallback).
    public static let fallbackOffset = CGPoint(x: 16, y: -12)
    public static let sizeRange: ClosedRange<Double> = 0.5...3
    /// How often the cursor kind is re-checked while the pointer is still (a link can appear under it).
    static let kindPollInterval: TimeInterval = 0.1
    /// Minimum event-time gap between kind checks driven by pointer moves.
    static let kindCheckInterval: TimeInterval = 1.0 / 30

    /// 0 draws at the exact pointer position. Higher values ease towards it; clamped to 0...0.95.
    public var smoothing: Double = 0 {
        didSet {
            let clamped = min(max(smoothing, 0), 0.95)
            if clamped != smoothing { smoothing = clamped }
        }
    }

    public private(set) var skin: Skin?
    public private(set) var sizeMultiplier: Double = 1
    public private(set) var kind: CursorKind = .arrow
    /// Where the hotspot is drawn (before any fallback offset), in global screen coordinates.
    public private(set) var displayedPosition: CGPoint?

    private struct Placement {
        weak var window: OverlayWindow?
        let layer: CALayer
    }

    private struct ImageKey: Hashable {
        let kind: CursorKind
        let scale: CGFloat
    }

    private let hider: CursorHider
    private let tracker: CursorTracker
    private let overlays: OverlayManager
    private let detector: CursorKindDetecting
    private var moveHandler: CursorTracker.HandlerID?
    private var target: CGPoint = .zero
    private var placements: [CGDirectDisplayID: Placement] = [:]
    private var images: [ImageKey: CGImage] = [:]
    private var easeTimer: Timer?
    private var kindTimer: Timer?
    private var lastKindCheck: TimeInterval = -.infinity

    public init(
        hider: CursorHider,
        tracker: CursorTracker,
        overlays: OverlayManager,
        detector: CursorKindDetecting = SystemCursorKindDetector()
    ) {
        self.hider = hider
        self.tracker = tracker
        self.overlays = overlays
        self.detector = detector
    }

    deinit {
        // Review focus 1: the real cursor must come back even if nobody called stop().
        hider.restore()
        // Take the skin off screen too, or it would sit frozen next to the restored cursor.
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                for placement in placements.values { placement.layer.removeFromSuperlayer() }
            }
        }
    }

    /// Shows `skin` (hiding the system cursor) or, with nil, stops and brings the system cursor back.
    public func apply(_ skin: Skin?, sizeMultiplier: Double) {
        guard let skin else {
            stop()
            return
        }
        let multiplier = min(max(sizeMultiplier, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        if self.skin?.id != skin.id || self.sizeMultiplier != multiplier { images.removeAll() }
        self.skin = skin
        self.sizeMultiplier = multiplier
        if moveHandler == nil { activate() }
        layout()
    }

    /// Removes the skin and restores the system cursor. Idempotent.
    public func stop() {
        if let moveHandler { tracker.removeMoveHandler(moveHandler) }
        moveHandler = nil
        easeTimer?.invalidate()
        easeTimer = nil
        kindTimer?.invalidate()
        kindTimer = nil
        for placement in placements.values { placement.layer.removeFromSuperlayer() }
        placements.removeAll()
        images.removeAll()
        skin = nil
        displayedPosition = nil
        hider.restore()
    }

    /// The skin layer in the overlay for `displayID`, if any.
    func skinLayer(for displayID: CGDirectDisplayID) -> CALayer? {
        placements[displayID]?.layer
    }

    private func activate() {
        hider.hide()
        moveHandler = tracker.addMoveHandler { [weak self] position, timestamp in
            self?.pointerMoved(to: position, at: timestamp)
        }
        tracker.start()
        target = tracker.position
        displayedPosition = target
        refreshKind()
        let timer = Timer(timeInterval: Self.kindPollInterval, repeats: true) { [weak self] timer in
            let alive = MainActor.assumeIsolated { () -> Bool in
                guard let self else { return false }
                if self.refreshKind() { self.layout() }
                return true
            }
            if !alive { timer.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        kindTimer = timer
    }

    private func pointerMoved(to position: CGPoint, at timestamp: TimeInterval) {
        guard skin != nil else { return }
        target = position
        if timestamp - lastKindCheck >= Self.kindCheckInterval || timestamp < lastKindCheck {
            lastKindCheck = timestamp
            refreshKind()
        }
        if smoothing <= 0 {
            displayedPosition = position
        } else {
            step()
            startEasing()
        }
        layout()
    }

    /// Updates `kind` from the detector. Unknown cursors keep the last kind. Returns true when it changed.
    @discardableResult
    private func refreshKind() -> Bool {
        guard let detected = detector.currentKind(), detected != kind else { return false }
        kind = detected
        return true
    }

    // MARK: Smoothing

    private func step() {
        let current = displayedPosition ?? target
        let follow = 1 - smoothing
        let next = CGPoint(x: current.x + (target.x - current.x) * follow, y: current.y + (target.y - current.y) * follow)
        if hypot(target.x - next.x, target.y - next.y) < 0.05 {
            displayedPosition = target
        } else {
            displayedPosition = next
        }
    }

    private func startEasing() {
        guard easeTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] timer in
            let alive = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.skin != nil else { return false }
                return self.easeTick()
            }
            if !alive { timer.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        easeTimer = timer
    }

    /// One easing frame. Returns false once the skin has settled on the pointer.
    private func easeTick() -> Bool {
        if smoothing <= 0 {
            displayedPosition = target
        } else {
            step()
        }
        layout()
        guard displayedPosition != target else {
            easeTimer = nil
            return false
        }
        return true
    }

    // MARK: Drawing

    private func layout() {
        guard let skin, let position = displayedPosition else { return }
        syncPlacements()
        let offset = hider.isHidden ? .zero : Self.fallbackOffset
        let pointer = CGPoint(x: position.x + offset.x, y: position.y + offset.y)
        let hotspot = skin.hotspot[kind] ?? .zero

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        for placement in placements.values {
            guard let window = placement.window else { continue }
            let backingScale = window.backingScaleFactor
            let renderScale = backingScale * CGFloat(sizeMultiplier)
            guard let image = image(skin, kind: kind, scale: renderScale) else {
                placement.layer.isHidden = true
                continue
            }
            let frame = SkinGeometry.layerFrame(
                pointer: pointer,
                windowOrigin: window.frame.origin,
                imagePixelSize: CGSize(width: image.width, height: image.height),
                hotspotPixels: CGPoint(x: hotspot.x * renderScale, y: hotspot.y * renderScale),
                backingScale: backingScale
            )
            let layer = placement.layer
            if layer.contentsScale != backingScale { layer.contentsScale = backingScale }
            layer.contents = image
            layer.frame = frame
            layer.isHidden = !frame.intersects(CGRect(origin: .zero, size: window.frame.size))
        }
    }

    private func image(_ skin: Skin, kind: CursorKind, scale: CGFloat) -> CGImage? {
        let key = ImageKey(kind: kind, scale: scale)
        if let cached = images[key] { return cached }
        let image = skin.image(for: kind, scale: scale)
        images[key] = image
        return image
    }

    /// Keeps one skin layer in each current overlay window; windows are recreated on wake and display changes.
    private func syncPlacements() {
        let windows = overlays.windows
        for (id, placement) in placements where placement.window == nil || placement.window !== windows[id] {
            placement.layer.removeFromSuperlayer()
            placements[id] = nil
        }
        for (id, window) in windows where placements[id] == nil {
            let layer = CALayer()
            layer.zPosition = 1000
            layer.contentsGravity = .resize
            layer.actions = [
                "position": NSNull(), "bounds": NSNull(), "contents": NSNull(),
                "hidden": NSNull(), "contentsScale": NSNull(),
            ]
            window.rootLayer.addSublayer(layer)
            placements[id] = Placement(window: window, layer: layer)
        }
    }
}
