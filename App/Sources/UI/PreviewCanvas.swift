import CursorlightCore
import SwiftUI

/// An animated stand-in for a highlight style on a fake window, driven by the real style recipes and the user's look.
/// It is a drawing of the effect, not the renderer itself, so small differences from the real overlay are expected.
struct PreviewCanvas: View {
    let style: HighlightStyle
    let look: HighlightLook
    var height: CGFloat = 210

    var body: some View {
        ZStack {
            DesktopLayer(scene: .slides)
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    Self.draw(&context, size: size, time: timeline.date.timeIntervalSinceReferenceDate, style: style, look: look)
                }
            }
        }
        .frame(height: height)
        .background(
            LinearGradient(colors: [Color(red: 0.14, green: 0.15, blue: 0.20), Color(red: 0.09, green: 0.09, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line))
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                Text(style.displayName).fontWeight(.semibold).foregroundStyle(Theme.text)
                Text("preview").foregroundStyle(Theme.dim)
            }
            .font(.system(size: 11)).padding(12)
        }
        .accessibilityLabel("\(style.displayName) preview")
    }

    /// The miniature screen inside the canvas: 16 by 10, centered, with room around it.
    static func screenRect(in size: CGSize) -> CGRect {
        let avail = CGRect(x: 56, y: 60, width: max(size.width - 112, 160), height: max(size.height - 132, 100))
        let width = min(avail.width, avail.height * 1.6)
        let height = width / 1.6
        return CGRect(x: avail.midX - width / 2, y: avail.midY - height / 2, width: width, height: height)
    }

    /// Recent pointer positions, so a trail can look back in time while the mouse drives the preview.
    final class PointerHistory {
        private var samples: [(point: CGPoint, time: Double)] = []

        func record(_ point: CGPoint, at time: Double) {
            samples.append((point, time))
            while let first = samples.first, first.time < time - 1 { samples.removeFirst() }
        }

        func position(at time: Double) -> CGPoint? {
            samples.last { $0.time <= time }?.point ?? samples.first?.point
        }
    }

    /// How much smaller the effect is drawn than on a real screen, so it keeps its real proportion to the content.
    static func effectScale(for screen: CGRect) -> CGFloat {
        min(max(screen.width / 1440, 0.55), 1)
    }

    /// The effect on top of the display. The display itself is `DesktopLayer`.
    static func draw(
        _ context: inout GraphicsContext, size: CGSize, time: Double, style: HighlightStyle, look: HighlightLook,
        pointer: CGPoint? = nil, history: PointerHistory? = nil, scene: PreviewScene = .slides,
        clicks: [PreviewClick] = [], ripples: Bool = true, lastHoverMove: Double? = nil
    ) {
        let screen = screenRect(in: size)
        let s = effectScale(for: screen)
        let auto: (Double) -> CGPoint = { Autopilot.point(at: $0, scene: scene, in: screen) }
        // The real mouse only drives the effect while it is over the display; in the margin the autopilot carries on.
        let pointer = pointer.flatMap { screen.contains($0) ? $0 : nil }
        let raw = pointer ?? auto(time)
        history?.record(raw, at: time)

        var fx = context
        fx.clip(to: Path(roundedRect: screen, cornerRadius: 12))
        fx.scaleBy(x: s, y: s)
        let unscale: (CGPoint) -> CGPoint = { CGPoint(x: $0.x / s, y: $0.y / s) }
        let p = unscale(raw)
        let recipe = style.recipe.applying(look)
        let accent = Color(rgba: look.accentColor(for: style))
        let light = Color(rgba: Palette.light)
        // Fade when still: the real mouse uses the real timer; the autopilot rests briefly, so its timer is shortened.
        var idle = 1.0
        let after = look.options.fadeAfterStill
        if after > 0 {
            let still = pointer != nil ? time - (lastHoverMove ?? time) : Autopilot.stillTime(at: time, scene: scene)
            let threshold = pointer != nil ? after : min(after, 0.9)
            idle = max(0, min(1, 1 - (still - threshold) / 0.8))
        }
        fx.opacity = Double(look.intensity) * idle

        switch style {
        case .aura:
            let r = recipe.aura.radius
            let breath = recipe.aura.breathCycles > 0 ? 1 + 0.03 * sin(time * 2 * .pi / recipe.aura.breathPeriod) : 1
            glow(&fx, at: p, radius: r * recipe.aura.outer.radiusFactor * breath, color: accent, alpha: 0.10)
            glow(&fx, at: p, radius: r * 1.15 * breath, color: accent, alpha: 0.26)
            glow(&fx, at: p, radius: r * recipe.aura.core.radiusFactor * 1.4, color: Color(rgba: look.accentColor(for: style).mixed(with: Palette.light, 0.75)), alpha: 0.6)
        case .lens:
            let r = recipe.lens.radius * 0.8
            let cover = CGRect(x: 0, y: 0, width: size.width / s, height: size.height / s)
            fx.drawLayer { layer in
                layer.fill(Path(cover), with: .color(.black.opacity(recipe.lens.dim)))
                layer.blendMode = .destinationOut
                let hole = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                layer.fill(hole, with: .radialGradient(
                    Gradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 1 - Double(recipe.lens.feather)), .init(color: .clear, location: 1)]),
                    center: p, startRadius: 0, endRadius: r
                ))
            }
        case .comet:
            let steps = max(6, min(Int((18 * recipe.comet.lifetime / 0.4).rounded()), 40))
            for k in stride(from: steps, through: 1, by: -1) {
                let when = time - Double(k) * 0.022
                let q = unscale(history?.position(at: when) ?? auto(when))
                let a = 1 - Double(k) / Double(steps)
                let d = recipe.comet.headDiameter * (0.25 + 0.75 * a)
                fx.fill(Path(ellipseIn: CGRect(x: q.x - d / 2, y: q.y - d / 2, width: d, height: d)), with: .color(accent.opacity(0.75 * a * a)))
            }
            glow(&fx, at: p, radius: recipe.comet.headHaloDiameter, color: accent, alpha: 0.5)
            let d = recipe.comet.headDiameter
            let head = Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d))
            fx.fill(head, with: .color(light))
            fx.stroke(head, with: .color(accent), lineWidth: 2)
        case .keyline:
            let r = recipe.keyline.radius
            let ring = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            fx.stroke(ring, with: .color(.black.opacity(0.35)), lineWidth: recipe.keyline.lightWidth + 2)
            fx.stroke(ring, with: .color(light), lineWidth: recipe.keyline.lightWidth)
            let dot = recipe.keyline.dotDiameter
            fx.fill(Path(ellipseIn: CGRect(x: p.x - dot / 2, y: p.y - dot / 2, width: dot, height: dot)), with: .color(light))
        case .crosshair:
            let gap = recipe.crosshair.gap
            var arms = Path()
            for d in [CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: -1)] {
                arms.move(to: CGPoint(x: p.x + d.x * gap, y: p.y + d.y * gap))
                arms.addLine(to: CGPoint(x: p.x + d.x * 4000, y: p.y + d.y * 4000))
            }
            fx.stroke(arms, with: .color(.black.opacity(0.3)), lineWidth: recipe.crosshair.lineWidth + 2)
            fx.stroke(arms, with: .color(accent.opacity(Double(recipe.crosshair.armAlpha))), lineWidth: recipe.crosshair.lineWidth)
            let r = recipe.crosshair.ringRadius
            fx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(accent), lineWidth: 1.5)
        case .sonar:
            for i in 0..<recipe.sonar.ringCount {
                let phase = ((time + Double(i) * 0.25).truncatingRemainder(dividingBy: 2.2)) / 2.2
                let r = recipe.sonar.startRadius * (1 - phase) + recipe.sonar.endRadius * phase
                let ring = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                fx.stroke(ring, with: .color(accent.opacity(0.7 * sin(phase * .pi))), lineWidth: 2)
            }
            glow(&fx, at: p, radius: recipe.sonar.dotRadius, color: accent, alpha: 0.5)
            let c = recipe.sonar.dotCoreRadius
            fx.fill(Path(ellipseIn: CGRect(x: p.x - c, y: p.y - c, width: 2 * c, height: 2 * c)), with: .color(light))
        }
        fx.opacity = 1

        if ripples {
            var all = clicks
            if pointer == nil, let age = Autopilot.clickAge(at: time, scene: scene) {
                all.append(PreviewClick(point: auto(time - age), time: time - age))
            }
            for click in all {
                let age = time - click.time
                guard age >= 0, age < Autopilot.rippleLength else { continue }
                let base = look.accentColor(for: style)
                let tint = Color(rgba: Palette.rippleAccent(base: base, button: click.right ? .right : .left))
                drawRipple(&fx, at: unscale(click.point), phase: age / Autopilot.rippleLength, color: tint, effect: look.options.clickEffect)
            }
        }
        // With the real mouse on the preview, the real cursor is already there.
        if pointer == nil { drawArrow(&fx, at: p) }
    }

    private static func drawRipple(_ context: inout GraphicsContext, at p: CGPoint, phase: Double, color: Color, effect: ClickEffect = .ripple) {
        func ring(_ phase: Double, scale: CGFloat = 1, dashed: Bool = false, filled: Double = 0.22, width: CGFloat = 3) {
            guard phase >= 0, phase < 1 else { return }
            let e = 1 - pow(1 - phase, 3)
            let r = (8 + 46 * e) * scale
            let fade = 1 - phase
            let rect = CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
            if filled > 0 { context.fill(Path(ellipseIn: rect), with: .color(color.opacity(filled * fade))) }
            context.stroke(
                Path(ellipseIn: rect), with: .color(color.opacity(0.85 * fade)),
                style: StrokeStyle(lineWidth: 1 + width * fade, lineCap: .round, dash: dashed ? [1.5, 9] : [])
            )
        }
        switch effect {
        case .ripple: ring(phase)
        case .doubleRing: ring(phase); ring(phase - 0.2)
        case .burst: ring(phase, scale: 1.25, dashed: true, filled: 0, width: 4)
        case .pulse: ring(phase, scale: 1.2, filled: 0.5, width: 0.5)
        }
    }

    private static func glow(_ context: inout GraphicsContext, at p: CGPoint, radius: CGFloat, color: Color, alpha: Double) {
        let rect = CGRect(x: p.x - radius, y: p.y - radius, width: 2 * radius, height: 2 * radius)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(stops: [
                .init(color: color.opacity(alpha), location: 0),
                .init(color: color.opacity(alpha * 0.45), location: 0.55),
                .init(color: color.opacity(0), location: 1),
            ]),
            center: p, startRadius: 0, endRadius: radius
        ))
    }

    private static func drawArrow(_ context: inout GraphicsContext, at p: CGPoint) {
        var path = Path()
        path.move(to: CGPoint(x: p.x, y: p.y))
        path.addLine(to: CGPoint(x: p.x + 11, y: p.y + 11))
        path.addLine(to: CGPoint(x: p.x + 6, y: p.y + 11.5))
        path.addLine(to: CGPoint(x: p.x + 9, y: p.y + 17.5))
        path.addLine(to: CGPoint(x: p.x + 6.8, y: p.y + 18.5))
        path.addLine(to: CGPoint(x: p.x + 3.8, y: p.y + 12.5))
        path.addLine(to: CGPoint(x: p.x, y: p.y + 16))
        path.closeSubpath()
        context.fill(path, with: .color(.white))
        context.stroke(path, with: .color(Color(white: 0.07)), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
    }
}

/// Small static thumbnails for the style cards.
struct StyleThumbnail: View {
    let style: HighlightStyle
    /// The scene's own color; nil uses the style's default.
    var color: Color? = nil
    /// Draws the effect larger or smaller, to mirror the scene's size setting.
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            let accent = color ?? Color(rgba: Palette.accent(for: style))
            switch style {
            case .aura:
                Circle().fill(RadialGradient(colors: [Color(white: 0.9).opacity(0.75), accent.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 24)).frame(width: 48, height: 48)
            case .lens:
                Rectangle().fill(RadialGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .clear, location: 0.35), .init(color: .black.opacity(0.65), location: 0.6)], center: .center, startRadius: 0, endRadius: 34))
            case .comet:
                Capsule().fill(LinearGradient(colors: [.clear, accent], startPoint: .leading, endPoint: .trailing)).frame(width: 34, height: 3).rotationEffect(.degrees(-14)).offset(x: -8, y: 5)
                Circle().fill(.white).frame(width: 9, height: 9).overlay(Circle().stroke(accent, lineWidth: 2)).offset(x: 14, y: -4)
            case .keyline:
                Circle().stroke(.white, lineWidth: 2.5).frame(width: 30, height: 30)
            case .crosshair:
                Rectangle().fill(accent.opacity(0.85)).frame(width: 60, height: 1.5).mask(
                    HStack(spacing: 0) { Color.black.frame(width: 21); Color.clear.frame(width: 18); Color.black.frame(width: 21) }
                )
                Rectangle().fill(accent.opacity(0.85)).frame(width: 1.5, height: 60).mask(
                    VStack(spacing: 0) { Color.black.frame(height: 21); Color.clear.frame(height: 18); Color.black.frame(height: 21) }
                )
                Circle().stroke(accent, lineWidth: 1.5).frame(width: 14, height: 14)
            case .sonar:
                Circle().stroke(accent.opacity(0.4), lineWidth: 2).frame(width: 46, height: 46)
                Circle().stroke(accent.opacity(0.8), lineWidth: 2).frame(width: 28, height: 28)
                Circle().fill(.white).frame(width: 8, height: 8)
            }
        }
        .scaleEffect(scale)
    }
}
