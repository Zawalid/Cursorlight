import AppKit

enum MenuBarIconState: Equatable {
    case idle, active, paused
}

/// The menu bar icon: the app's ring and pointer, drawn in the color the menu bar needs (white on a dark bar, black on a light one). Three states you can tell apart at a glance: outline (ready), outline with a dot (an effect is running), dashed (paused).
enum MenuBarIcon {
    static func image(_ state: MenuBarIconState, color: NSColor) -> NSImage {
        // Bitmap representations, not a drawing closure: a closure image can lose its template tint in the menu bar and
        // come out black on a dark bar. Bitmaps are tinted by macOS from their alpha, like any system symbol.
        let image = NSImage(size: NSSize(width: 20, height: 18))
        for scale in [2, 3] {
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 20 * scale, pixelsHigh: 18 * scale, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ), let context = NSGraphicsContext(bitmapImageRep: rep) else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            let ctx = context.cgContext
            ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            draw(state, color: color, in: ctx)
            NSGraphicsContext.restoreGraphicsState()
            rep.size = NSSize(width: 20, height: 18)
            image.addRepresentation(rep)
        }
        // Not a template: macOS did not tint a custom template on this menu bar, so the app picks black or white itself.
        image.isTemplate = false
        return image
    }

    private static func draw(_ state: MenuBarIconState, color: NSColor, in ctx: CGContext) {
        let center = CGPoint(x: 10, y: 9)
        ctx.setFillColor(color.cgColor)
        ctx.setStrokeColor(color.cgColor)
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
            // Same ring and pointer, plus a solid dot: no knocked-out shapes, so every tint and highlight keeps it readable.
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(x: center.x - 7.4, y: center.y - 7.4, width: 14.8, height: 14.8))
            ctx.addPath(arrow); ctx.fillPath()
            ctx.setLineWidth(0.9)
            ctx.addPath(arrow); ctx.strokePath()
            ctx.fillEllipse(in: CGRect(x: 14.4, y: 12.4, width: 4.8, height: 4.8))
        case .paused:
            ctx.setLineWidth(1.5)
            ctx.setLineDash(phase: 0, lengths: [2.4, 2.4])
            ctx.strokeEllipse(in: CGRect(x: center.x - 7.4, y: center.y - 7.4, width: 14.8, height: 14.8))
            ctx.setLineDash(phase: 0, lengths: [])
            ctx.setLineWidth(1.3)
            ctx.addPath(arrow); ctx.strokePath()
        }
    }
}
