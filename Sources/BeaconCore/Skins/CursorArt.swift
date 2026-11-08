import CoreGraphics

/// sRGB color with straight alpha, kept as plain values so art descriptions stay `Sendable`.
struct RGBA: Sendable {
    let red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    static let white = RGBA(1, 1, 1)
    static let black = RGBA(0, 0, 0)

    var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
    func with(alpha: CGFloat) -> RGBA { RGBA(red, green, blue, alpha) }
}

/// Two shadows tuned to survive video compression: a tight contact shadow that keeps the edge readable on
/// light backgrounds, and a wide, fairly dense ambient one that encoders do not smear into nothing.
struct SkinShadow: Sendable {
    var tint: RGBA = .black
    var contactAlpha: CGFloat = 0.45
    var contactBlur: CGFloat = 1.5
    var contactOffset: CGFloat = 0.8
    var ambientAlpha: CGFloat = 0.32
    var ambientBlur: CGFloat = 6
    var ambientOffset: CGFloat = 2.5

    /// Room the shadow needs around the art, in points.
    static let padding: CGFloat = 12
}

enum SkinFill: Sendable {
    case solid(RGBA)
    case vertical(top: RGBA, bottom: RGBA)
}

struct SkinGlow: Sendable {
    let color: RGBA
    let radius: CGFloat
}

/// Look of a vector skin.
struct VectorStyle: Sendable {
    var fill: SkinFill
    var stroke: RGBA
    /// Visible outline width outside the shape, in points.
    var strokeWidth: CGFloat
    /// Color of interior detail lines (finger separations).
    var detail: RGBA
    var glow: SkinGlow?
    /// Thin light rim just inside the outline.
    var rim: RGBA?
    var shadow = SkinShadow()
}

/// Look of a pixel-art skin.
struct PixelStyle: Sendable {
    var fill: RGBA
    var shade: RGBA
    var outline: RGBA
    /// One-cell ring outside the outline so the dark edge still reads on dark backgrounds.
    var halo: RGBA = RGBA(1, 1, 1, 0.85)
    /// Size of one art pixel, in points.
    var cell: CGFloat = 1.5
    var shadow = SkinShadow()
}

/// Vector outlines for each cursor kind, in a top-left, y-down point space, plus the hotspot in that space.
enum CursorShapes {
    struct Shape {
        let outline: CGPath
        let details: CGPath?
        let hotspot: CGPoint
    }

    static func shape(for kind: CursorKind) -> Shape {
        switch kind {
        case .arrow: arrow()
        case .hand: hand()
        case .ibeam: ibeam()
        }
    }

    private static func arrow() -> Shape {
        let path = CGMutablePath()
        path.addLines(between: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 16.9),
            CGPoint(x: 4.0, y: 13.1),
            CGPoint(x: 6.6, y: 19.3),
            CGPoint(x: 9.35, y: 18.15),
            CGPoint(x: 6.8, y: 12.1),
            CGPoint(x: 12.25, y: 12.1),
        ])
        path.closeSubpath()
        return Shape(outline: path, details: nil, hotspot: .zero)
    }

    private static func roundedRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> CGPath {
        CGPath(
            roundedRect: CGRect(x: x, y: y, width: width, height: height),
            cornerWidth: radius, cornerHeight: radius, transform: nil
        )
    }

    private static func hand() -> Shape {
        let index = roundedRect(5.1, 0, 3.8, 12.6, 1.9)
        let middle = roundedRect(8.7, 6.6, 3.6, 7.8, 1.8)
        let ring = roundedRect(11.9, 7.6, 3.4, 7.4, 1.7)
        let pinky = roundedRect(14.9, 9.0, 3.0, 6.8, 1.5)
        let palm = roundedRect(3.2, 8.6, 13.8, 12.6, 4.5)
        var thumbTransform = CGAffineTransform(translationX: 5.4, y: 15.6).rotated(by: 42 * .pi / 180)
        let thumb = CGPath(
            roundedRect: CGRect(x: -7.2, y: -1.85, width: 7.8, height: 3.7),
            cornerWidth: 1.85, cornerHeight: 1.85, transform: &thumbTransform
        )
        let outline = [middle, ring, pinky, palm, thumb].reduce(index) { $0.union($1) }

        let details = CGMutablePath()
        for (x, top, bottom) in [(CGFloat(8.9), CGFloat(9.8), CGFloat(12.6)), (12.1, 10.6, 13.4), (15.1, 11.6, 14.2)] {
            details.move(to: CGPoint(x: x, y: top))
            details.addLine(to: CGPoint(x: x, y: bottom))
        }
        return Shape(outline: outline, details: details, hotspot: CGPoint(x: 7, y: 0))
    }

    private static func ibeam() -> Shape {
        let stem = CGPath(rect: CGRect(x: 3, y: 0.8, width: 2, height: 16.4), transform: nil)
        let top = roundedRect(0, 0, 8, 1.8, 0.9)
        let bottom = roundedRect(0, 16.2, 8, 1.8, 0.9)
        return Shape(outline: stem.union(top).union(bottom), details: nil, hotspot: CGPoint(x: 4, y: 9))
    }
}

/// Pixel-art bitmaps: `#` outline, `o` fill, `.` empty. Shaded fill is derived from the outline.
enum PixelArt {
    struct Bitmap {
        let rows: [[Character]]
        /// Hotspot in cells from the top-left.
        let hotspot: CGPoint
        var width: Int { rows.map(\.count).max() ?? 0 }
        var height: Int { rows.count }

        func cell(_ column: Int, _ row: Int) -> Character {
            guard row >= 0, row < rows.count, column >= 0, column < rows[row].count else { return "." }
            return rows[row][column]
        }
    }

    static func bitmap(for kind: CursorKind) -> Bitmap {
        switch kind {
        case .arrow: Bitmap(rows: arrow.map(Array.init), hotspot: .zero)
        case .hand: Bitmap(rows: hand.map(Array.init), hotspot: CGPoint(x: 5, y: 0))
        case .ibeam: Bitmap(rows: ibeam.map(Array.init), hotspot: CGPoint(x: 4.5, y: 8))
        }
    }

    private static let arrow = [
        "#...........",
        "##..........",
        "#o#.........",
        "#oo#........",
        "#ooo#.......",
        "#oooo#......",
        "#ooooo#.....",
        "#oooooo#....",
        "#ooooooo#...",
        "#oooooooo#..",
        "#ooooo#####.",
        "#oo#oo#.....",
        "#o#.#oo#....",
        "##..#oo#....",
        "#....#oo#...",
        ".....#oo#...",
        "......##....",
    ]

    private static let hand = [
        "....##..........",
        "...#oo#.........",
        "...#oo#.........",
        "...#oo#.........",
        "...#oo###.......",
        "...#oo#oo###....",
        "...#oo#oo#oo##..",
        "##.#oo#oo#oo#o#.",
        "#o##oooooooo#o#.",
        "#oo#oooooooooo#.",
        "#oooooooooooooo#",
        ".#oooooooooooo#.",
        "..#ooooooooooo#.",
        "..#oooooooooo#..",
        "...#oooooooo#...",
        "...#oooooooo#...",
        "...##########...",
    ]

    private static let ibeam = [
        ".###.###.",
        "#ooo#ooo#",
        ".###o###.",
        "...#o#...",
        "...#o#...",
        "...#o#...",
        "...#o#...",
        "...#o#...",
        "...#o#...",
        "...#o#...",
        "...#o#...",
        "...#o#...",
        "...#o#...",
        ".###o###.",
        "#ooo#ooo#",
        ".###.###.",
    ]
}

/// Turns shapes and styles into `SkinArtwork`.
enum SkinPainter {
    static func vector(_ kind: CursorKind, style: VectorStyle) -> SkinArtwork {
        let shape = CursorShapes.shape(for: kind)
        let reach = style.strokeWidth + (style.glow?.radius ?? 0) * 0.5
        let bounds = shape.outline.boundingBoxOfPath.insetBy(dx: -reach, dy: -reach)
        return layout(bounds: bounds, hotspot: shape.hotspot) { context in
            let shape = CursorShapes.shape(for: kind)
            withShadows(style.shadow, in: context) {
                drawVector(shape, style: style, in: context)
            }
        }
    }

    static func pixel(_ kind: CursorKind, style: PixelStyle) -> SkinArtwork {
        let bitmap = PixelArt.bitmap(for: kind)
        let bounds = CGRect(x: 0, y: 0, width: CGFloat(bitmap.width) * style.cell, height: CGFloat(bitmap.height) * style.cell)
            .insetBy(dx: -style.cell, dy: -style.cell)
        let hotspot = CGPoint(x: bitmap.hotspot.x * style.cell, y: bitmap.hotspot.y * style.cell)
        return layout(bounds: bounds, hotspot: hotspot) { context in
            withShadows(style.shadow, in: context) {
                drawPixels(PixelArt.bitmap(for: kind), style: style, in: context)
            }
        }
    }

    /// Places art of the given bounds on a canvas with whole-point padding for the shadow, so hotspots stay on
    /// the same sub-point grid as the art.
    private static func layout(bounds: CGRect, hotspot: CGPoint, draw: @escaping @Sendable (CGContext) -> Void) -> SkinArtwork {
        let pad = SkinShadow.padding
        let offset = CGPoint(x: (pad - bounds.minX).rounded(.up), y: (pad - bounds.minY).rounded(.up))
        let size = CGSize(
            width: (offset.x + bounds.maxX + pad).rounded(.up),
            height: (offset.y + bounds.maxY + pad).rounded(.up)
        )
        return SkinArtwork(canvasSize: size, hotspot: CGPoint(x: hotspot.x + offset.x, y: hotspot.y + offset.y)) { context in
            context.saveGState()
            context.translateBy(x: offset.x, y: offset.y)
            draw(context)
            context.restoreGState()
        }
    }

    /// Shadow offsets and blur are in device pixels, unaffected by the transform, so they are scaled here, and
    /// a downward shadow is negative because the device space is y-up.
    private static func withShadows(_ shadow: SkinShadow, in context: CGContext, _ draw: () -> Void) {
        let scale = max(abs(context.ctm.a), 0.01)
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -shadow.ambientOffset * scale),
            blur: shadow.ambientBlur * scale,
            color: shadow.tint.with(alpha: shadow.ambientAlpha).cgColor
        )
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setShadow(
            offset: CGSize(width: 0, height: -shadow.contactOffset * scale),
            blur: shadow.contactBlur * scale,
            color: shadow.tint.with(alpha: shadow.contactAlpha).cgColor
        )
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        draw()
        context.endTransparencyLayer()
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func drawVector(_ shape: CursorShapes.Shape, style: VectorStyle, in context: CGContext) {
        let scale = max(abs(context.ctm.a), 0.01)
        context.setLineJoin(.round)
        context.setLineCap(.round)

        if let glow = style.glow {
            context.saveGState()
            context.setShadow(offset: .zero, blur: glow.radius * scale, color: glow.color.cgColor)
            context.addPath(shape.outline)
            context.setStrokeColor(glow.color.cgColor)
            context.setLineWidth(style.strokeWidth * 2)
            context.strokePath()
            context.restoreGState()
        }

        // Stroke at double width, then fill over the inner half: the outline sits fully outside the shape.
        context.addPath(shape.outline)
        context.setStrokeColor(style.stroke.cgColor)
        context.setLineWidth(style.strokeWidth * 2)
        context.strokePath()

        context.saveGState()
        context.addPath(shape.outline)
        context.clip()
        let box = shape.outline.boundingBoxOfPath
        switch style.fill {
        case .solid(let color):
            context.setFillColor(color.cgColor)
            context.fill(box)
        case .vertical(let top, let bottom):
            if let space = CGColorSpace(name: CGColorSpace.sRGB),
               let gradient = CGGradient(colorsSpace: space, colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(
                    gradient, start: CGPoint(x: box.midX, y: box.minY), end: CGPoint(x: box.midX, y: box.maxY), options: []
                )
            } else {
                context.setFillColor(top.cgColor)
                context.fill(box)
            }
        }
        if let rim = style.rim {
            context.addPath(shape.outline)
            context.setStrokeColor(rim.cgColor)
            context.setLineWidth(1.4)
            context.strokePath()
        }
        if let details = shape.details {
            context.addPath(details)
            context.setStrokeColor(style.detail.cgColor)
            context.setLineWidth(0.9)
            context.strokePath()
        }
        context.restoreGState()
    }

    private static func drawPixels(_ bitmap: PixelArt.Bitmap, style: PixelStyle, in context: CGContext) {
        let cell = style.cell
        for row in -1...bitmap.height {
            for column in -1...bitmap.width {
                let color: RGBA
                switch bitmap.cell(column, row) {
                case "#":
                    color = style.outline
                case "o":
                    // Fill cells touching the outline on their right or bottom get the shade: a lit-from-top-left look.
                    let shaded = bitmap.cell(column + 1, row) == "#" || bitmap.cell(column, row + 1) == "#"
                    color = shaded ? style.shade : style.fill
                default:
                    let touchesOutline = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains {
                        bitmap.cell(column + $0.0, row + $0.1) == "#"
                    }
                    guard touchesOutline else { continue }
                    color = style.halo
                }
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
            }
        }
    }
}
