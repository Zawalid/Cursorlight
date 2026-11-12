import XCTest
@testable import BeaconCore

final class InkModelTests: XCTestCase {
    private func draw(_ model: inout InkModel, _ points: [CGPoint], endAt end: TimeInterval = 0) {
        guard let first = points.first else { return }
        model.begin(at: first, style: .marker, color: .red)
        for p in points.dropFirst() { model.append(p) }
        model.end(at: end)
    }

    private var circle: [CGPoint] {
        (0...90).map { i in
            let a = 2 * Double.pi * 1.03 * Double(i) / 90
            return CGPoint(x: 300 + 80 * cos(a), y: 300 + 80 * sin(a))
        }
    }

    private var wave: [CGPoint] {
        (0...60).map { CGPoint(x: 100 + CGFloat($0) * 4, y: 200 + 50 * sin(Double($0) / 3)) }
    }

    func testStrokeIsFullyVisibleThenFadesThenIsRemoved() {
        var model = InkModel()
        draw(&model, wave, endAt: 10)
        XCTAssertEqual(model.step(time: 11).strokes.first?.alpha, 1)
        let fading = model.step(time: 12.3).strokes.first?.alpha ?? -1
        XCTAssertEqual(fading, 0.5, accuracy: 0.01)
        XCTAssertTrue(model.step(time: 13).strokes.isEmpty)
        XCTAssertFalse(model.needsFrames)
    }

    func testStrokeBeingDrawnNeverFades() {
        var model = InkModel()
        model.begin(at: .zero, style: .marker, color: .red)
        model.append(CGPoint(x: 50, y: 0))
        XCTAssertTrue(model.isDrawing)
        XCTAssertEqual(model.step(time: 999).strokes.first?.alpha, 1)
    }

    func testCircleMorphsFromRawToEllipse() {
        var model = InkModel()
        var wobbly = circle
        for i in wobbly.indices { wobbly[i].x += CGFloat(i % 3) * 2 }
        draw(&model, wobbly, endAt: 5)
        let start = model.step(time: 5).strokes[0].points
        let end = model.step(time: 5.5).strokes[0].points
        XCTAssertEqual(start.count, InkModel.morphPointCount)
        XCTAssertEqual(end.count, InkModel.morphPointCount)
        // After the morph every point sits on the fitted ellipse (center roughly 300, radius roughly 80).
        let radii = end.map { hypot($0.x - 301, $0.y - 300) }
        XCTAssertLessThan((radii.max() ?? 0) - (radii.min() ?? 0), 6)
        XCTAssertNotEqual(start, end)
    }

    func testCleanupDisabledKeepsRawPoints() {
        var model = InkModel(cleanupEnabled: false)
        draw(&model, circle, endAt: 1)
        let frame = model.step(time: 2)
        XCTAssertNotEqual(frame.strokes[0].points.count, InkModel.morphPointCount)
    }

    func testUnrecognizedStrokeKeepsRawPoints() {
        var model = InkModel()
        draw(&model, wave, endAt: 1)
        XCTAssertEqual(model.step(time: 3).strokes[0].points.count, model.step(time: 1).strokes[0].points.count)
    }

    func testUndoRemovesNewestStroke() {
        var model = InkModel()
        draw(&model, wave)
        draw(&model, wave)
        XCTAssertEqual(model.strokeCount, 2)
        model.undo()
        XCTAssertEqual(model.strokeCount, 1)
        model.undo()
        model.undo()
        XCTAssertEqual(model.strokeCount, 0)
    }

    func testClearFadesQuicklyEvenWhileDrawing() {
        var model = InkModel()
        model.begin(at: .zero, style: .neon, color: .blue)
        model.append(CGPoint(x: 40, y: 0))
        model.clear(at: 1)
        XCTAssertFalse(model.isDrawing)
        XCTAssertEqual(model.step(time: 1.1).strokes.first?.alpha ?? -1, 0.5, accuracy: 0.01)
        XCTAssertTrue(model.step(time: 1.3).strokes.isEmpty)
    }

    func testSingleClickMakesADotAndEndWithoutBeginIsSafe() {
        var model = InkModel()
        model.end(at: 0)
        model.append(CGPoint(x: 1, y: 1))
        model.undo()
        draw(&model, [CGPoint(x: 10, y: 10)])
        XCTAssertEqual(model.step(time: 0.1).strokes.first?.points.count, 1)
    }

    func testNonFinitePointsAreIgnoredAndPointCountIsCapped() {
        var model = InkModel()
        model.begin(at: CGPoint(x: CGFloat.nan, y: 0), style: .marker, color: .red)
        XCTAssertEqual(model.strokeCount, 0)
        model.begin(at: .zero, style: .marker, color: .red)
        model.append(CGPoint(x: CGFloat.infinity, y: 0))
        for i in 1...6000 { model.append(CGPoint(x: CGFloat(i) * 2, y: 0)) }
        XCTAssertLessThanOrEqual(model.step(time: 0).strokes[0].points.count, InkModel.maxPointsPerStroke)
    }
}
