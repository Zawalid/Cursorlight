import BeaconCore
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
        clicks: [PreviewClick] = [], ripples: Bool = true
    ) {
        let screen = screenRect(in: size)
        let s = effectScale(for: screen)
        let auto: (Double) -> CGPoint = { Autopilot.point(at: $0, scene: scene, in: screen) }
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
        fx.opacity = Double(look.intensity)

        switch style {
        case .aura:
            let r = recipe.aura.radius
            let breath = 1 + 0.03 * sin(time * 2 * .pi / recipe.aura.breathPeriod)
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
                    Gradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.77), .init(color: .clear, location: 1)]),
                    center: p, startRadius: 0, endRadius: r
                ))
            }
        case .comet:
            let steps = 18
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
            fx.stroke(ring, with: .color(.black.opacity(0.35)), lineWidth: 5)
            fx.stroke(ring, with: .color(light), lineWidth: 3)
            let dot = recipe.keyline.dotDiameter
            fx.fill(Path(ellipseIn: CGRect(x: p.x - dot / 2, y: p.y - dot / 2, width: dot, height: dot)), with: .color(light))
        case .sonar:
            for i in 0..<3 {
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
                drawRipple(&fx, at: unscale(click.point), phase: age / Autopilot.rippleLength, color: tint)
            }
        }
        // With the real mouse on the preview, the real cursor is already there.
        if pointer == nil { drawArrow(&fx, at: p) }
    }

    private static func drawRipple(_ context: inout GraphicsContext, at p: CGPoint, phase: Double, color: Color) {
        let e = 1 - pow(1 - phase, 3)
        let r = 8 + 46 * e
        let fade = 1 - phase
        context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(color.opacity(0.22 * fade)))
        context.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(color.opacity(0.85 * fade)), lineWidth: 1 + 3 * fade)
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
            case .sonar:
                Circle().stroke(accent.opacity(0.4), lineWidth: 2).frame(width: 46, height: 46)
                Circle().stroke(accent.opacity(0.8), lineWidth: 2).frame(width: 28, height: 28)
                Circle().fill(.white).frame(width: 8, height: 8)
            }
        }
        .scaleEffect(scale)
    }
}
