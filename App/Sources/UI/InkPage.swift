import BeaconCore
import SwiftUI

/// A looping before-and-after: a rough loop is drawn, snaps into an ellipse, then fades.
struct InkPreview: View {
    let style: InkStyle
    let color: InkColor
    let cleanup: Bool
    let fade: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let cycle = 4.2
                let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                draw(&context, size: size, t: t, cycle: cycle)
            }
        }
        .frame(height: 170)
        .background(LinearGradient(colors: [Color(red: 0.14, green: 0.15, blue: 0.20), Color(red: 0.09, green: 0.09, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line))
        .overlay(alignment: .bottomLeading) {
            Text(cleanup ? "A rough loop morphs into a clean ellipse" : "Cleanup off: strokes stay as drawn")
                .font(.system(size: 11)).foregroundStyle(Theme.dim).padding(12)
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, cycle: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2 - 6)
        let rx = size.width * 0.17, ry = size.height * 0.27
        let count = 64
        let clean: [CGPoint] = (0..<count).map { i in
            let a = 2 * Double.pi * Double(i) / Double(count - 1) - 1.2
            return CGPoint(x: center.x + rx * cos(a), y: center.y + ry * sin(a))
        }
        let rough: [CGPoint] = clean.enumerated().map { i, p in
            let k = Double(i)
            return CGPoint(x: p.x + 7 * sin(k * 0.55) + 4 * sin(k * 1.7), y: p.y + 6 * cos(k * 0.45) + 3 * sin(k * 2.3))
        }
        let drawTime = 1.5, morphStart = 1.7, morph = 0.3, holdEnd = 3.4
        let progress = min(t / drawTime, 1)
        let visible = max(Int(Double(count) * progress), 2)
        var points = Array(rough.prefix(visible))
        if cleanup, t >= morphStart {
            let m = min((t - morphStart) / morph, 1)
            let e = 1 - pow(1 - m, 3)
            points = zip(rough, clean).map { CGPoint(x: $0.x + ($1.x - $0.x) * e, y: $0.y + ($1.y - $0.y) * e) }
        }
        let alpha = t > holdEnd ? max(0, 1 - (t - holdEnd) / (cycle - holdEnd)) : 1
        Self.stroke(&context, points: points, style: style, color: color, alpha: alpha)
    }

    static func stroke(_ context: inout GraphicsContext, points: [CGPoint], style: InkStyle, color: InkColor, alpha: Double) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        let tint = Color(rgba: color.rgba)
        let round = StrokeStyle(lineWidth: style.width, lineCap: .round, lineJoin: .round)
        if style != .highlighter {
            context.stroke(path, with: .color(.black.opacity(0.22 * alpha)), style: StrokeStyle(lineWidth: style.width + 2, lineCap: .round, lineJoin: .round))
        }
        if let glow = style.glow {
            context.stroke(path, with: .color(tint.opacity(Double(glow.alpha) * alpha)), style: StrokeStyle(lineWidth: glow.width, lineCap: .round, lineJoin: .round))
        }
        let core = style.lightCore ? Color(rgba: color.rgba.mixed(with: Palette.light, 0.75)) : tint
        context.stroke(path, with: .color(core.opacity(Double(style.alpha) * alpha)), style: round)
    }
}

struct InkSwatchStroke: View {
    let style: InkStyle
    let color: InkColor

    var body: some View {
        Canvas { context, size in
            let points = (0...30).map { i -> CGPoint in
                let x = size.width * (0.12 + 0.76 * Double(i) / 30)
                return CGPoint(x: x, y: size.height * (0.5 + 0.22 * sin(Double(i) / 4.2)))
            }
            InkPreview.stroke(&context, points: points, style: style, color: color, alpha: 1)
        }
    }
}
