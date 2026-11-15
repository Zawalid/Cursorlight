import AppKit

enum MenuBarIconState: Equatable {
    case idle, active, paused
}

/// The menu bar icon: the app's ring and pointer, drawn as a template image so macOS tints it for light, dark and a busy
/// wallpaper. Three states you can tell apart at a glance: outline (ready), solid (an effect is running), dashed (paused).
enum MenuBarIcon {
    static func image(_ state: MenuBarIconState) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: 10, y: 9)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)

            // Pointer, tip up and to the left, centered in the ring.
            let unit: [CGPoint] = [
                CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1.0), CGPoint(x: 0.24, y: 0.78), CGPoint(x: 0.40, y: 1.14),
                CGPoint(x: 0.60, y: 1.05), CGPoint(x: 0.44, y: 0.70), CGPoint(x: 0.76, y: 0.70),
            ]
            let scale: CGFloat = 8.4 / 1.14
            let left = center.x - 0.38 * scale + 0.3
            let top = center.y + 0.57 * scale
            let arrow = CGMutablePath()
            for (i, p) in unit.enumerated() {
                let point = CGPoint(x: left + p.x * scale, y: top - p.y * scale)
                if i == 0 { arrow.move(to: point) } else { arrow.addLine(to: point) }
            }
            arrow.closeSubpath()

            switch state {
            case .idle:
                ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: CGRect(x: center.x - 7.4, y: center.y - 7.4, width: 14.8, height: 14.8))
                ctx.addPath(arrow); ctx.fillPath()
                ctx.setLineWidth(0.9)
                ctx.addPath(arrow); ctx.strokePath()
            case .active:
                ctx.fillEllipse(in: CGRect(x: center.x - 8.1, y: center.y - 8.1, width: 16.2, height: 16.2))
                ctx.setBlendMode(.clear)
                ctx.addPath(arrow); ctx.fillPath()
                ctx.setLineWidth(0.9)
                ctx.addPath(arrow); ctx.strokePath()
            case .paused:
                ctx.setLineWidth(1.5)
                ctx.setLineDash(phase: 0, lengths: [2.4, 2.4])
                ctx.strokeEllipse(in: CGRect(x: center.x - 7.4, y: center.y - 7.4, width: 14.8, height: 14.8))
                ctx.setLineDash(phase: 0, lengths: [])
                ctx.setLineWidth(1.3)
                ctx.addPath(arrow); ctx.strokePath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
