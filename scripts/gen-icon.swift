// Generates the placeholder app icon into App/Sources/Assets.xcassets/AppIcon.appiconset.
// usage: swift scripts/gen-icon.swift   (replace the artwork when the real identity exists)
import AppKit

let out = "App/Sources/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data? {
    let s = CGFloat(px)
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let inset = s * 0.098
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let bg = CGGradient(colorsSpace: space, colors: [CGColor(red: 0.17, green: 0.09, blue: 0.07, alpha: 1), CGColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)] as CFArray, locations: [0, 1])
    if let bg { ctx.drawLinearGradient(bg, start: CGPoint(x: s / 2, y: rect.maxY), end: CGPoint(x: s / 2, y: rect.minY), options: []) }
    let c = CGPoint(x: s / 2, y: s / 2)
    // Outer glow, core, light centre.
    let glow = CGGradient(colorsSpace: space, colors: [CGColor(red: 1, green: 0.35, blue: 0.21, alpha: 0.55), CGColor(red: 1, green: 0.35, blue: 0.21, alpha: 0.0)] as CFArray, locations: [0, 1])
    if let glow { ctx.drawRadialGradient(glow, startCenter: c, startRadius: 0, endCenter: c, endRadius: s * 0.38, options: []) }
    let core = CGGradient(colorsSpace: space, colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 1), CGColor(red: 1, green: 0.45, blue: 0.3, alpha: 1), CGColor(red: 1, green: 0.35, blue: 0.21, alpha: 0)] as CFArray, locations: [0, 0.35, 1])
    if let core { ctx.drawRadialGradient(core, startCenter: c, startRadius: 0, endCenter: c, endRadius: s * 0.17, options: []) }
    // Thin ring.
    ctx.setStrokeColor(CGColor(red: 1, green: 0.8, blue: 0.72, alpha: 0.55))
    ctx.setLineWidth(max(s * 0.012, 1))
    ctx.strokeEllipse(in: CGRect(x: c.x - s * 0.25, y: c.y - s * 0.25, width: s * 0.5, height: s * 0.5))
    ctx.restoreGState()
    // Hairline edge.
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.setLineWidth(max(s * 0.004, 1))
    ctx.strokePath()
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
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
if let json = try? JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]) {
    try? json.write(to: URL(fileURLWithPath: "\(out)/Contents.json"))
}
let top: [String: Any] = ["info": ["version": 1, "author": "xcode"]]
if let json = try? JSONSerialization.data(withJSONObject: top) { try? json.write(to: URL(fileURLWithPath: "App/Sources/Assets.xcassets/Contents.json")) }
print("wrote \(images.count) icons")
