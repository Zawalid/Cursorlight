import AppKit
import XCTest
@testable import CursorlightCore

@MainActor
final class InkRendererTests: XCTestCase {
    private func stroke(_ id: Int, _ style: InkStyle, _ color: InkColor, y: CGFloat, alpha: CGFloat = 1) -> InkStrokeFrame {
        let points = (0...40).map { CGPoint(x: 40 + CGFloat($0) * 6, y: y + 18 * sin(Double($0) / 4)) }
        return InkStrokeFrame(id: id, points: points, style: style, color: color, alpha: alpha)
    }

    func testLayersFollowStrokeIdentity() {
        let host = CALayer()
        host.frame = CGRect(x: 0, y: 0, width: 400, height: 200)
        let renderer = InkRenderer(scale: 2)
        renderer.attach(to: host)
        renderer.render(InkFrame(strokes: [stroke(1, .marker, .red, y: 50), stroke(2, .neon, .blue, y: 120)]), windowOrigin: .zero)
        XCTAssertEqual(renderer.root.sublayers?.count, 2)
        renderer.render(InkFrame(strokes: [stroke(2, .neon, .blue, y: 120, alpha: 0.5)]), windowOrigin: .zero)
        XCTAssertEqual(renderer.root.sublayers?.count, 1)
        XCTAssertEqual(renderer.root.sublayers?.first?.opacity ?? 0, 0.5, accuracy: 0.001)
        renderer.render(InkFrame(strokes: []), windowOrigin: .zero)
        XCTAssertEqual(renderer.root.sublayers?.count ?? 0, 0)
    }

    func testSinglePointStrokeHasAPath() {
        let renderer = InkRenderer(scale: 1)
        let dot = InkStrokeFrame(id: 1, points: [CGPoint(x: 10, y: 10)], style: .marker, color: .red, alpha: 1)
        renderer.attach(to: CALayer())
        renderer.render(InkFrame(strokes: [dot]), windowOrigin: .zero)
        XCTAssertFalse(InkRenderer.smoothPath(dot.points).isEmpty)
    }

    /// Writes a PNG of every style when CURSORLIGHT_SNAPSHOT_DIR is set, for looking at by eye. Does nothing otherwise.
    func testSnapshotAllStyles() throws {
        guard let dir = ProcessInfo.processInfo.environment["CURSORLIGHT_SNAPSHOT_DIR"] else { return }
        let size = CGSize(width: 520, height: 420)
        let host = CALayer()
        host.frame = CGRect(origin: .zero, size: size)
        let renderer = InkRenderer(scale: 2)
        renderer.attach(to: host)
        var strokes: [InkStrokeFrame] = []
        for (i, style) in InkStyle.allCases.enumerated() {
            strokes.append(stroke(i, style, .red, y: 60 + CGFloat(i) * 70))
        }
        strokes.append(stroke(10, .neon, .green, y: 300))
        strokes.append(stroke(11, .marker, .white, y: 360))
        renderer.render(InkFrame(strokes: strokes), windowOrigin: .zero)
        let context = try XCTUnwrap(CGContext(
            data: nil, width: Int(size.width) * 2, height: Int(size.height) * 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 0.14, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width * 2, height: size.height * 2 / 2))
        context.setFillColor(CGColor(gray: 0.96, alpha: 1))
        context.fill(CGRect(x: 0, y: size.height, width: size.width * 2, height: size.height))
        context.scaleBy(x: 2, y: 2)
        host.render(in: context)
        let image = try XCTUnwrap(context.makeImage())
        let rep = NSBitmapImageRep(cgImage: image)
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("ink-styles.png"))
    }
}
