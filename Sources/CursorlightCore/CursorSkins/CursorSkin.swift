import CoreGraphics
import Foundation

/// The look of the real pointer. `.system` leaves the pointer alone.
public enum CursorDesign: String, Codable, CaseIterable, Sendable {
    case system, classic, dart, bolt, ring, target, star, heart, ghost

    public var displayName: String {
        switch self {
        case .system: "System"
        case .classic: "Classic"
        case .dart: "Dart"
        case .bolt: "Bolt"
        case .ring: "Ring"
        case .target: "Target"
        case .star: "Star"
        case .heart: "Heart"
        case .ghost: "Ghost"
        }
    }

    /// The color used when the user has not picked one.
    public var defaultColor: RGBA {
        switch self {
        case .system, .classic: RGBA(hex: "#7A4DFF")
        case .dart: RGBA(hex: "#16B5A6")
        case .bolt: RGBA(hex: "#FFB020")
        case .ring: RGBA(hex: "#FF5A36")
        case .target: RGBA(hex: "#E8325F")
        case .star: RGBA(hex: "#FFC93C")
        case .heart: RGBA(hex: "#FF4D7E")
        case .ghost: RGBA(hex: "#8FA3FF")
        }
    }

    /// Pointer-shaped designs click with their tip; the others click with their center.
    var hotspotAtTip: Bool { self == .classic || self == .dart || self == .bolt }
}

/// What the user chose for the pointer.
public struct CursorSkinSettings: Codable, Equatable, Sendable {
    public static let sizeRange: ClosedRange<Double> = 0.75...2

    public var design: CursorDesign = .system
    /// `#RRGGBB`; nil uses the design's own color.
    public var color: String?
    /// A multiple of the base 32 point size.
    public var size: Double = 1

    public init(design: CursorDesign = .system, color: String? = nil, size: Double = 1) {
        self.design = design
        self.color = color
        self.size = size
    }

    public var isActive: Bool { design != .system }
    public var resolvedColor: RGBA { color.flatMap { RGBA.isValidHex($0) ? RGBA(hex: $0) : nil } ?? design.defaultColor }

    private enum CodingKeys: String, CodingKey { case design, color, size }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        design = (try? c.decode(CursorDesign.self, forKey: .design)) ?? .system
        color = (try? c.decode(String.self, forKey: .color)).flatMap { RGBA.isValidHex($0) ? $0 : nil }
        let raw = (try? c.decode(Double.self, forKey: .size)) ?? 1
        size = raw.isFinite ? min(max(raw, Self.sizeRange.lowerBound), Self.sizeRange.upperBound) : 1
    }
}

/// One pointer ready to register: images at 1x to 4x, the size in points and where the click lands.
public struct CursorSkinImage: Sendable {
    public var images: [CGImage]
    public var size: CGSize
    public var hotspot: CGPoint
}

/// Draws the designs with Core Graphics. Pure: no window server calls, so it is unit-tested.
public enum CursorSkinRenderer {
    public static let basePoints: CGFloat = 32

    public static func render(_ settings: CursorSkinSettings) -> CursorSkinImage? {
        guard settings.isActive else { return nil }
        let points = (basePoints * CGFloat(settings.size)).rounded()
        let images = (1...4).compactMap { image(design: settings.design, color: settings.resolvedColor, points: points, scale: CGFloat($0)) }
        guard images.count == 4 else { return nil }
        let unit = points / basePoints
        let hotspot = settings.design.hotspotAtTip
            ? CGPoint(x: (4 * unit).rounded(), y: (3 * unit).rounded())
            : CGPoint(x: points / 2, y: points / 2)
        return CursorSkinImage(images: images, size: CGSize(width: points, height: points), hotspot: hotspot)
    }

    static func image(design: CursorDesign, color: RGBA, points: CGFloat, scale: CGFloat) -> CGImage? {
        let px = Int((points * scale).rounded())
        guard px > 0, let ctx = CGContext(
            data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // Work in a 32 point design box with the origin at the top left.
        ctx.scaleBy(x: scale * points / basePoints, y: scale * points / basePoints)
        ctx.translateBy(x: 0, y: basePoints)
        ctx.scaleBy(x: 1, y: -1)
        draw(design, color: color, in: ctx)
        return ctx.makeImage()
    }

    private static func cg(_ c: RGBA, _ alpha: Double = 1) -> CGColor {
        CGColor(red: c.red, green: c.green, blue: c.blue, alpha: alpha)
    }

    private static func draw(_ design: CursorDesign, color: RGBA, in ctx: CGContext) {
        let fill = cg(color)
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        switch design {
        case .system:
            break
        case .classic:
            let p = arrow(CGPoint(x: 4, y: 3))
            outlined(p, fill: fill, in: ctx)
        case .dart:
            let o = CGPoint(x: 4, y: 3)
            let p = CGMutablePath()
            p.move(to: o)
            p.addLine(to: CGPoint(x: o.x + 7, y: o.y + 24))
            p.addLine(to: CGPoint(x: o.x + 11, y: o.y + 15))
            p.addLine(to: CGPoint(x: o.x + 22, y: o.y + 11))
            p.closeSubpath()
            outlined(p, fill: fill, in: ctx)
        case .bolt:
            let o = CGPoint(x: 4, y: 3)
            let p = CGMutablePath()
            p.move(to: o)
            p.addLine(to: CGPoint(x: o.x + 4, y: o.y + 13))
            p.addLine(to: CGPoint(x: o.x + 10, y: o.y + 13))
            p.addLine(to: CGPoint(x: o.x + 6, y: o.y + 26))
            p.addLine(to: CGPoint(x: o.x + 20, y: o.y + 9))
            p.addLine(to: CGPoint(x: o.x + 13, y: o.y + 9))
            p.addLine(to: CGPoint(x: o.x + 18, y: o.y + 2))
            p.closeSubpath()
            outlined(p, fill: fill, in: ctx)
        case .ring:
            let rect = CGRect(x: 6, y: 6, width: 20, height: 20)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: CGColor(gray: 0, alpha: 0.4))
            ctx.setStrokeColor(white); ctx.setLineWidth(6.5); ctx.strokeEllipse(in: rect)
            ctx.restoreGState()
            ctx.setStrokeColor(fill); ctx.setLineWidth(3.5); ctx.strokeEllipse(in: rect)
            ctx.setFillColor(CGColor(gray: 0.1, alpha: 1)); ctx.fillEllipse(in: CGRect(x: 14, y: 14, width: 4, height: 4))
        case .target:
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: CGColor(gray: 0, alpha: 0.4))
            ctx.setStrokeColor(white); ctx.setLineWidth(6)
            ctx.strokeEllipse(in: CGRect(x: 8, y: 8, width: 16, height: 16))
            for (a, b) in [(CGPoint(x: 16, y: 1.5), CGPoint(x: 16, y: 10)), (CGPoint(x: 16, y: 22), CGPoint(x: 16, y: 30.5)),
                           (CGPoint(x: 1.5, y: 16), CGPoint(x: 10, y: 16)), (CGPoint(x: 22, y: 16), CGPoint(x: 30.5, y: 16))] {
                ctx.move(to: a); ctx.addLine(to: b)
            }
            ctx.strokePath()
            ctx.restoreGState()
            ctx.setStrokeColor(fill); ctx.setLineWidth(2.5)
            ctx.strokeEllipse(in: CGRect(x: 8, y: 8, width: 16, height: 16))
            for (a, b) in [(CGPoint(x: 16, y: 2), CGPoint(x: 16, y: 10)), (CGPoint(x: 16, y: 22), CGPoint(x: 16, y: 30)),
                           (CGPoint(x: 2, y: 16), CGPoint(x: 10, y: 16)), (CGPoint(x: 22, y: 16), CGPoint(x: 30, y: 16))] {
                ctx.move(to: a); ctx.addLine(to: b)
            }
            ctx.strokePath()
            ctx.setFillColor(fill); ctx.fillEllipse(in: CGRect(x: 14.5, y: 14.5, width: 3, height: 3))
        case .star:
            let p = CGMutablePath()
            let c = CGPoint(x: 16, y: 16.5)
            for i in 0..<10 {
                let r: CGFloat = i % 2 == 0 ? 14 : 6
                let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            outlined(p, fill: fill, in: ctx)
        case .heart:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 16, y: 28))
            p.addCurve(to: CGPoint(x: 3, y: 12), control1: CGPoint(x: 6, y: 22), control2: CGPoint(x: 3, y: 17))
            p.addCurve(to: CGPoint(x: 16, y: 9), control1: CGPoint(x: 3, y: 4), control2: CGPoint(x: 13, y: 3))
            p.addCurve(to: CGPoint(x: 29, y: 12), control1: CGPoint(x: 19, y: 3), control2: CGPoint(x: 29, y: 4))
            p.addCurve(to: CGPoint(x: 16, y: 28), control1: CGPoint(x: 29, y: 17), control2: CGPoint(x: 26, y: 22))
            p.closeSubpath()
            outlined(p, fill: fill, in: ctx)
        case .ghost:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 5, y: 28))
            p.addLine(to: CGPoint(x: 5, y: 15))
            p.addCurve(to: CGPoint(x: 27, y: 15), control1: CGPoint(x: 5, y: -1), control2: CGPoint(x: 27, y: -1))
            p.addLine(to: CGPoint(x: 27, y: 28))
            p.addLine(to: CGPoint(x: 22, y: 24))
            p.addLine(to: CGPoint(x: 16, y: 28))
            p.addLine(to: CGPoint(x: 10, y: 24))
            p.closeSubpath()
            outlined(p, fill: fill, in: ctx)
            ctx.setFillColor(white)
            ctx.fillEllipse(in: CGRect(x: 10, y: 12, width: 4.5, height: 5.5))
            ctx.fillEllipse(in: CGRect(x: 17.5, y: 12, width: 4.5, height: 5.5))
            ctx.setFillColor(CGColor(gray: 0.1, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: 12, y: 14, width: 2.5, height: 3))
            ctx.fillEllipse(in: CGRect(x: 19.5, y: 14, width: 2.5, height: 3))
        }
    }

    private static func arrow(_ o: CGPoint) -> CGPath {
        let p = CGMutablePath()
        p.move(to: o)
        p.addLine(to: CGPoint(x: o.x, y: o.y + 22))
        p.addLine(to: CGPoint(x: o.x + 5.5, y: o.y + 17))
        p.addLine(to: CGPoint(x: o.x + 9.5, y: o.y + 25))
        p.addLine(to: CGPoint(x: o.x + 13, y: o.y + 23.5))
        p.addLine(to: CGPoint(x: o.x + 9, y: o.y + 15.5))
        p.addLine(to: CGPoint(x: o.x + 15.5, y: o.y + 15.5))
        p.closeSubpath()
        return p
    }

    /// A shape with a white edge, a soft shadow and the color inset inside it.
    private static func outlined(_ path: CGPath, fill: CGColor, in ctx: CGContext) {
        let box = path.boundingBoxOfPath
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: CGColor(gray: 0, alpha: 0.45))
        ctx.addPath(path)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
        ctx.setLineWidth(2.4)
        ctx.setLineJoin(.round)
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
        ctx.saveGState()
        // Shrink toward the shape's center so the white edge stays visible.
        let cx = box.midX, cy = box.midY
        ctx.translateBy(x: cx, y: cy); ctx.scaleBy(x: 0.82, y: 0.82); ctx.translateBy(x: -cx, y: -cy)
        ctx.addPath(path)
        ctx.setFillColor(fill)
        ctx.fillPath()
        ctx.restoreGState()
    }
}
