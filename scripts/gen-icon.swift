// Generates the 3D app icon into App/Sources/Assets.xcassets/AppIcon.appiconset.
// A glossy extruded pointer inside a glowing ring, rendered with SceneKit, on a dark glass tile.
// usage: swift scripts/gen-icon.swift
import AppKit
import SceneKit
import Metal

let out = "App/Sources/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

let master = 1024
let accent = NSColor(srgbRed: 1.0, green: 0.353, blue: 0.212, alpha: 1)

func shape() -> SCNNode {
    let p = NSBezierPath()
    let pts: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -1.0), CGPoint(x: 0.24, y: -0.78),
        CGPoint(x: 0.40, y: -1.14), CGPoint(x: 0.60, y: -1.05), CGPoint(x: 0.44, y: -0.70),
        CGPoint(x: 0.76, y: -0.70),
    ]
    p.move(to: pts[0])
    for q in pts.dropFirst() { p.line(to: q) }
    p.close()
    p.flatness = 0.001
    let s = SCNShape(path: p, extrusionDepth: 0.34)
    s.chamferRadius = 0.07
    s.chamferMode = .both
    let m = SCNMaterial()
    m.lightingModel = .blinn
    m.diffuse.contents = accent
    m.specular.contents = NSColor(white: 1, alpha: 1)
    m.shininess = 0.8
    m.emission.contents = NSColor(srgbRed: 0.22, green: 0.03, blue: 0.0, alpha: 1)
    s.materials = [m]
    let n = SCNNode(geometry: s)
    n.pivot = SCNMatrix4MakeTranslation(0.38, -0.55, 0.17)
    return n
}

func scene() -> SCNScene {
    let sc = SCNScene()
    sc.background.contents = NSColor.clear

    let pointer = shape()
    pointer.eulerAngles = SCNVector3(0.30, 0.50, 0.08)
    pointer.scale = SCNVector3(1.4, 1.4, 1.4)
    pointer.position = SCNVector3(0.30, 0.05, 0.1)
    sc.rootNode.addChildNode(pointer)

    // Glowing ring behind and around the pointer.
    let torus = SCNTorus(ringRadius: 1.12, pipeRadius: 0.06)
    let rm = SCNMaterial()
    rm.lightingModel = .constant
    rm.diffuse.contents = NSColor(srgbRed: 1, green: 0.72, blue: 0.58, alpha: 1)
    torus.materials = [rm]
    let ring = SCNNode(geometry: torus)
    ring.eulerAngles = SCNVector3(1.18, 0.15, 0.0)
    ring.position = SCNVector3(0, 0, -0.25)
    sc.rootNode.addChildNode(ring)

    func light(_ type: SCNLight.LightType, _ color: NSColor, _ intensity: CGFloat, _ pos: SCNVector3) -> SCNNode {
        let l = SCNLight(); l.type = type; l.color = color; l.intensity = intensity
        let n = SCNNode(); n.light = l; n.position = pos; n.look(at: SCNVector3(0, 0, 0))
        return n
    }
    sc.rootNode.addChildNode(light(.omni, .white, 1500, SCNVector3(-2.2, 3.4, 3.6)))
    sc.rootNode.addChildNode(light(.omni, NSColor(srgbRed: 1, green: 0.85, blue: 0.75, alpha: 1), 350, SCNVector3(3.5, -1.5, 2.5)))
    sc.rootNode.addChildNode(light(.ambient, NSColor(white: 0.5, alpha: 1), 120, SCNVector3(0, 0, 0)))

    let cam = SCNCamera()
    cam.fieldOfView = 34
    cam.zNear = 0.1
    cam.zFar = 50
        let cn = SCNNode(); cn.camera = cam; cn.position = SCNVector3(0, 0, 5.4)
    sc.rootNode.addChildNode(cn)
    return sc
}

func render3D(_ px: Int) -> CGImage? {
    guard let device = MTLCreateSystemDefaultDevice() else { return nil }
    let r = SCNRenderer(device: device, options: nil)
    let sc = scene()
    r.scene = sc
    r.pointOfView = sc.rootNode.childNodes.first { $0.camera != nil }
    let img = r.snapshot(atTime: 0, with: CGSize(width: px, height: px), antialiasingMode: .multisampling4X)
    return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func compose(_ px: Int, _ fg: CGImage) -> Data? {
    let s = CGFloat(px)
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.interpolationQuality = .high
    let inset = s * 0.098
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)
    // Soft drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: CGColor(gray: 0, alpha: 0.45))
    ctx.addPath(path); ctx.setFillColor(CGColor(gray: 0.05, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let bg = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.20, green: 0.14, blue: 0.30, alpha: 1),
        CGColor(red: 0.08, green: 0.06, blue: 0.14, alpha: 1),
        CGColor(red: 0.03, green: 0.03, blue: 0.06, alpha: 1)] as CFArray, locations: [0, 0.55, 1])
    if let bg { ctx.drawLinearGradient(bg, start: CGPoint(x: s * 0.3, y: rect.maxY), end: CGPoint(x: s * 0.7, y: rect.minY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]) }
    // Warm bloom behind the subject.
    let c = CGPoint(x: s * 0.5, y: s * 0.47)
    let glow = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 1, green: 0.35, blue: 0.21, alpha: 0.55),
        CGColor(red: 1, green: 0.35, blue: 0.21, alpha: 0)] as CFArray, locations: [0, 1])
    if let glow { ctx.drawRadialGradient(glow, startCenter: c, startRadius: 0, endCenter: c, endRadius: s * 0.46, options: []) }
    // The 3D render.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.05, color: CGColor(red: 1, green: 0.35, blue: 0.2, alpha: 0.9))
    ctx.draw(fg, in: CGRect(x: 0, y: 0, width: s, height: s))
    ctx.restoreGState()
    ctx.draw(fg, in: CGRect(x: 0, y: 0, width: s, height: s))
    // Glass sheen on the upper half of the tile.
    let sheen = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.16),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray, locations: [0, 1])
    if let sheen { ctx.drawLinearGradient(sheen, start: CGPoint(x: s / 2, y: rect.maxY), end: CGPoint(x: s / 2, y: rect.midY), options: [.drawsAfterEndLocation]) }
    ctx.restoreGState()
    // Hairline edge.
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(max(s * 0.004, 1))
    ctx.strokePath()
    guard let image = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

guard let fg = render3D(master) else { print("3D render failed"); exit(1) }
var images: [[String: String]] = []
for (size, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = size * scale
    let name = "icon_\(size)x\(size)@\(scale)x.png"
    if let data = compose(px, fg) { try? data.write(to: URL(fileURLWithPath: "\(out)/\(name)")) }
    images.append(["size": "\(size)x\(size)", "idiom": "mac", "filename": name, "scale": "\(scale)x"])
}
if let data = compose(1024, fg) { try? data.write(to: URL(fileURLWithPath: "\(out)/../icon-master.png")) }
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
if let json = try? JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]) {
    try? json.write(to: URL(fileURLWithPath: "\(out)/Contents.json"))
}
let top: [String: Any] = ["info": ["version": 1, "author": "xcode"]]
if let json = try? JSONSerialization.data(withJSONObject: top) { try? json.write(to: URL(fileURLWithPath: "App/Sources/Assets.xcassets/Contents.json")) }
print("wrote \(images.count) icons")
