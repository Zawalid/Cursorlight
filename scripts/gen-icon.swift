// Generates the app icon into App/Sources/Assets.xcassets/AppIcon.appiconset.
// Pure Core Graphics, drawn at any size: a dark glass tile, a glowing glass ring and a lit, extruded pointer.
// Light comes from the top left. Depth is built from a stack of extrusion layers, inner highlights and inner shadows.
// usage: swift scripts/gen-icon.swift
import AppKit

let out = "App/Sources/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)

let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: space, components: [r, g, b, a]) ?? CGColor(gray: 0, alpha: a) }

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient? {
    CGGradient(colorsSpace: space, colors: stops.map { $0.1 } as CFArray, locations: stops.map { $0.0 })
}

/// Polygon with rounded corners.
func roundedPolygon(_ pts: [CGPoint], radius: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let n = pts.count
    for i in 0..<n {
        let prev = pts[(i + n - 1) % n], cur = pts[i], next = pts[(i + 1) % n]
        let a = CGPoint(x: (cur.x + prev.x) / 2, y: (cur.y + prev.y) / 2)
        if i == 0 { p.move(to: a) } else { p.addLine(to: a) }
        p.addArc(tangent1End: cur, tangent2End: next, radius: radius)
    }
    p.closeSubpath()
    return p
}

/// Light or shadow drawn inside a shape, along the edges. Offset moves where the edge light falls.
func inner(_ ctx: CGContext, _ path: CGPath, offset: CGSize, blur: CGFloat, color: CGColor) {
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let outer = CGMutablePath()
    outer.addRect(path.boundingBoxOfPath.insetBy(dx: -400, dy: -400))
    outer.addPath(path)
    ctx.setShadow(offset: offset, blur: blur, color: color)
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.addPath(outer)
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
}

func draw(_ px: Int) -> Data? {
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)

    // ---- Tile ----
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: rgb(0, 0, 0, 0.55))
    ctx.addPath(tilePath); ctx.setFillColor(rgb(0.05, 0.04, 0.09)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    if let g = gradient([(0, rgb(0.27, 0.19, 0.44)), (0.5, rgb(0.13, 0.09, 0.24)), (1, rgb(0.04, 0.03, 0.09))]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 330, y: 924), end: CGPoint(x: 700, y: 100),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    // Warm light pooling in the middle of the tile.
    let c = CGPoint(x: 512, y: 486)
    if let g = gradient([(0, rgb(1, 0.36, 0.2, 0.42)), (0.55, rgb(1, 0.3, 0.2, 0.12)), (1, rgb(1, 0.3, 0.2, 0))]) {
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: 420, options: [])
    }
    // Soft glass sheen across the upper part.
    if let g = gradient([(0, rgb(1, 1, 1, 0.16)), (1, rgb(1, 1, 1, 0))]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [.drawsBeforeStartLocation])
    }
    ctx.restoreGState()
    // Tile edge: light on the upper rim, shade on the lower rim.
    inner(ctx, tilePath, offset: CGSize(width: 0, height: -3), blur: 2, color: rgb(1, 1, 1, 0.55))
    inner(ctx, tilePath, offset: CGSize(width: 0, height: 4), blur: 8, color: rgb(0, 0, 0, 0.55))

    // ---- Ring: a glass tube lit from the top left ----
    let ringC = CGPoint(x: 512, y: 500), ringR: CGFloat = 262, ringW: CGFloat = 44
    let arc = CGMutablePath()
    arc.addEllipse(in: CGRect(x: ringC.x - ringR, y: ringC.y - ringR, width: ringR * 2, height: ringR * 2))
    let ringPath = arc.copy(strokingWithWidth: ringW, lineCap: .butt, lineJoin: .round, miterLimit: 10)

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 60, color: rgb(1, 0.34, 0.18, 0.95))
    ctx.addPath(ringPath); ctx.setFillColor(rgb(1, 0.4, 0.25)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 10, height: -16), blur: 22, color: rgb(0, 0, 0, 0.5))
    ctx.addPath(ringPath); ctx.setFillColor(rgb(1, 0.4, 0.25)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(ringPath); ctx.clip()
    if let g = gradient([(0, rgb(1, 0.86, 0.74)), (0.45, rgb(1, 0.55, 0.36)), (1, rgb(0.86, 0.2, 0.1))]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 280, y: 760), end: CGPoint(x: 760, y: 240), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    // Specular streak along the upper left of the tube.
    ctx.setLineCap(.round)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.8)); ctx.setLineWidth(8)
    ctx.addArc(center: ringC, radius: ringR + 8, startAngle: 2.0, endAngle: 2.75, clockwise: false)
    ctx.strokePath()
    ctx.setStrokeColor(rgb(1, 1, 1, 0.35)); ctx.setLineWidth(5)
    ctx.addArc(center: ringC, radius: ringR - 10, startAngle: 3.35, endAngle: 3.9, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()
    inner(ctx, ringPath, offset: CGSize(width: 3, height: -4), blur: 4, color: rgb(1, 1, 1, 0.7))
    inner(ctx, ringPath, offset: CGSize(width: -5, height: 7), blur: 10, color: rgb(0.45, 0.04, 0, 0.75))

    // ---- Pointer ----
    let S: CGFloat = 355
    let origin = CGPoint(x: 512 - 0.38 * S, y: 500 + 0.56 * S)
    let unit: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -1.0), CGPoint(x: 0.24, y: -0.78),
        CGPoint(x: 0.40, y: -1.14), CGPoint(x: 0.60, y: -1.05), CGPoint(x: 0.44, y: -0.70),
        CGPoint(x: 0.76, y: -0.70),
    ]
    func pointer(offset: CGPoint) -> CGPath {
        roundedPolygon(unit.map { CGPoint(x: origin.x + $0.x * S + offset.x, y: origin.y + $0.y * S + offset.y) }, radius: 24)
    }
    let depth = 34
    // Cast shadow of the whole solid.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 14, height: -26), blur: 34, color: rgb(0, 0, 0, 0.6))
    ctx.addPath(pointer(offset: CGPoint(x: CGFloat(depth) * 0.55, y: -CGFloat(depth) * 0.55)))
    ctx.setFillColor(rgb(0.4, 0.08, 0.03)); ctx.fillPath()
    ctx.restoreGState()
    // Extrusion: stacked copies, darker towards the back.
    for i in stride(from: depth, through: 1, by: -1) {
        let t = CGFloat(i) / CGFloat(depth)
        let d = CGFloat(i) * 0.6
        ctx.addPath(pointer(offset: CGPoint(x: d, y: -d)))
        ctx.setFillColor(rgb(0.78 - 0.34 * t, 0.2 - 0.12 * t, 0.1 - 0.07 * t))
        ctx.fillPath()
    }
    // Front face.
    let face = pointer(offset: .zero)
    ctx.saveGState()
    ctx.addPath(face); ctx.clip()
    if let g = gradient([(0, rgb(1, 0.62, 0.46)), (0.45, rgb(1, 0.38, 0.22)), (1, rgb(0.9, 0.22, 0.1))]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: origin.x, y: origin.y), end: CGPoint(x: origin.x + 0.7 * S, y: origin.y - 1.1 * S),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    // Gloss on the upper half of the face.
    if let g = gradient([(0, rgb(1, 1, 1, 0.34)), (1, rgb(1, 1, 1, 0))]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: origin.x, y: origin.y), end: CGPoint(x: origin.x + 0.25 * S, y: origin.y - 0.55 * S),
                               options: [.drawsBeforeStartLocation])
    }
    ctx.restoreGState()
    inner(ctx, face, offset: CGSize(width: 3, height: -3), blur: 3, color: rgb(1, 1, 1, 0.85))
    inner(ctx, face, offset: CGSize(width: -4, height: 5), blur: 9, color: rgb(0.5, 0.05, 0, 0.7))

    guard let image = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

var images: [[String: String]] = []
for (size, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = size * scale
    let name = "icon_\(size)x\(size)@\(scale)x.png"
    if let data = draw(px) { try? data.write(to: URL(fileURLWithPath: "\(out)/\(name)")) }
    images.append(["size": "\(size)x\(size)", "idiom": "mac", "filename": name, "scale": "\(scale)x"])
}
if let data = draw(1024) { try? data.write(to: URL(fileURLWithPath: "build/icon-master.png")) }
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
if let json = try? JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]) {
    try? json.write(to: URL(fileURLWithPath: "\(out)/Contents.json"))
}
let top: [String: Any] = ["info": ["version": 1, "author": "xcode"]]
if let json = try? JSONSerialization.data(withJSONObject: top) { try? json.write(to: URL(fileURLWithPath: "App/Sources/Assets.xcassets/Contents.json")) }
print("wrote \(images.count) icons")
