import BeaconCore
import SwiftUI

/// An animated stand-in for a highlight style on a fake window, driven by the real style recipes and the user's look.
/// It is a drawing of the effect, not the renderer itself, so small differences from the real overlay are expected.
struct PreviewCanvas: View {
    let style: HighlightStyle
    let look: HighlightLook
    var height: CGFloat = 210

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                Self.draw(&context, size: size, time: timeline.date.timeIntervalSinceReferenceDate, style: style, look: look)
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

    static func position(at t: Double, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * (0.5 + 0.27 * sin(t / 1.7) + 0.07 * sin(t / 0.53)),
            y: size.height * (0.46 + 0.19 * sin(t / 1.15 + 1) + 0.05 * sin(t / 0.41))
        )
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, time: Double, style: HighlightStyle, look: HighlightLook) {
        drawWindow(&context, size: size)
        let p = position(at: time, in: size)
        let recipe = style.recipe.applying(look)
        let accent = Color(rgba: look.accentColor(for: style))
        let light = Color(rgba: Palette.light)
        context.opacity = Double(look.intensity)

        switch style {
        case .aura:
            let r = recipe.aura.radius
            let breath = 1 + 0.03 * sin(time * 2 * .pi / recipe.aura.breathPeriod)
            glow(&context, at: p, radius: r * recipe.aura.outer.radiusFactor * breath, color: accent, alpha: 0.10)
            glow(&context, at: p, radius: r * 1.15 * breath, color: accent, alpha: 0.26)
            glow(&context, at: p, radius: r * recipe.aura.core.radiusFactor * 1.4, color: Color(rgba: look.accentColor(for: style).mixed(with: Palette.light, 0.75)), alpha: 0.6)
        case .lens:
            let r = recipe.lens.radius * 0.8
            context.drawLayer { layer in
                layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(recipe.lens.dim)))
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
                let q = position(at: time - Double(k) * 0.022, in: size)
                let a = 1 - Double(k) / Double(steps)
                let d = recipe.comet.headDiameter * (0.25 + 0.75 * a)
                context.fill(Path(ellipseIn: CGRect(x: q.x - d / 2, y: q.y - d / 2, width: d, height: d)), with: .color(accent.opacity(0.75 * a * a)))
            }
            glow(&context, at: p, radius: recipe.comet.headHaloDiameter, color: accent, alpha: 0.5)
            let d = recipe.comet.headDiameter
            let head = Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d))
            context.fill(head, with: .color(light))
            context.stroke(head, with: .color(accent), lineWidth: 2)
        case .keyline:
            let r = recipe.keyline.radius
            let ring = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            context.stroke(ring, with: .color(.black.opacity(0.35)), lineWidth: 5)
            context.stroke(ring, with: .color(light), lineWidth: 3)
            let dot = recipe.keyline.dotDiameter
            context.fill(Path(ellipseIn: CGRect(x: p.x - dot / 2, y: p.y - dot / 2, width: dot, height: dot)), with: .color(light))
        case .sonar:
            for i in 0..<3 {
                let phase = ((time + Double(i) * 0.25).truncatingRemainder(dividingBy: 2.2)) / 2.2
                let r = recipe.sonar.startRadius * (1 - phase) + recipe.sonar.endRadius * phase
                let ring = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                context.stroke(ring, with: .color(accent.opacity(0.7 * sin(phase * .pi))), lineWidth: 2)
            }
            glow(&context, at: p, radius: recipe.sonar.dotRadius, color: accent, alpha: 0.5)
            let c = recipe.sonar.dotCoreRadius
            context.fill(Path(ellipseIn: CGRect(x: p.x - c, y: p.y - c, width: 2 * c, height: 2 * c)), with: .color(light))
        }
        context.opacity = 1
        drawArrow(&context, at: p)
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

    private static func drawWindow(_ context: inout GraphicsContext, size: CGSize) {
        let frame = CGRect(x: 26, y: 22, width: size.width - 52, height: size.height - 70)
        context.fill(Path(roundedRect: frame, cornerRadius: 10), with: .color(Color(white: 0.955)))
        context.fill(Path(roundedRect: CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 22), cornerRadius: 10), with: .color(Color(white: 0.89)))
        for (i, w) in [0.55, 0.72, 0.40].enumerated() {
            let bar = CGRect(x: frame.minX + 18, y: frame.minY + 40 + CGFloat(i) * 18, width: frame.width * w, height: 8)
            context.fill(Path(roundedRect: bar, cornerRadius: 4), with: .color(Color(white: 0.79)))
        }
        let button = CGRect(x: frame.minX + 18, y: frame.minY + 100, width: frame.width * 0.24, height: 18)
        context.fill(Path(roundedRect: button, cornerRadius: 6), with: .color(Color(red: 0.30, green: 0.64, blue: 1)))
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

    var body: some View {
        ZStack {
            let accent = Color(rgba: Palette.accent(for: style))
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
    }
}
