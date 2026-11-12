import XCTest
@testable import BeaconCore

final class ShapeRecognizerTests: XCTestCase {
    private let recognizer = ShapeRecognizer()

    /// Deterministic jitter in -amount...amount.
    private func jitter(_ i: Int, _ amount: CGFloat) -> CGFloat {
        CGFloat(sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1) * amount
    }

    private func loop(center: CGPoint, rx: CGFloat, ry: CGFloat, noise: CGFloat = 3, turns: Double = 1.04) -> [CGPoint] {
        let n = 90
        return (0...n).map { i in
            let a = 2 * Double.pi * turns * Double(i) / Double(n) + 0.7
            return CGPoint(
                x: center.x + (rx + jitter(i, noise)) * CGFloat(cos(a)),
                y: center.y + (ry + jitter(i + 500, noise)) * CGFloat(sin(a))
            )
        }
    }

    private func line(from a: CGPoint, to b: CGPoint, noise: CGFloat = 1.5) -> [CGPoint] {
        let n = 40
        return (0...n).map { i in
            let t = CGFloat(i) / CGFloat(n)
            return CGPoint(x: a.x + (b.x - a.x) * t + jitter(i, noise), y: a.y + (b.y - a.y) * t + jitter(i + 99, noise))
        }
    }

    func testCircleDrawnWithJitterIsEllipse() {
        let points = loop(center: CGPoint(x: 300, y: 300), rx: 80, ry: 80)
        guard case let .ellipse(rect) = recognizer.recognize(points) else { return XCTFail("expected ellipse") }
        XCTAssertEqual(rect.midX, 300, accuracy: 8)
        XCTAssertEqual(rect.width, 160, accuracy: 16)
    }

    func testWideOvalIsEllipse() {
        let points = loop(center: CGPoint(x: 500, y: 200), rx: 150, ry: 50)
        guard case let .ellipse(rect) = recognizer.recognize(points) else { return XCTFail("expected ellipse") }
        XCTAssertGreaterThan(rect.width, rect.height * 2)
    }

    func testRectangleIsRectangle() {
        var points: [CGPoint] = []
        let corners = [CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 100), CGPoint(x: 300, y: 220), CGPoint(x: 100, y: 220), CGPoint(x: 102, y: 104)]
        for (a, b) in zip(corners, corners.dropFirst()) { points += line(from: a, to: b, noise: 1.5) }
        guard case let .rectangle(rect) = recognizer.recognize(points) else { return XCTFail("expected rectangle") }
        XCTAssertEqual(rect.width, 200, accuracy: 12)
        XCTAssertEqual(rect.height, 120, accuracy: 12)
    }

    func testStraightStrokeWithHeadIsArrow() {
        let tip = CGPoint(x: 400, y: 300)
        let shaft = line(from: CGPoint(x: 100, y: 100), to: tip)
        let wing = line(from: tip, to: CGPoint(x: 380, y: 262))
        guard case let .arrow(from, to) = recognizer.recognize(shaft + wing) else { return XCTFail("expected arrow") }
        XCTAssertEqual(from.x, 100, accuracy: 6)
        XCTAssertEqual(to.x, 400, accuracy: 6)
        XCTAssertEqual(to.y, 300, accuracy: 6)
    }

    func testHorizontalLineIsUnderline() {
        let points = line(from: CGPoint(x: 100, y: 200), to: CGPoint(x: 400, y: 211))
        guard case let .underline(from, to) = recognizer.recognize(points) else { return XCTFail("expected underline") }
        XCTAssertEqual(from.y, to.y, accuracy: 0.001)
        XCTAssertEqual(from.y, 205.5, accuracy: 6)
        XCTAssertLessThan(from.x, to.x)
    }

    func testRightToLeftUnderlineKeepsDirection() {
        let points = line(from: CGPoint(x: 400, y: 200), to: CGPoint(x: 100, y: 200))
        guard case let .underline(from, to) = recognizer.recognize(points) else { return XCTFail("expected underline") }
        XCTAssertGreaterThan(from.x, to.x)
    }

    func testSlantedLineIsLine() {
        let points = line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 260))
        guard case .line = recognizer.recognize(points) else { return XCTFail("expected line") }
    }

    func testScribbleIsNone() {
        let points = (0...80).map { i in CGPoint(x: 100 + CGFloat(i) * 2, y: 200 + (i % 2 == 0 ? 40 : -40)) }
        XCTAssertEqual(recognizer.recognize(points), .none)
    }

    func testOpenCurveIsNone() {
        let points = (0...60).map { i -> CGPoint in
            let a = Double(i) / 60 * Double.pi
            return CGPoint(x: 200 + 100 * cos(a), y: 200 + 100 * sin(a))
        }
        XCTAssertEqual(recognizer.recognize(points), .none)
    }

    func testEmptySinglePointAndTwoPointInputsReturnNone() {
        XCTAssertEqual(recognizer.recognize([]), .none)
        XCTAssertEqual(recognizer.recognize([CGPoint(x: 5, y: 5)]), .none)
        XCTAssertEqual(recognizer.recognize([CGPoint(x: 5, y: 5), CGPoint(x: 400, y: 5)]), .none)
    }

    func testTinyStrokeAndNonFiniteInputAreNone() {
        let tiny = (0..<20).map { CGPoint(x: 10 + CGFloat($0) * 0.3, y: 10) }
        XCTAssertEqual(recognizer.recognize(tiny), .none)
        let bad = line(from: .zero, to: CGPoint(x: 300, y: 0)) + [CGPoint(x: CGFloat.nan, y: 3)]
        XCTAssertEqual(recognizer.recognize(bad), .none)
    }

    func testShapePolylinesAreResampledToRequestedCount() {
        let shapes: [RecognizedShape] = [
            .ellipse(CGRect(x: 0, y: 0, width: 100, height: 60)),
            .rectangle(CGRect(x: 0, y: 0, width: 100, height: 60)),
            .arrow(from: .zero, to: CGPoint(x: 200, y: 50)),
            .underline(from: .zero, to: CGPoint(x: 200, y: 0)),
            .line(from: .zero, to: CGPoint(x: 200, y: 50)),
        ]
        for shape in shapes {
            XCTAssertEqual(shape.polyline(count: 48, matching: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)])?.count, 48)
        }
        XCTAssertNil(RecognizedShape.none.polyline(count: 48, matching: []))
    }
}

final class PolygonShapeTests: XCTestCase {
    private func ring(_ corners: [CGPoint], perSide: Int = 20, jitter: Double = 1.5) -> [CGPoint] {
        var points: [CGPoint] = []
        for i in 0..<corners.count {
            let a = corners[i], b = corners[(i + 1) % corners.count]
            for k in 0..<perSide {
                let t = CGFloat(k) / CGFloat(perSide)
                let wobble = CGFloat(jitter * sin(Double(points.count) * 1.3))
                points.append(CGPoint(x: a.x + (b.x - a.x) * t + wobble, y: a.y + (b.y - a.y) * t - wobble))
            }
        }
        points.append(corners[0])
        return points
    }

    func testTriangleIsRecognized() {
        let shape = ShapeRecognizer().recognize(ring([CGPoint(x: 200, y: 100), CGPoint(x: 300, y: 260), CGPoint(x: 100, y: 260)]))
        guard case let .triangle(corners) = shape else { return XCTFail("got \(shape)") }
        XCTAssertEqual(corners.count, 3)
        XCTAssertEqual(shape.kind, .triangle)
    }

    func testDiamondIsRecognized() {
        let shape = ShapeRecognizer().recognize(ring([CGPoint(x: 200, y: 100), CGPoint(x: 300, y: 200), CGPoint(x: 200, y: 300), CGPoint(x: 100, y: 200)]))
        XCTAssertEqual(shape.kind, .diamond, "got \(shape)")
    }

    func testRectangleStillWinsOverDiamond() {
        let shape = ShapeRecognizer().recognize(ring([CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 100), CGPoint(x: 300, y: 250), CGPoint(x: 100, y: 250)]))
        XCTAssertEqual(shape.kind, .rectangle, "got \(shape)")
    }

    func testPolygonMorphHasTheRequestedPointCount() {
        let raw = ring([CGPoint(x: 200, y: 100), CGPoint(x: 300, y: 260), CGPoint(x: 100, y: 260)])
        let shape = ShapeRecognizer().recognize(raw)
        XCTAssertEqual(shape.polyline(count: InkModel.morphPointCount, matching: raw)?.count, InkModel.morphPointCount)
    }
}

final class ShapeSetMigrationTests: XCTestCase {
    func testOldEveryShapeValueStillMeansEveryShape() throws {
        let old = try JSONDecoder().decode(InkShapeSet.self, from: Data("31".utf8))
        XCTAssertEqual(old, .all)
        let some = try JSONDecoder().decode(InkShapeSet.self, from: Data("5".utf8))
        XCTAssertEqual(some, [.ellipse, .line])
    }
}
