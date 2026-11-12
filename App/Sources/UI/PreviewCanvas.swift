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

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, time: Double, style: HighlightStyle, look: HighlightLook,
        pointer: CGPoint? = nil, history: PointerHistory? = nil
    ) {
        drawWindow(&context, size: size)
        let p = pointer ?? position(at: time, in: size)
        history?.record(p, at: time)
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
                let q = history?.position(at: time - Double(k) * 0.022) ?? position(at: time - Double(k) * 0.022, in: size)
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
        // With the real mouse on the preview, the real cursor is already there.
        if pointer == nil { drawArrow(&context, at: p) }
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

    /// A small desktop: wallpaper, a menu bar, a light document window, a dark panel and a dock. Everything sits inside
    /// the frame, so the whole scene reads at any size and every style is seen on light and dark.
    private static func drawWindow(_ context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        // Wallpaper
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.16, green: 0.17, blue: 0.24), Color(red: 0.07, green: 0.07, blue: 0.10)]),
                startPoint: .zero, endPoint: CGPoint(x: w, y: h)
            )
        )
        // Menu bar
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: 16)), with: .color(Color.white.opacity(0.07)))
        for i in 0..<3 { context.fill(Path(roundedRect: CGRect(x: 14 + CGFloat(i) * 26, y: 6, width: 18, height: 4), cornerRadius: 2), with: .color(Color.white.opacity(0.3))) }
        context.fill(Path(roundedRect: CGRect(x: w - 52, y: 6, width: 38, height: 4), cornerRadius: 2), with: .color(Color.white.opacity(0.3)))

        let top: CGFloat = min(max(h * 0.2, 58), 76), bottom: CGFloat = h - 46
        // Light document window
        let doc = CGRect(x: w * 0.07, y: top, width: w * 0.5, height: max(bottom - top, 60))
        context.fill(Path(roundedRect: doc, cornerRadius: 10), with: .color(Color(white: 0.95)))
        context.fill(Path(roundedRect: CGRect(x: doc.minX, y: doc.minY, width: doc.width, height: 20), cornerRadius: 10), with: .color(Color(white: 0.89)))
        for i in 0..<3 {
            context.fill(Path(ellipseIn: CGRect(x: doc.minX + 10 + CGFloat(i) * 12, y: doc.minY + 7, width: 6, height: 6)), with: .color(Color(white: 0.72)))
        }
        let rows = max(Int((doc.height - 90) / 22), 2)
        for i in 0..<rows {
            let widths = [0.62, 0.8, 0.46, 0.7, 0.55]
            let bar = CGRect(x: doc.minX + 20, y: doc.minY + 38 + CGFloat(i) * 22, width: doc.width * widths[i % widths.count], height: 8)
            context.fill(Path(roundedRect: bar, cornerRadius: 4), with: .color(Color(white: 0.80)))
        }
        let button = CGRect(x: doc.minX + 20, y: doc.maxY - 38, width: doc.width * 0.24, height: 22)
        context.fill(Path(roundedRect: button, cornerRadius: 7), with: .color(Color(red: 0.30, green: 0.64, blue: 1)))

        // Dark panel
        let panel = CGRect(x: w * 0.62, y: top + 16, width: w * 0.31, height: max(bottom - top - 16, 50))
        context.fill(Path(roundedRect: panel, cornerRadius: 10), with: .color(Color(white: 0.13)))
        context.fill(Path(roundedRect: CGRect(x: panel.minX, y: panel.minY, width: panel.width, height: 20), cornerRadius: 10), with: .color(Color(white: 0.18)))
        let panelRows = max(Int((panel.height - 40) / 24), 2)
        for i in 0..<panelRows {
            let row = CGRect(x: panel.minX + 16, y: panel.minY + 38 + CGFloat(i) * 24, width: panel.width * (i % 2 == 0 ? 0.7 : 0.5), height: 9)
            context.fill(Path(roundedRect: row, cornerRadius: 4.5), with: .color(Color(white: 0.27)))
        }

        // Dock
        let dock = CGRect(x: w * 0.5 - w * 0.17, y: h - 34, width: w * 0.34, height: 24)
        context.fill(Path(roundedRect: dock, cornerRadius: 12), with: .color(Color.white.opacity(0.12)))
        for i in 0..<6 {
            context.fill(Path(roundedRect: CGRect(x: dock.minX + 12 + CGFloat(i) * (dock.width - 24) / 6, y: dock.minY + 5, width: 14, height: 14), cornerRadius: 4), with: .color(Color.white.opacity(0.28)))
        }
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
