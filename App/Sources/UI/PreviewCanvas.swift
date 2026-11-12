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

    static func position(at t: Double, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * (0.5 + 0.27 * sin(t / 1.7) + 0.07 * sin(t / 0.53)),
            y: rect.minY + rect.height * (0.46 + 0.19 * sin(t / 1.15 + 1) + 0.05 * sin(t / 0.41))
        )
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

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, time: Double, style: HighlightStyle, look: HighlightLook,
        pointer: CGPoint? = nil, history: PointerHistory? = nil
    ) {
        let screen = screenRect(in: size)
        drawWindow(&context, rect: screen)
        let p = pointer ?? position(at: time, in: screen)
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
                let q = history?.position(at: time - Double(k) * 0.022) ?? position(at: time - Double(k) * 0.022, in: screen)
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

    /// A small desktop inside `rect`: wallpaper, a menu bar, a light document window, a dark panel and a dock. Everything
    /// sits inside the frame, so the scene reads at any size and every style is seen on light and dark.
    static func drawDesktop(_ context: inout GraphicsContext, rect: CGRect) { drawWindow(&context, rect: rect) }

    private static func drawWindow(_ context: inout GraphicsContext, rect: CGRect) {
        let ox = rect.minX, oy = rect.minY, w = rect.width, h = rect.height
        let k = w / 880
        context.drawLayer { layer in
            layer.clip(to: Path(roundedRect: rect, cornerRadius: 12))
            layer.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.17, green: 0.165, blue: 0.18), Color(red: 0.075, green: 0.072, blue: 0.082)]),
                    startPoint: CGPoint(x: ox, y: oy), endPoint: CGPoint(x: ox + w, y: oy + h)
                )
            )
            // Menu bar
            layer.fill(Path(CGRect(x: ox, y: oy, width: w, height: 16 * k)), with: .color(Color.white.opacity(0.08)))
            for i in 0..<3 {
                layer.fill(Path(roundedRect: CGRect(x: ox + (14 + CGFloat(i) * 26) * k, y: oy + 6 * k, width: 18 * k, height: 4 * k), cornerRadius: 2), with: .color(Color.white.opacity(0.3)))
            }
            layer.fill(Path(roundedRect: CGRect(x: ox + w - 52 * k, y: oy + 6 * k, width: 38 * k, height: 4 * k), cornerRadius: 2), with: .color(Color.white.opacity(0.3)))

            let top = oy + 34 * k, bottom = oy + h - 46 * k
            // Light document window
            let doc = CGRect(x: ox + w * 0.07, y: top, width: w * 0.5, height: bottom - top)
            layer.fill(Path(roundedRect: doc, cornerRadius: 9 * k), with: .color(Color(white: 0.95)))
            layer.fill(Path(roundedRect: CGRect(x: doc.minX, y: doc.minY, width: doc.width, height: 22 * k), cornerRadius: 9 * k), with: .color(Color(white: 0.89)))
            for i in 0..<3 {
                layer.fill(Path(ellipseIn: CGRect(x: doc.minX + (10 + CGFloat(i) * 13) * k, y: doc.minY + 8 * k, width: 6 * k, height: 6 * k)), with: .color(Color(white: 0.72)))
            }
            let rows = max(Int((doc.height - 100 * k) / (24 * k)), 2)
            let widths = [0.62, 0.8, 0.46, 0.7, 0.55]
            for i in 0..<rows {
                let bar = CGRect(x: doc.minX + 22 * k, y: doc.minY + 42 * k + CGFloat(i) * 24 * k, width: doc.width * widths[i % widths.count], height: 9 * k)
                layer.fill(Path(roundedRect: bar, cornerRadius: 4.5 * k), with: .color(Color(white: 0.8)))
            }
            layer.fill(Path(roundedRect: CGRect(x: doc.minX + 22 * k, y: doc.maxY - 42 * k, width: doc.width * 0.24, height: 24 * k), cornerRadius: 7 * k), with: .color(Color(red: 0.30, green: 0.64, blue: 1)))

            // Dark panel
            let panel = CGRect(x: ox + w * 0.62, y: top + 18 * k, width: w * 0.31, height: bottom - top - 18 * k)
            layer.fill(Path(roundedRect: panel, cornerRadius: 9 * k), with: .color(Color(white: 0.13)))
            layer.fill(Path(roundedRect: CGRect(x: panel.minX, y: panel.minY, width: panel.width, height: 22 * k), cornerRadius: 9 * k), with: .color(Color(white: 0.18)))
            let panelRows = max(Int((panel.height - 44 * k) / (26 * k)), 2)
            for i in 0..<panelRows {
                let row = CGRect(x: panel.minX + 16 * k, y: panel.minY + 42 * k + CGFloat(i) * 26 * k, width: panel.width * (i % 2 == 0 ? 0.7 : 0.5), height: 10 * k)
                layer.fill(Path(roundedRect: row, cornerRadius: 5 * k), with: .color(Color(white: 0.27)))
            }

            // Dock
            let dock = CGRect(x: ox + w * 0.5 - w * 0.17, y: oy + h - 36 * k, width: w * 0.34, height: 26 * k)
            layer.fill(Path(roundedRect: dock, cornerRadius: 13 * k), with: .color(Color.white.opacity(0.12)))
            for i in 0..<6 {
                layer.fill(Path(roundedRect: CGRect(x: dock.minX + 12 * k + CGFloat(i) * (dock.width - 24 * k) / 6, y: dock.minY + 5 * k, width: 16 * k, height: 16 * k), cornerRadius: 4.5 * k), with: .color(Color.white.opacity(0.28)))
            }
        }
        context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(Color.white.opacity(0.12)), lineWidth: 1)
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
