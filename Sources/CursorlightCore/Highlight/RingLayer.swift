import AppKit
import QuartzCore

/// One animated ring (click ripple, press ring, summon pulse, sonar ring): optional fill, the colored ring, a dark
/// keyline hugging its outside edge and, for right clicks, a second inner ring.
@MainActor
final class RingLayer {
    let container = CALayer()
    private let fill = CAShapeLayer()
    private let keyline = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let inner = CAShapeLayer()

    init(scale: CGFloat) {
        container.bounds = .zero
        container.isHidden = true
        for shape in [fill, keyline, ring, inner] {
            shape.contentsScale = scale
            shape.fillColor = nil
            container.addSublayer(shape)
        }
        keyline.lineWidth = 1
    }

    /// - Parameters:
    ///   - origin: the window's origin in global coordinates; the ring's center is converted with it.
    ///   - keylineAlpha: alpha of the dark keyline relative to the ring's own alpha.
    func update(
        _ state: RingState?, origin: CGPoint, color: RGBA, fillColor: RGBA, double: Bool,
        keylineAlpha: CGFloat, scale: CGFloat
    ) {
        guard let state, state.alpha > 0.002, state.radius > 0 else {
            container.isHidden = true
            return
        }
        container.isHidden = false
        let local = CGPoint(x: state.center.x - origin.x, y: state.center.y - origin.y)
        container.position = PointerGeometry.pixelAligned(local, scale: scale)
        container.opacity = Float(state.alpha)

        let r = state.radius
        let w = state.lineWidth
        ring.path = Self.circle(r)
        ring.lineWidth = w
        ring.lineCap = state.dashed ? .round : .butt
        ring.lineDashPattern = state.dashed ? [NSNumber(value: Double(w * 0.9)), NSNumber(value: Double(max(8, w * 3)))] : nil
        ring.strokeColor = color.with(alpha: 1).cgColor

        keyline.path = Self.circle(r + w / 2 + 0.5)
        keyline.strokeColor = Palette.keyline.with(alpha: Double(keylineAlpha)).cgColor

        if state.fillAlpha > 0.001 {
            fill.isHidden = false
            fill.path = Self.circle(max(r - w / 2, 0))
            fill.fillColor = fillColor.with(alpha: Double(min(state.fillAlpha / state.alpha, 1))).cgColor
        } else {
            fill.isHidden = true
        }

        inner.isHidden = !double
        if double {
            inner.path = Self.circle(r * 0.62)
            inner.lineWidth = max(w * 0.75, 1)
            inner.strokeColor = color.with(alpha: 0.85).cgColor
        }
    }

    static func circle(_ radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: 2 * radius, height: 2 * radius), transform: nil)
    }
}
