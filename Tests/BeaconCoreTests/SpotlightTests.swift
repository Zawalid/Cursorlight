import XCTest
@testable import BeaconCore

final class SpotlightModelTests: XCTestCase {
    private func drawn(_ from: CGPoint, _ to: CGPoint) -> SpotlightModel {
        var m = SpotlightModel()
        m.pointerDown(from)
        m.pointerDragged(to)
        m.pointerUp(to)
        return m
    }

    func testDrawingMakesARegionFromAnyCorner() {
        let m = drawn(CGPoint(x: 300, y: 300), CGPoint(x: 100, y: 120))
        XCTAssertEqual(m.region, CGRect(x: 100, y: 120, width: 200, height: 180))
    }

    func testATinyDragKeepsThePreviousRegion() {
        var m = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 260))
        let before = m.region
        m.pointerDown(CGPoint(x: 600, y: 600))
        m.pointerUp(CGPoint(x: 605, y: 603))
        XCTAssertEqual(m.region, before)
    }

    func testDraggingInsideMovesTheRegion() {
        var m = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 260))
        m.pointerDown(CGPoint(x: 200, y: 180))
        m.pointerDragged(CGPoint(x: 230, y: 150))
        m.pointerUp(CGPoint(x: 230, y: 150))
        XCTAssertEqual(m.region, CGRect(x: 130, y: 70, width: 200, height: 160))
    }

    func testPullingACornerResizesAndKeepsAMinimumSize() {
        var m = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 260))
        XCTAssertEqual(m.handle(at: CGPoint(x: 302, y: 258)), .topRight)
        m.pointerDown(CGPoint(x: 300, y: 260))
        m.pointerDragged(CGPoint(x: 350, y: 300))
        XCTAssertEqual(m.region, CGRect(x: 100, y: 100, width: 250, height: 200))
        m.pointerDragged(CGPoint(x: 90, y: 90))
        m.pointerUp(CGPoint(x: 90, y: 90))
        XCTAssertEqual(m.region?.width, SpotlightModel.minSize)
        XCTAssertEqual(m.region?.height, SpotlightModel.minSize)
        XCTAssertEqual(m.region?.origin, CGPoint(x: 100, y: 100))
    }

    func testDraggingOutsideDrawsANewRegion() {
        var m = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 200))
        m.pointerDown(CGPoint(x: 500, y: 500))
        m.pointerDragged(CGPoint(x: 640, y: 580))
        m.pointerUp(CGPoint(x: 640, y: 580))
        XCTAssertEqual(m.region, CGRect(x: 500, y: 500, width: 140, height: 80))
    }

    func testClear() {
        var m = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 260))
        m.clear()
        XCTAssertNil(m.region)
        XCTAssertFalse(m.isDragging)
    }

    func testSpotlightOptionsClampAndRoundTrip() throws {
        var o = HighlightOptions()
        o.spotlightDim = 5
        o.spotlightSoftness = -3
        o.spotlightCorner = 500
        let clean = o.sanitized()
        XCTAssertEqual(clean.spotlightDim, HighlightOptions.dimRange.upperBound)
        XCTAssertEqual(clean.spotlightSoftness, 0)
        XCTAssertEqual(clean.spotlightCorner, HighlightOptions.cornerRange.upperBound)
        var s = BeaconSettings.defaults
        s.highlightOptions.spotlightShape = .ellipse
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded.highlightOptions.spotlight.shape, .ellipse)
        XCTAssertEqual(TriggerSettings().hotkey(for: .spotlight)?.displayString, "⌃⌥S")
        XCTAssertEqual(TriggerRouter(settings: TriggerSettings()).route(.hotkey(.spotlight), active: .init()), [.spotlight])
    }
}
