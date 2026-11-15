import AppKit
import QuartzCore

/// Draws `InkFrame`s on one overlay window: per stroke a dark keyline, an optional glow and the colored core.
@MainActor
final class InkRenderer {
    private final class StrokeLayers {
        let container = CALayer()
        let keyline = CAShapeLayer()
        let glow = CAShapeLayer()
        let core = CAShapeLayer()
        /// Stamps and text labels live here, centered or anchored on the mark's point.
        let content = CALayer()

        init() {
            container.addSublayer(content)
            for shape in [keyline, glow, core] {
                shape.fillColor = nil
                shape.lineCap = .round
                shape.lineJoin = .round
                container.addSublayer(shape)
            }
        }
    }

    let root = CALayer()
    private let board = CALayer()
    private var layers: [Int: StrokeLayers] = [:]
    private let scale: CGFloat

    init(scale: CGFloat) {
        self.scale = max(scale, 1)
        root.anchorPoint = .zero
        root.masksToBounds = false
        board.opacity = 0
        board.anchorPoint = .zero
    }

    /// A solid backdrop under every mark, for drawing on instead of the screen.
    func setBoard(_ kind: InkBoard) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        board.frame = board.superlayer?.bounds ?? root.bounds
        switch kind {
        case .none: board.opacity = 0
        case .white:
            board.backgroundColor = NSColor(white: 0.97, alpha: 1).cgColor
            board.opacity = 1
        case .black:
            board.backgroundColor = NSColor(white: 0.06, alpha: 1).cgColor
            board.opacity = 1
        }
        CATransaction.commit()
    }

    func attach(to host: CALayer) {
        withoutAnimation {
            root.frame = host.bounds
            board.frame = host.bounds
            host.addSublayer(board)
            host.addSublayer(root)
        }
    }

    func detach() {
        withoutAnimation {
            root.removeFromSuperlayer()
            board.removeFromSuperlayer()
        }
    }

    func render(_ frame: InkFrame, windowOrigin: CGPoint) {
        withoutAnimation {
            let live = Set(frame.strokes.map(\.id))
            for (id, entry) in layers where !live.contains(id) {
                entry.container.removeFromSuperlayer()
                layers[id] = nil
            }
            for stroke in frame.strokes {
                let entry = layers[stroke.id] ?? makeLayers(for: stroke)
                update(entry, stroke, origin: windowOrigin)
            }
        }
    }

    private func makeLayers(for stroke: InkStrokeFrame) -> StrokeLayers {
        let entry = StrokeLayers()
        let style = stroke.style
        let color = stroke.rgba
        let scale = stroke.widthScale
        for shape in [entry.keyline, entry.glow, entry.core] { shape.contentsScale = self.scale }
        switch stroke.kind {
        case .stamp(let stamp, let number):
            for shape in [entry.keyline, entry.glow, entry.core] { shape.isHidden = true }
            Self.buildStamp(stamp, number: number, color: color, into: entry.content, scale: self.scale)
        case .text(let text):
            for shape in [entry.keyline, entry.glow, entry.core] { shape.isHidden = true }
            Self.buildText(text, color: color, into: entry.content, scale: self.scale)
        case .filledBox:
            entry.keyline.isHidden = true
            entry.glow.isHidden = true
            entry.core.fillColor = color.with(alpha: 0.28).cgColor
            entry.core.strokeColor = color.with(alpha: 0.95).cgColor
            entry.core.lineWidth = max(2, style.width * scale * 0.5)
        case .redact:
            entry.keyline.isHidden = true
            entry.glow.isHidden = true
            entry.core.fillColor = NSColor(white: 0.04, alpha: 1).cgColor
            entry.core.strokeColor = nil
        case .freehand, .arrow, .curvedArrow, .doubleArrow, .bracket:
            entry.keyline.strokeColor = Palette.keyline.with(alpha: 0.22).cgColor
            entry.keyline.lineWidth = style.width * scale + 2
            entry.keyline.isHidden = !style.hasKeyline
            if let glow = style.glow {
                entry.glow.strokeColor = color.with(alpha: Double(glow.alpha)).cgColor
                entry.glow.lineWidth = glow.width * scale
            } else {
                entry.glow.isHidden = true
            }
            let coreColor = style.lightCore ? color.mixed(with: Palette.light, 0.75) : color
            entry.core.strokeColor = coreColor.with(alpha: Double(style.alpha)).cgColor
            entry.core.lineWidth = style.width * scale
            if let dash = style.dash { entry.core.lineDashPattern = dash.map { NSNumber(value: Double($0 * style.width * scale)) } }
        }
        root.addSublayer(entry.container)
        layers[stroke.id] = entry
        return entry
    }

    private func update(_ entry: StrokeLayers, _ stroke: InkStrokeFrame, origin: CGPoint) {
        let local = stroke.points.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
        let width = stroke.style.width * stroke.widthScale
        switch stroke.kind {
        case .freehand:
            let path = Self.smoothPath(local)
            entry.keyline.path = path
            entry.glow.path = path
            entry.core.path = path
        case .arrow, .curvedArrow, .doubleArrow, .bracket:
            let path = Self.markPath(stroke.kind, local, lineWidth: width)
            entry.keyline.path = path
            entry.glow.path = path
            entry.core.path = path
        case .filledBox, .redact:
            if local.count == 2 {
                let rect = CGRect(x: min(local[0].x, local[1].x), y: min(local[0].y, local[1].y), width: abs(local[1].x - local[0].x), height: abs(local[1].y - local[0].y))
                entry.core.path = CGPath(roundedRect: rect, cornerWidth: min(6, rect.width / 2), cornerHeight: min(6, rect.height / 2), transform: nil)
            }
        case .stamp, .text:
            if let p = local.first { entry.content.position = p }
        }
        entry.container.opacity = Float(stroke.alpha)
    }

    /// Arrow, double arrow and bracket from the two dragged points.
    static func markPath(_ kind: InkMarkKind, _ points: [CGPoint], lineWidth: CGFloat) -> CGPath {
        let path = CGMutablePath()
        guard points.count == 2 else { return path }
        let a = points[0], b = points[1]
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length > 1 else { return path }
        path.move(to: a)
        var heading = atan2(b.y - a.y, b.x - a.x)
        if kind == .curvedArrow {
            let c = InkCurve.control(from: a, to: b)
            path.addQuadCurve(to: b, control: c)
            heading = atan2(b.y - c.y, b.x - c.x)
        } else {
            path.addLine(to: b)
        }
        func head(at tip: CGPoint, pointing angle: CGFloat) {
            let size = min(max(14, lineWidth * 3.6), length * 0.45)
            for side in [-1.0, 1.0] {
                let angleBack = angle + .pi + CGFloat(side) * 0.5
                path.move(to: tip)
                path.addLine(to: CGPoint(x: tip.x + size * cos(angleBack), y: tip.y + size * sin(angleBack)))
            }
        }
        switch kind {
        case .arrow, .curvedArrow:
            head(at: b, pointing: heading)
        case .doubleArrow:
            head(at: b, pointing: heading)
            head(at: a, pointing: heading + .pi)
        case .bracket:
            let tick = min(max(10, lineWidth * 2.4), length * 0.4)
            let normal = heading + .pi / 2
            for end in [a, b] {
                path.move(to: CGPoint(x: end.x - tick * cos(normal), y: end.y - tick * sin(normal)))
                path.addLine(to: CGPoint(x: end.x + tick * cos(normal), y: end.y + tick * sin(normal)))
            }
        default:
            break
        }
        return path
    }

    // MARK: Stamps and text

    private static func contrast(_ c: RGBA) -> NSColor {
        (0.299 * c.red + 0.587 * c.green + 0.114 * c.blue) > 0.62 ? NSColor(white: 0.08, alpha: 1) : .white
    }

    private static func label(_ string: String, size: CGFloat, color: NSColor, scale: CGFloat) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = string
        layer.font = NSFont.systemFont(ofSize: size, weight: .bold)
        layer.fontSize = size
        layer.foregroundColor = color.cgColor
        layer.alignmentMode = .center
        layer.contentsScale = scale
        return layer
    }

    private static func buildStamp(_ stamp: StampKind, number: Int, color: RGBA, into content: CALayer, scale: CGFloat) {
        let d: CGFloat = 38
        let circle = CGPath(ellipseIn: CGRect(x: -d / 2, y: -d / 2, width: d, height: d), transform: nil)
        let ink = contrast(color)
        func disc() {
            let shape = CAShapeLayer()
            shape.path = circle
            shape.fillColor = color.cgColor
            shape.strokeColor = NSColor.black.withAlphaComponent(0.25).cgColor
            shape.lineWidth = 1
            shape.shadowColor = NSColor.black.cgColor
            shape.shadowOpacity = 0.35
            shape.shadowRadius = 3
            shape.shadowOffset = CGSize(width: 0, height: -1)
            content.addSublayer(shape)
        }
        func glyph(_ text: String, size: CGFloat) {
            let layer = label(text, size: size, color: ink, scale: scale)
            layer.frame = CGRect(x: -d / 2, y: -size * 0.58, width: d, height: size * 1.2)
            content.addSublayer(layer)
        }
        func stroke(_ path: CGPath, width: CGFloat = 4.5) {
            let shape = CAShapeLayer()
            shape.path = path
            shape.fillColor = nil
            shape.strokeColor = ink.cgColor
            shape.lineWidth = width
            shape.lineCap = .round
            shape.lineJoin = .round
            content.addSublayer(shape)
        }
        switch stamp {
        case .number:
            disc()
            glyph("\(number)", size: number > 9 ? 16 : 21)
        case .question:
            disc(); glyph("?", size: 23)
        case .exclamation:
            disc(); glyph("!", size: 23)
        case .check:
            disc()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -9, y: 0)); p.addLine(to: CGPoint(x: -3, y: -7)); p.addLine(to: CGPoint(x: 10, y: 9))
            stroke(p)
        case .cross:
            disc()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -8, y: -8)); p.addLine(to: CGPoint(x: 8, y: 8))
            p.move(to: CGPoint(x: -8, y: 8)); p.addLine(to: CGPoint(x: 8, y: -8))
            stroke(p)
        case .bubble:
            let body = CGMutablePath()
            body.addRoundedRect(in: CGRect(x: -22, y: -10, width: 44, height: 30), cornerWidth: 10, cornerHeight: 10)
            body.move(to: CGPoint(x: -12, y: -9)); body.addLine(to: CGPoint(x: -18, y: -20)); body.addLine(to: CGPoint(x: -3, y: -9))
            let shape = CAShapeLayer()
            shape.path = body
            shape.fillColor = color.cgColor
            shape.strokeColor = NSColor.black.withAlphaComponent(0.25).cgColor
            shape.lineWidth = 1
            shape.shadowColor = NSColor.black.cgColor
            shape.shadowOpacity = 0.35
            shape.shadowRadius = 3
            shape.shadowOffset = CGSize(width: 0, height: -1)
            content.addSublayer(shape)
            for x in [-10.0, 0.0, 10.0] {
                let dot = CAShapeLayer()
                dot.path = CGPath(ellipseIn: CGRect(x: x - 2.5, y: 5, width: 5, height: 5), transform: nil)
                dot.fillColor = ink.cgColor
                content.addSublayer(dot)
            }
        case .star:
            let p = CGMutablePath()
            for i in 0..<10 {
                let r: CGFloat = i % 2 == 0 ? 20 : 8.5
                let angle = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let pt = CGPoint(x: r * cos(angle), y: r * sin(angle) - 1)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
            let shape = CAShapeLayer()
            shape.path = p
            shape.fillColor = color.cgColor
            shape.strokeColor = NSColor.black.withAlphaComponent(0.3).cgColor
            shape.lineWidth = 1
            shape.lineJoin = .round
            content.addSublayer(shape)
        case .heart:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: -16))
            p.addCurve(to: CGPoint(x: -18, y: 4), control1: CGPoint(x: -8, y: -10), control2: CGPoint(x: -18, y: -4))
            p.addCurve(to: CGPoint(x: 0, y: 8), control1: CGPoint(x: -18, y: 14), control2: CGPoint(x: -6, y: 15))
            p.addCurve(to: CGPoint(x: 18, y: 4), control1: CGPoint(x: 6, y: 15), control2: CGPoint(x: 18, y: 14))
            p.addCurve(to: CGPoint(x: 0, y: -16), control1: CGPoint(x: 18, y: -4), control2: CGPoint(x: 8, y: -10))
            p.closeSubpath()
            let shape = CAShapeLayer()
            shape.path = p
            shape.fillColor = color.cgColor
            shape.strokeColor = NSColor.black.withAlphaComponent(0.3).cgColor
            shape.lineWidth = 1
            content.addSublayer(shape)
        }
    }

    private static func buildText(_ text: String, color: RGBA, into content: CALayer, scale: CGFloat) {
        let font = NSFont.systemFont(ofSize: 24, weight: .bold)
        let size = (text as NSString).size(withAttributes: [.font: font])
        let layer = CATextLayer()
        layer.string = text
        layer.font = font
        layer.fontSize = 24
        layer.foregroundColor = color.cgColor
        layer.contentsScale = scale
        layer.alignmentMode = .left
        layer.frame = CGRect(x: 0, y: -size.height / 2, width: ceil(size.width) + 4, height: ceil(size.height))
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: -1)
        content.addSublayer(layer)
    }

    /// Quadratic curves through segment midpoints; a single point becomes a dot.
    static func smoothPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 1 {
            path.addLine(to: CGPoint(x: first.x + 0.01, y: first.y))
            return path
        }
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        for i in 1..<(points.count - 1) {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            path.addQuadCurve(to: mid, control: points[i])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }

    private func withoutAnimation(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }
}
