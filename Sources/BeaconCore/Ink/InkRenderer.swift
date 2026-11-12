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

        init() {
            for shape in [keyline, glow, core] {
                shape.fillColor = nil
                shape.lineCap = .round
                shape.lineJoin = .round
                container.addSublayer(shape)
            }
        }
    }

    let root = CALayer()
    private var layers: [Int: StrokeLayers] = [:]
    private let scale: CGFloat

    init(scale: CGFloat) {
        self.scale = max(scale, 1)
        root.anchorPoint = .zero
        root.masksToBounds = false
    }

    func attach(to host: CALayer) {
        withoutAnimation {
            root.frame = host.bounds
            host.addSublayer(root)
        }
    }

    func detach() {
        withoutAnimation { root.removeFromSuperlayer() }
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
        let color = stroke.color.rgba
        for shape in [entry.keyline, entry.glow, entry.core] { shape.contentsScale = scale }
        entry.keyline.strokeColor = Palette.keyline.with(alpha: 0.22).cgColor
        let scale = stroke.widthScale
        entry.keyline.lineWidth = style.width * scale + 2
        entry.keyline.isHidden = style == .highlighter
        if let glow = style.glow {
            entry.glow.strokeColor = color.with(alpha: Double(glow.alpha)).cgColor
            entry.glow.lineWidth = glow.width * scale
        } else {
            entry.glow.isHidden = true
        }
        let coreColor = style.lightCore ? color.mixed(with: Palette.light, 0.75) : color
        entry.core.strokeColor = coreColor.with(alpha: Double(style.alpha)).cgColor
        entry.core.lineWidth = style.width * scale
        root.addSublayer(entry.container)
        layers[stroke.id] = entry
        return entry
    }

    private func update(_ entry: StrokeLayers, _ stroke: InkStrokeFrame, origin: CGPoint) {
        let local = stroke.points.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
        let path = Self.smoothPath(local)
        entry.keyline.path = path
        entry.glow.path = path
        entry.core.path = path
        entry.container.opacity = Float(stroke.alpha)
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
