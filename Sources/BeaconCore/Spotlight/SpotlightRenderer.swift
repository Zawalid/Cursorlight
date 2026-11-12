import AppKit
import QuartzCore

/// Draws the spotlight on one overlay window: a dark layer with a hole where the region is, an optional soft edge made
/// of a few nested layers, and an outline with handles while the region is being edited.
@MainActor
final class SpotlightRenderer {
    private let root = CALayer()
    private var dimLayers: [CAShapeLayer] = []
    private let outline = CAShapeLayer()
    private var handleLayers: [CAShapeLayer] = []
    private var shown = false

    init() {
        root.opacity = 0
        outline.fillColor = nil
        outline.strokeColor = NSColor.white.withAlphaComponent(0.9).cgColor
        outline.lineWidth = 1.5
        outline.lineDashPattern = [6, 4]
        root.addSublayer(outline)
        for _ in 0..<8 {
            let handle = CAShapeLayer()
            handle.fillColor = NSColor.white.cgColor
            handle.strokeColor = NSColor.black.withAlphaComponent(0.4).cgColor
            handle.lineWidth = 1
            root.addSublayer(handle)
            handleLayers.append(handle)
        }
    }

    func attach(to layer: CALayer) {
        root.frame = layer.bounds
        root.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.addSublayer(root)
    }

    func detach() { root.removeFromSuperlayer() }

    func render(region: CGRect?, windowFrame: CGRect, style: SpotlightStyle, editing: Bool, visible: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        root.frame = CGRect(origin: .zero, size: windowFrame.size)
        guard let region, visible else {
            fade(to: 0)
            return
        }
        let local = region.offsetBy(dx: -windowFrame.minX, dy: -windowFrame.minY)
        let layers = max(1, style.softness > 0 ? 6 : 1)
        while dimLayers.count < layers {
            let layer = CAShapeLayer()
            layer.fillRule = .evenOdd
            layer.fillColor = NSColor.black.cgColor
            root.insertSublayer(layer, at: 0)
            dimLayers.append(layer)
        }
        while dimLayers.count > layers { dimLayers.removeLast().removeFromSuperlayer() }
        // n stacked layers of alpha a give 1 - (1 - a)^n = dim at full distance.
        let alpha = 1 - pow(1 - min(max(style.dim, 0), 0.97), 1 / Double(layers))
        let bounds = CGRect(origin: .zero, size: windowFrame.size)
        for (i, layer) in dimLayers.enumerated() {
            let inflate = layers == 1 ? 0 : style.softness * Double(layers - 1 - i) / Double(layers - 1)
            let path = CGMutablePath()
            path.addRect(bounds)
            path.addPath(Self.holePath(local, style: style, inflate: CGFloat(inflate)))
            layer.frame = bounds
            layer.path = path
            layer.opacity = Float(alpha)
        }
        outline.isHidden = !editing
        outline.path = Self.holePath(local, style: style, inflate: 0)
        for (handle, layer) in zip(SpotlightModel.Handle.allCases, handleLayers) {
            layer.isHidden = !editing
            let p = handle.point(in: local)
            layer.path = CGPath(roundedRect: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
        }
        fade(to: 1)
    }

    private func fade(to value: Float) {
        guard root.opacity != value else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0.22)
        root.opacity = value
        CATransaction.commit()
    }

    private static func holePath(_ rect: CGRect, style: SpotlightStyle, inflate: CGFloat) -> CGPath {
        let r = rect.insetBy(dx: -inflate, dy: -inflate)
        switch style.shape {
        case .rectangle:
            return CGPath(rect: r, transform: nil)
        case .rounded:
            let radius = min(CGFloat(style.corner) + inflate, min(r.width, r.height) / 2)
            return CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
        case .ellipse:
            return CGPath(ellipseIn: r, transform: nil)
        }
    }
}
