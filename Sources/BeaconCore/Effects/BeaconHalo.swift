import AppKit
import QuartzCore

/// A glowing ring drawn around the real pointer, which stays visible in its center. It blooms in on a spring,
/// follows the pointer without lag, can dim the rest of the screen, and fades out after the pointer rests.
@MainActor
public final class BeaconHalo: Effect {
    public let id = EffectID.beacon
    public var onFinish: (() -> Void)?

    /// Ring radius in points; large enough to surround the arrow at an enlarged cursor size.
    static let radius: CGFloat = 40
    /// The dim leaves a clear disc around the pointer and reaches full strength at the feather's outer radius.
    static let clearRadius: CGFloat = radius * 1.35
    static let featherRadius: CGFloat = radius * 3

    /// Full-window layer holding everything; hidden when the pointer is on another display.
    let root = CALayer()
    /// Centered on the pointer; carries the ring, its glow and the inner wash. Scales during the bloom.
    let body = CALayer()
    let ring = CAShapeLayer()
    private let glowRing = CAShapeLayer()
    private let rim = CAShapeLayer()
    private let wash = CAGradientLayer()
    private let ripple = CAShapeLayer()
    private let dim = CALayer()
    private let feather = CAGradientLayer()
    private let dimEdges = (0..<4).map { _ in CALayer() }

    private let dimAlpha: CGFloat
    private let restDelay: TimeInterval
    /// System uptime clock, the same timebase as `NSEvent.timestamp`; injectable so rest logic is testable.
    private let now: () -> TimeInterval
    private let fadeDuration: TimeInterval
    private var theme: Theme = .neon
    private var scale: CGFloat = 2

    private enum Phase { case detached, hidden, shown, fading }
    private var phase = Phase.detached
    private var hasBloomed = false
    /// Event time (system uptime) of the last pointer move.
    private var lastMove: TimeInterval = 0
    private var restTask: Task<Void, Never>?
    private var fadeTask: Task<Void, Never>?

    /// - Parameters:
    ///   - dim: alpha of the dim over the rest of the screen, clamped to 0...0.6.
    ///   - restDelay: seconds without movement before the halo fades.
    ///   - now: current time in system uptime, the timebase of the `time` passed to `pointerMoved(to:at:)`.
    public init(
        dim: CGFloat = 0.25,
        restDelay: TimeInterval = 1.5,
        fadeDuration: TimeInterval = 0.45,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        dimAlpha = min(max(dim, 0), 0.6)
        self.restDelay = restDelay
        self.now = now
        self.fadeDuration = fadeDuration
        buildLayers()
    }

    // MARK: Effect

    public func activate(on window: OverlayWindow, tracker: CursorTracker) {
        guard phase == .detached else { return }
        scale = window.backingScaleFactor
        let host = window.rootLayer
        withoutAnimation {
            root.frame = host.bounds
            for layer in [root, body, ring, glowRing, rim, wash, ripple, dim, feather] + dimEdges {
                layer.contentsScale = scale
            }
            root.isHidden = true
            host.addSublayer(root)
        }
        phase = .hidden
    }

    public func deactivate() {
        restTask?.cancel()
        fadeTask?.cancel()
        restTask = nil
        fadeTask = nil
        phase = .detached
        withoutAnimation {
            for layer in [root, body, ripple, dim] { layer.removeAllAnimations() }
            root.removeFromSuperlayer()
        }
    }

    public func apply(theme: Theme) {
        self.theme = theme
        let r = Self.radius
        ring.strokeColor = theme.primary
        ring.lineWidth = theme.ringWidth
        ring.shadowColor = theme.glowColor
        ring.shadowRadius = 2 + 10 * theme.glow
        ring.shadowOpacity = Float(0.35 + 0.65 * theme.glow)
        ring.shadowPath = ring.path?.copy(strokingWithWidth: theme.ringWidth, lineCap: .round, lineJoin: .round, miterLimit: 1)

        glowRing.strokeColor = theme.primary.copy(alpha: 0.22 * theme.glow)
        glowRing.lineWidth = theme.ringWidth * 4
        glowRing.shadowColor = theme.glowColor
        glowRing.shadowRadius = 26 * theme.glow
        glowRing.shadowOpacity = Float(0.8 * theme.glow)
        glowRing.shadowPath = glowRing.path?.copy(strokingWithWidth: theme.ringWidth * 4, lineCap: .round, lineJoin: .round, miterLimit: 1)

        rim.path = Self.circle(radius: r - theme.ringWidth / 2 - 1)
        rim.strokeColor = theme.accent
        rim.lineWidth = 1

        let fill = theme.fillOpacity
        wash.colors = [
            theme.primary.copy(alpha: fill) ?? theme.primary,
            theme.primary.copy(alpha: fill * 0.55) ?? theme.primary,
            theme.primary.copy(alpha: 0) ?? theme.primary,
        ]

        ripple.strokeColor = theme.primary
        ripple.lineWidth = max(theme.ringWidth * 0.75, 1)
    }

    public func pointerMoved(to layerPoint: CGPoint?, at time: TimeInterval) {
        guard phase != .detached else { return }
        guard let layerPoint else {
            hide()
            return
        }
        withoutAnimation {
            if root.frame != root.superlayer?.bounds, let bounds = root.superlayer?.bounds { root.frame = bounds }
            body.position = layerPoint
            layoutDim(around: layerPoint)
            root.isHidden = false
        }
        if !hasBloomed {
            hasBloomed = true
            bloom()
        } else if phase == .fading {
            revive()
        }
        phase = .shown
        lastMove = time
        if restTask == nil { startRestTimer() }
    }

    // MARK: Layers

    private func buildLayers() {
        let r = Self.radius
        root.anchorPoint = .zero
        root.masksToBounds = false

        dim.frame = .zero
        dim.masksToBounds = false
        dim.isHidden = dimAlpha <= 0
        for edge in dimEdges {
            edge.backgroundColor = CGColor(gray: 0, alpha: dimAlpha)
            dim.addSublayer(edge)
        }
        configureFeather()
        dim.addSublayer(feather)
        root.addSublayer(dim)

        body.bounds = .zero
        body.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        wash.type = .radial
        wash.bounds = CGRect(x: 0, y: 0, width: 2 * r, height: 2 * r)
        wash.position = .zero
        wash.startPoint = CGPoint(x: 0.5, y: 0.5)
        wash.endPoint = CGPoint(x: 1, y: 1)
        wash.locations = [0, 0.7, 1]

        for shape in [glowRing, ring, ripple] {
            shape.path = Self.circle(radius: r)
            shape.fillColor = nil
            shape.shadowOffset = .zero
            shape.lineCap = .round
        }
        rim.fillColor = nil
        ripple.opacity = 0

        body.addSublayer(glowRing)
        body.addSublayer(wash)
        body.addSublayer(ring)
        body.addSublayer(rim)
        body.addSublayer(ripple)
        root.addSublayer(body)
        apply(theme: theme)
    }

    /// A square centered on the pointer with a radial ramp from clear to the dim color. Four plain rectangles fill
    /// the rest of the window, so nothing large is re-rasterized as the pointer moves.
    private func configureFeather() {
        let side = Self.featherRadius
        // The gradient's unit radius reaches the square's corner, so the corners get the full dim too.
        let reach = side * 2.squareRoot()
        feather.type = .radial
        feather.startPoint = CGPoint(x: 0.5, y: 0.5)
        feather.endPoint = CGPoint(x: 0.5 + 0.5 * 2.squareRoot(), y: 0.5 + 0.5 * 2.squareRoot())
        var colors: [CGColor] = []
        var locations: [NSNumber] = []
        let steps = 6
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let smooth = t * t * (3 - 2 * t)
            let radius = Self.clearRadius + t * (Self.featherRadius - Self.clearRadius)
            colors.append(CGColor(gray: 0, alpha: dimAlpha * smooth))
            locations.append(NSNumber(value: Double(radius / reach)))
        }
        colors.append(CGColor(gray: 0, alpha: dimAlpha))
        locations.append(1)
        feather.colors = colors
        feather.locations = locations
    }

    private func layoutDim(around point: CGPoint) {
        guard !dim.isHidden else { return }
        let bounds = root.bounds
        let center = PointerGeometry.pixelAligned(point, scale: scale)
        let s = Self.featherRadius
        let square = CGRect(x: center.x - s, y: center.y - s, width: 2 * s, height: 2 * s)
        feather.frame = square
        let below = max(square.minY - bounds.minY, 0)
        let above = max(bounds.maxY - square.maxY, 0)
        let leftWidth = max(square.minX - bounds.minX, 0)
        let rightWidth = max(bounds.maxX - square.maxX, 0)
        dimEdges[0].frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: below)
        dimEdges[1].frame = CGRect(x: bounds.minX, y: square.maxY, width: bounds.width, height: above)
        dimEdges[2].frame = CGRect(x: bounds.minX, y: square.minY, width: leftWidth, height: square.height)
        dimEdges[3].frame = CGRect(x: square.maxX, y: square.minY, width: rightWidth, height: square.height)
    }

    // MARK: Motion

    private func bloom() {
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.3
        spring.toValue = 1
        spring.mass = 1
        spring.stiffness = 240
        spring.damping = 15
        spring.initialVelocity = 0
        spring.duration = spring.settlingDuration
        body.add(spring, forKey: "bloom")

        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.toValue = 1
        appear.duration = 0.18
        appear.timingFunction = CAMediaTimingFunction(name: .easeOut)
        body.add(appear, forKey: "appear")

        let dimIn = CABasicAnimation(keyPath: "opacity")
        dimIn.fromValue = 0
        dimIn.toValue = 1
        dimIn.duration = 0.35
        dimIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        dim.add(dimIn, forKey: "appear")

        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 1
        grow.toValue = 2.2
        let vanish = CABasicAnimation(keyPath: "opacity")
        vanish.fromValue = 0.8
        vanish.toValue = 0
        let wave = CAAnimationGroup()
        wave.animations = [grow, vanish]
        wave.duration = 0.75
        wave.beginTime = CACurrentMediaTime() + 0.08
        wave.fillMode = .backwards
        wave.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1)
        ripple.add(wave, forKey: "ripple")
    }

    /// True once the pointer has not moved for `restAfter` seconds. All times are system uptime.
    nonisolated static func hasRested(lastMove: TimeInterval, now: TimeInterval, restAfter: TimeInterval) -> Bool {
        now - lastMove >= restAfter
    }

    var isFading: Bool { phase == .fading }

    /// Starts the fade if the pointer has rested long enough. The timer calls it; tests call it with a fake clock.
    func checkRest() {
        guard phase == .shown, Self.hasRested(lastMove: lastMove, now: now(), restAfter: restDelay) else { return }
        beginFade()
    }

    /// Ends a fade that ran to completion. The fade timer calls it; tests call it directly.
    func completeFade() {
        guard phase == .fading else { return }
        fadeTask?.cancel()
        fadeTask = nil
        onFinish?()
    }

    /// Sleeps until the rest deadline, re-checking after each move pushed it back.
    private func startRestTimer() {
        restTask = Task { [weak self] in
            while true {
                guard let self, !Task.isCancelled, self.phase == .shown else { return }
                let current = self.now()
                if Self.hasRested(lastMove: self.lastMove, now: current, restAfter: self.restDelay) { break }
                let remaining = self.restDelay - (current - self.lastMove)
                try? await Task.sleep(for: .seconds(remaining))
            }
            self?.restTask = nil
            self?.checkRest()
        }
    }

    private func beginFade() {
        restTask?.cancel()
        restTask = nil
        guard phase == .shown else { return }
        phase = .fading
        animateOpacity(to: 0, duration: fadeDuration)
        let settle = CABasicAnimation(keyPath: "transform.scale")
        settle.fromValue = body.presentation()?.value(forKeyPath: "transform.scale") ?? 1
        settle.toValue = 0.9
        settle.duration = fadeDuration
        settle.timingFunction = CAMediaTimingFunction(name: .easeIn)
        settle.fillMode = .forwards
        settle.isRemovedOnCompletion = false
        body.add(settle, forKey: "settle")

        let delay = fadeDuration
        fadeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.completeFade()
        }
    }

    private func revive() {
        fadeTask?.cancel()
        fadeTask = nil
        body.removeAnimation(forKey: "settle")
        animateOpacity(to: 1, duration: 0.15)
    }

    private func hide() {
        restTask?.cancel()
        fadeTask?.cancel()
        restTask = nil
        fadeTask = nil
        phase = .hidden
        withoutAnimation {
            root.isHidden = true
            root.removeAnimation(forKey: "fade")
            body.removeAnimation(forKey: "settle")
            root.opacity = 1
        }
    }

    private func animateOpacity(to target: Float, duration: TimeInterval) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = root.presentation()?.opacity ?? root.opacity
        fade.toValue = target
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: target > 0 ? .easeOut : .easeInEaseOut)
        withoutAnimation { root.opacity = target }
        root.add(fade, forKey: "fade")
    }

    private func withoutAnimation(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    private static func circle(radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: 2 * radius, height: 2 * radius), transform: nil)
    }
}
