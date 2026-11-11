import AppKit
import QuartzCore

/// Maps `HighlightFrame`s to Core Animation layers on one overlay window. Holds no behavior of its own: every value
/// comes from the frame and the style recipe. Glows are cached bitmaps; only rings and the comet tail get new paths
/// per frame.
@MainActor
final class HighlightRenderer {
    let root = CALayer()
    private(set) var style: HighlightStyle
    private let scale: CGFloat

    /// Centered on the highlight; carries the transform (stretch, pop, breath, press).
    let body = CALayer()
    private let styleLayer = CALayer()
    private var pulse: RingLayer
    private var sonarRings: [RingLayer] = []
    private var ripples: [RingLayer] = []
    private var pressRing: RingLayer

    // Lens
    private let dim = CALayer()
    private let feather = CALayer()
    private let wash = CALayer()
    private let dimEdges = (0..<4).map { _ in CALayer() }
    /// 0...1: the dim shows only on the display that has the pointer, and eases across when it moves.
    private var dimPresence: CGFloat = 0
    private var lastTime: TimeInterval?

    // Comet
    private let tail = CALayer()
    private let tailGradient = CAGradientLayer()
    private let tailMask = CAShapeLayer()
    private let tailCore = CAShapeLayer()
    private var stamps: [CALayer] = []
    private var stampImages: [CGImage] = []

    init(style: HighlightStyle, scale: CGFloat) {
        self.style = style
        self.scale = max(scale, 1)
        pulse = RingLayer(scale: self.scale)
        pressRing = RingLayer(scale: self.scale)
        root.anchorPoint = .zero
        root.masksToBounds = false
        build()
    }

    /// True while the renderer's own easing (the dim moving between displays) still needs frames.
    var isSettled: Bool { dimPresence == 0 || dimPresence == 1 }

    func attach(to host: CALayer) {
        withoutAnimation {
            root.frame = host.bounds
            host.addSublayer(root)
        }
    }

    func detach() {
        withoutAnimation { root.removeFromSuperlayer() }
    }

    func configure(style: HighlightStyle) {
        guard style != self.style else { return }
        self.style = style
        withoutAnimation {
            root.sublayers?.forEach { $0.removeFromSuperlayer() }
            body.sublayers?.forEach { $0.removeFromSuperlayer() }
            styleLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            build()
        }
    }

    // MARK: Build

    private func build() {
        let recipe = style.recipe
        let accent = Palette.accent(for: style)
        body.bounds = .zero
        body.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        body.setAffineTransform(.identity)
        body.isHidden = style == .lens
        styleLayer.anchorPoint = .zero
        styleLayer.bounds = .zero

        pulse = RingLayer(scale: scale)
        pressRing = RingLayer(scale: scale)
        ripples = (0..<recipe.ripple.maxConcurrent).map { _ in RingLayer(scale: scale) }
        sonarRings = []

        switch style {
        case .aura: buildAura(recipe.aura, accent: accent)
        case .lens: buildLens(recipe.lens)
        case .comet: buildComet(recipe.comet, accent: accent)
        case .keyline: buildKeyline(recipe.keyline)
        case .sonar: buildSonar(recipe.sonar, accent: accent)
        }

        if style == .lens { root.addSublayer(dim) }
        root.addSublayer(styleLayer)
        styleLayer.addSublayer(pulse.container)
        if style == .comet { styleLayer.addSublayer(tail) }
        styleLayer.addSublayer(body)
        styleLayer.isHidden = true
        for ring in ripples { root.addSublayer(ring.container) }
        root.addSublayer(pressRing.container)
        for layer in allLayers(of: root) { layer.contentsScale = scale }
    }

    private func buildAura(_ aura: AuraRecipe, accent: RGBA) {
        let coreColor = accent.mixed(with: Palette.light, Double(aura.coreLightness))
        let specs: [(String, GlowLayerRecipe, RGBA)] = [
            ("aura.outer", aura.outer, accent), ("aura.mid", aura.mid, accent), ("aura.core", aura.core, coreColor),
        ]
        for (name, spec, color) in specs {
            let sprite = SpriteFactory.blurredDisk(
                name: name, radius: aura.radius * spec.radiusFactor, blur: spec.blur, peak: spec.alpha,
                scale: scale, color: color
            )
            body.addSublayer(spriteLayer(sprite.image, extent: sprite.extent))
        }
        let bands = PointerGeometry.ringBands(edges: [aura.radius, aura.radius + aura.keylineWidth], scale: scale)
        if let band = bands.first {
            let keyline = CAShapeLayer()
            keyline.path = RingLayer.circle(band.radius)
            keyline.lineWidth = band.width
            keyline.fillColor = nil
            keyline.strokeColor = Palette.keyline.with(alpha: Double(aura.keylineAlpha)).cgColor
            body.addSublayer(keyline)
        }
    }

    private func buildLens(_ lens: LensRecipe) {
        let inner = lens.radius * (1 - lens.feather)
        let dimAlpha = lens.dim
        dim.sublayers?.forEach { $0.removeFromSuperlayer() }
        dim.anchorPoint = .zero
        dim.frame = .zero
        dim.masksToBounds = false
        dim.opacity = 0
        for edge in dimEdges {
            edge.backgroundColor = CGColor(gray: 0, alpha: dimAlpha)
            dim.addSublayer(edge)
        }
        // The feather's square is the circle's bounding square, so its corners already carry the full dim.
        feather.contents = SpriteFactory.radial(
            name: "lens.feather", extent: lens.radius, scale: scale, color: RGBA(0, 0, 0)
        ) { d in dimAlpha * CGFloat(Easing.smoothstep(Double(inner), Double(lens.radius), Double(d))) }
        dim.addSublayer(feather)
        wash.contents = SpriteFactory.radial(
            name: "lens.wash", extent: lens.radius, scale: scale, color: Palette.light
        ) { d in lens.washAlpha * CGFloat(1 - Easing.smoothstep(0, Double(inner), Double(d))) }
        dim.addSublayer(wash)
    }

    private func buildComet(_ comet: CometRecipe, accent: RGBA) {
        tail.sublayers?.forEach { $0.removeFromSuperlayer() }
        tail.anchorPoint = .zero
        tail.bounds = .zero
        // Glow pass: soft stamps tinted from head hue to tail hue (six steps of the 25 degree shift).
        stampImages = (0..<6).compactMap { step in
            let color = accent.hueRotated(by: comet.hueShift * Double(step) / 5)
            return SpriteFactory.radial(name: "comet.stamp.\(step)", extent: 16, scale: 2, color: color) { d in
                CGFloat(exp(-Double(d * d) / (2 * 5.3 * 5.3)))
            }
        }
        stamps = (0..<comet.maxPoints).map { _ in
            let layer = CALayer()
            layer.isHidden = true
            tail.addSublayer(layer)
            return layer
        }
        // Body: tapered polygon filled with a head-to-tail gradient.
        tailGradient.type = .axial
        tailGradient.mask = tailMask
        tailMask.fillColor = CGColor(gray: 1, alpha: 1)
        tailMask.shadowOpacity = 0
        tail.addSublayer(tailGradient)
        // Crisp light core inside the body.
        tailCore.fillColor = Palette.light.with(alpha: 0.95).cgColor
        tail.addSublayer(tailCore)

        // Head: accent halo, light dot with an accent rim and a dark keyline.
        let halo = SpriteFactory.blurredDisk(
            name: "comet.halo", radius: comet.headDiameter / 2, blur: comet.headHaloDiameter / 2 - comet.headDiameter / 4,
            peak: 0.7, scale: scale, color: accent
        )
        body.addSublayer(spriteLayer(halo.image, extent: halo.extent))
        let r = comet.headDiameter / 2
        let bands = PointerGeometry.ringBands(edges: [r - 2, r, r + 1], scale: scale)
        let dot = CAShapeLayer()
        dot.path = RingLayer.circle(r - 1)
        dot.fillColor = Palette.light.cgColor
        body.addSublayer(dot)
        if bands.count == 2 {
            body.addSublayer(stroke(bands[0], color: accent))
            body.addSublayer(stroke(bands[1], color: Palette.keyline.with(alpha: 0.35)))
        }
    }

    private func buildKeyline(_ keyline: KeylineRecipe) {
        let r = keyline.radius
        let half = keyline.lightWidth / 2
        let bands = PointerGeometry.ringBands(
            edges: [r - half - keyline.darkWidth, r - half, r + half, r + half + keyline.darkWidth], scale: scale
        )
        if bands.count == 3 {
            body.addSublayer(stroke(bands[0], color: Palette.keyline.with(alpha: Double(keyline.innerDarkAlpha))))
            body.addSublayer(stroke(bands[1], color: Palette.light.with(alpha: 0.95)))
            body.addSublayer(stroke(bands[2], color: Palette.keyline.with(alpha: Double(keyline.darkAlpha))))
        }
        let dotRadius = keyline.dotDiameter / 2
        let dotBands = PointerGeometry.ringBands(edges: [dotRadius, dotRadius + 1], scale: scale)
        let dot = CAShapeLayer()
        dot.path = RingLayer.circle(dotRadius)
        dot.fillColor = Palette.light.cgColor
        body.addSublayer(dot)
        if let band = dotBands.first {
            body.addSublayer(stroke(band, color: Palette.keyline.with(alpha: Double(keyline.darkAlpha))))
        }
    }

    private func buildSonar(_ sonar: SonarRecipe, accent: RGBA) {
        sonarRings = (0..<sonar.ringCount).map { _ in
            let ring = RingLayer(scale: scale)
            styleLayer.addSublayer(ring.container)
            return ring
        }
        let glow = SpriteFactory.blurredDisk(
            name: "sonar.glow", radius: sonar.dotRadius * 0.45, blur: sonar.dotRadius * 0.9, peak: 0.6,
            scale: scale, color: accent
        )
        body.addSublayer(spriteLayer(glow.image, extent: glow.extent))
        let r = sonar.dotCoreRadius
        let core = CAShapeLayer()
        core.path = RingLayer.circle(r)
        core.fillColor = Palette.light.cgColor
        body.addSublayer(core)
        let bands = PointerGeometry.ringBands(edges: [r, r + 1.5, r + 2.5], scale: scale)
        if bands.count == 2 {
            body.addSublayer(stroke(bands[0], color: accent))
            body.addSublayer(stroke(bands[1], color: Palette.keyline.with(alpha: 0.35)))
        }
    }

    private func spriteLayer(_ image: CGImage?, extent: CGFloat) -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 2 * extent, height: 2 * extent)
        layer.position = .zero
        layer.contents = image
        return layer
    }

    private func stroke(_ band: (radius: CGFloat, width: CGFloat), color: RGBA) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = RingLayer.circle(band.radius)
        layer.lineWidth = band.width
        layer.fillColor = nil
        layer.strokeColor = color.cgColor
        return layer
    }

    // MARK: Render

    /// - Parameters:
    ///   - windowFrame: the window's frame in global coordinates.
    ///   - isOwner: whether this window's display has the pointer (only it shows the Lens dim).
    func render(_ frame: HighlightFrame, windowFrame: CGRect, isOwner: Bool) {
        let origin = windowFrame.origin
        let dt = lastTime.map { max(frame.time - $0, 0) } ?? 0
        lastTime = frame.time
        withoutAnimation {
            if root.frame.size != windowFrame.size, let bounds = root.superlayer?.bounds { root.frame = bounds }
            renderStyle(frame, origin: origin, isOwner: isOwner, dt: dt)
            renderRipples(frame, origin: origin)
        }
    }

    private func renderStyle(_ frame: HighlightFrame, origin: CGPoint, isOwner: Bool, dt: TimeInterval) {
        let local = CGPoint(x: frame.center.x - origin.x, y: frame.center.y - origin.y)
        // At rest the highlight sits on the pointer, snapped to the device pixel the cursor is drawn on, so the
        // static rings are crisp. While moving it stays sub-pixel smooth.
        let center = frame.isSettled ? PointerGeometry.pixelAligned(local, scale: scale) : local

        if style == .lens {
            let target: CGFloat = isOwner && frame.isShown ? 1 : 0
            dimPresence += (target - dimPresence) * CGFloat(1 - exp(-dt / 0.08))
            if abs(dimPresence - target) < 0.01 { dimPresence = target }
            dim.opacity = Float(frame.dimLevel * dimPresence)
            dim.isHidden = dimPresence == 0 && !frame.isShown
            layoutLens(around: center, scale: frame.lensScale)
        }

        styleLayer.isHidden = !frame.isShown
        guard frame.isShown else { return }
        let accent = Palette.accent(for: style)
        let pulseColor = style == .keyline ? Palette.light : accent.mixed(with: Palette.light, 0.4)
        pulse.update(
            frame.pulse, origin: origin, color: pulseColor, fillColor: accent, double: false, keylineAlpha: 0.3,
            scale: scale
        )

        body.position = center
        body.opacity = Float(frame.level * frame.breathAlpha)
        switch style {
        case .aura:
            body.setAffineTransform(frame.stretch.transform.scaledBy(x: frame.bodyScale, y: frame.bodyScale))
        case .lens:
            body.isHidden = true
        case .comet:
            body.setAffineTransform(CGAffineTransform(scaleX: frame.bodyScale, y: frame.bodyScale))
            tail.opacity = Float(frame.level)
            renderTail(frame.trail, origin: origin)
        case .keyline:
            body.setAffineTransform(CGAffineTransform(scaleX: frame.bodyScale, y: frame.bodyScale))
        case .sonar:
            body.opacity = Float(frame.dotLevel)
            body.setAffineTransform(CGAffineTransform(scaleX: frame.bodyScale, y: frame.bodyScale))
            for (index, ring) in sonarRings.enumerated() {
                let state = index < frame.sonarRings.count ? frame.sonarRings[index] : nil
                ring.update(
                    state, origin: origin, color: accent.mixed(with: Palette.light, 0.2), fillColor: accent,
                    double: false, keylineAlpha: 0.35, scale: scale
                )
            }
        }
    }

    private func layoutLens(around center: CGPoint, scale lensScale: CGFloat) {
        guard !dim.isHidden else { return }
        let bounds = root.bounds
        let half = PointerGeometry.snapped(style.recipe.lens.radius * lensScale, scale: scale)
        let c = PointerGeometry.pixelAligned(center, scale: scale)
        let square = CGRect(x: c.x - half, y: c.y - half, width: 2 * half, height: 2 * half)
        feather.frame = square
        wash.frame = square
        let below = max(square.minY - bounds.minY, 0)
        let above = max(bounds.maxY - square.maxY, 0)
        let left = max(square.minX - bounds.minX, 0)
        let right = max(bounds.maxX - square.maxX, 0)
        dimEdges[0].frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: below)
        dimEdges[1].frame = CGRect(x: bounds.minX, y: square.maxY, width: bounds.width, height: above)
        dimEdges[2].frame = CGRect(x: bounds.minX, y: square.minY, width: left, height: square.height)
        dimEdges[3].frame = CGRect(x: square.maxX, y: square.minY, width: right, height: square.height)
    }

    private func renderTail(_ trail: [TrailPoint], origin: CGPoint) {
        let comet = style.recipe.comet
        let points = trail.map { point -> TrailPoint in
            var p = point
            p.point = CGPoint(x: point.point.x - origin.x, y: point.point.y - origin.y)
            return p
        }
        guard points.count >= 2, let head = points.last, let end = points.first else {
            tail.isHidden = true
            return
        }
        tail.isHidden = false

        // Body polygon and gradient.
        let outline = Self.taperedOutline(points) { $0.width }
        let box = outline.boundingBoxOfPath.insetBy(dx: -2, dy: -2)
        tailGradient.frame = box
        var shifted = CGAffineTransform(translationX: -box.minX, y: -box.minY)
        tailMask.frame = CGRect(origin: .zero, size: box.size)
        tailMask.path = outline.copy(using: &shifted)
        tailGradient.startPoint = unit(head.point, in: box)
        tailGradient.endPoint = unit(end.point, in: box)
        let accent = Palette.accent(for: style)
        let stops = 6
        tailGradient.colors = (0..<stops).map { index in
            let u = Double(index) / Double(stops - 1)
            let age = head.age + (end.age - head.age) * u
            let alpha = TrailBuffer.alpha(age: age, recipe: comet)
            return accent.hueRotated(by: comet.hueShift * age).with(alpha: Double(alpha)).cgColor
        }
        tailGradient.locations = (0..<stops).map { NSNumber(value: Double($0) / Double(stops - 1)) }

        // Core: same taper scaled to the core width, only over the younger part of the tail.
        let young = points.filter { $0.age < 0.7 }
        tailCore.path = young.count >= 2
            ? Self.taperedOutline(young) { $0.width * comet.coreWidth / comet.headWidth }
            : nil

        // Glow stamps at even arc-length spacing from the head, compensated for overlap so the stack reaches the
        // glow alpha and no more. Even spacing keeps the glow from beading.
        let total = zip(points, points.dropFirst()).reduce(CGFloat(0)) { $0 + hypot($1.1.point.x - $1.0.point.x, $1.1.point.y - $1.0.point.y) }
        let spacing = max(4, total / CGFloat(max(stamps.count - 1, 1)))
        var used = 0
        for p in Self.resample(Array(points.reversed()), every: spacing) where used < stamps.count {
            let diameter = p.width + comet.glowWidth
            let overlap = max(Double(diameter / spacing), 1)
            let target = Double(comet.glowAlpha * p.alpha / comet.headAlpha)
            let perStamp = 1 - pow(1 - min(target, 0.99), 1 / overlap)
            let layer = stamps[used]
            layer.isHidden = false
            layer.contents = stampImages.isEmpty ? nil : stampImages[min(Int((p.age * 5).rounded()), stampImages.count - 1)]
            layer.bounds = CGRect(x: 0, y: 0, width: diameter * 1.5, height: diameter * 1.5)
            layer.position = p.point
            layer.opacity = Float(perStamp)
            used += 1
        }
        for layer in stamps[used...] { layer.isHidden = true }
    }

    /// Points every `spacing` points of arc length along a polyline, interpolating width, alpha and age.
    static func resample(_ points: [TrailPoint], every spacing: CGFloat) -> [TrailPoint] {
        guard let first = points.first, spacing > 0 else { return [] }
        var result = [first]
        var carried: CGFloat = 0
        for (a, b) in zip(points, points.dropFirst()) {
            let length = hypot(b.point.x - a.point.x, b.point.y - a.point.y)
            guard length > 0 else { continue }
            var along = spacing - carried
            while along <= length {
                let t = along / length
                result.append(TrailPoint(
                    point: CGPoint(x: a.point.x + (b.point.x - a.point.x) * t, y: a.point.y + (b.point.y - a.point.y) * t),
                    age: a.age + (b.age - a.age) * Double(t),
                    width: a.width + (b.width - a.width) * t,
                    alpha: a.alpha + (b.alpha - a.alpha) * t
                ))
                along += spacing
            }
            carried = length - (along - spacing)
        }
        return result
    }

    private func unit(_ point: CGPoint, in box: CGRect) -> CGPoint {
        CGPoint(x: (point.x - box.minX) / max(box.width, 1), y: (point.y - box.minY) / max(box.height, 1))
    }

    /// A closed outline around a polyline with a per-point width: left side tail to head, right side back.
    static func taperedOutline(_ points: [TrailPoint], width: (TrailPoint) -> CGFloat) -> CGPath {
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for (i, p) in points.enumerated() {
            let a = points[max(i - 1, 0)].point
            let b = points[min(i + 1, points.count - 1)].point
            var nx = -(b.y - a.y)
            var ny = b.x - a.x
            let length = hypot(nx, ny)
            if length > 0 {
                nx /= length
                ny /= length
            }
            let half = width(p) / 2
            left.append(CGPoint(x: p.point.x + nx * half, y: p.point.y + ny * half))
            right.append(CGPoint(x: p.point.x - nx * half, y: p.point.y - ny * half))
        }
        let path = CGMutablePath()
        path.addLines(between: left + right.reversed())
        path.closeSubpath()
        return path
    }

    private func renderRipples(_ frame: HighlightFrame, origin: CGPoint) {
        let recipe = style.recipe.ripple
        for (index, ring) in ripples.enumerated() {
            let state = index < frame.ripples.count ? frame.ripples[index] : nil
            update(ring, state, origin: origin, recipe: recipe)
        }
        update(pressRing, frame.press, origin: origin, recipe: recipe)
    }

    private func update(_ ring: RingLayer, _ state: RingState?, origin: CGPoint, recipe: RippleRecipe) {
        let button = state?.button ?? .left
        let accent = Palette.rippleAccent(for: style, button: button)
        let color = recipe.lightRing && button == .left ? Palette.light : accent
        ring.update(
            state, origin: origin, color: color, fillColor: accent, double: button == .right,
            keylineAlpha: recipe.lightRing ? 0.45 : 0.3, scale: scale
        )
    }

    // MARK: Helpers

    private func allLayers(of layer: CALayer) -> [CALayer] {
        [layer] + (layer.sublayers ?? []).flatMap { allLayers(of: $0) } + (layer.mask.map { allLayers(of: $0) } ?? [])
    }

    private func withoutAnimation(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }
}
