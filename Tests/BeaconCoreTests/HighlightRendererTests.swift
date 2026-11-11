import AppKit
import XCTest

@testable import BeaconCore

@MainActor
final class HighlightRendererTests: XCTestCase {
    private var window: OverlayWindow?

    override func tearDown() async throws {
        window?.close()
        window = nil
    }

    private func settledFrame(style: HighlightStyle, at point: CGPoint) -> HighlightFrame {
        var model = HighlightModel(style: style, pointer: point)
        model.setHighlight(true, at: 0, pointer: point)
        var frame = model.step(pointer: point, time: 0)
        for i in 1...240 { frame = model.step(pointer: point, time: Double(i) / 120) }
        return frame
    }

    func testBodySitsOnThePointerInWindowCoordinates() {
        let frame = CGRect(x: -1512, y: 200, width: 1512, height: 982)
        let window = OverlayWindow(displayID: 2, frame: frame)
        self.window = window
        for style in [HighlightStyle.aura, .keyline, .comet, .sonar] {
            let renderer = HighlightRenderer(style: style, scale: 2)
            renderer.attach(to: window.rootLayer)
            let pointer = CGPoint(x: -1000.5, y: 250.5)
            renderer.render(settledFrame(style: style, at: pointer), windowFrame: frame, isOwner: true)
            XCTAssertEqual(renderer.body.position, CGPoint(x: 511.5, y: 50.5), "\(style)")
            XCTAssertGreaterThan(renderer.body.opacity, 0.95, "\(style) is fully shown (Aura may be mid-breath)")
            renderer.detach()
            XCTAssertNil(renderer.root.superlayer)
        }
    }

    func testStyleSwitchRebuildsLayers() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let window = OverlayWindow(displayID: 1, frame: frame)
        self.window = window
        let renderer = HighlightRenderer(style: .aura, scale: 1)
        renderer.attach(to: window.rootLayer)
        let auraLayers = renderer.body.sublayers?.count ?? 0
        renderer.configure(style: .keyline)
        XCTAssertEqual(renderer.style, .keyline)
        XCTAssertNotEqual(renderer.body.sublayers?.count ?? 0, auraLayers)
        renderer.render(settledFrame(style: .keyline, at: CGPoint(x: 10.3, y: 20.7)), windowFrame: frame, isOwner: true)
        XCTAssertEqual(renderer.body.position, CGPoint(x: 10, y: 21), "snapped at 1x")
    }
}
