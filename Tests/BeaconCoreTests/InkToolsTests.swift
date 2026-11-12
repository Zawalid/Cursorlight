import XCTest
@testable import BeaconCore

final class InkToolsTests: XCTestCase {
    private func line(_ model: inout InkModel, from a: CGPoint, to b: CGPoint) {
        model.begin(at: a, style: .marker, color: .red)
        for i in 1...10 {
            let t = CGFloat(i) / 10
            model.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        model.end(at: 1)
    }

    func testNumberStampsCountUpAndUndoStepsBack() {
        var m = InkModel()
        m.placeStamp(.number, at: CGPoint(x: 10, y: 10), color: .red, customColor: nil, time: 0)
        m.placeStamp(.number, at: CGPoint(x: 50, y: 10), color: .red, customColor: nil, time: 0)
        m.placeStamp(.check, at: CGPoint(x: 90, y: 10), color: .red, customColor: nil, time: 0)
        let numbers = m.step(time: 0).strokes.compactMap { frame -> Int? in
            if case let .stamp(.number, n) = frame.kind { return n }
            return nil
        }
        XCTAssertEqual(numbers, [1, 2])
        m.undo()
        m.undo()
        m.placeStamp(.number, at: .zero, color: .red, customColor: nil, time: 0)
        if case let .stamp(.number, n) = m.step(time: 0).strokes.last?.kind { XCTAssertEqual(n, 2) } else { XCTFail("no stamp") }
    }

    func testClearRestartsTheCount() {
        var m = InkModel()
        m.placeStamp(.number, at: .zero, color: .red, customColor: nil, time: 0)
        m.clear(at: 0)
        m.placeStamp(.number, at: .zero, color: .red, customColor: nil, time: 1)
        if case let .stamp(.number, n) = m.step(time: 1).strokes.last?.kind { XCTAssertEqual(n, 1) } else { XCTFail("no stamp") }
    }

    func testBoxIsDraggedFromTwoCornersAndATinyDragIsDropped() {
        var m = InkModel()
        m.begin(at: CGPoint(x: 100, y: 100), style: .marker, color: .red, kind: .filledBox)
        m.append(CGPoint(x: 220, y: 180))
        m.append(CGPoint(x: 300, y: 260))
        m.end(at: 1)
        XCTAssertEqual(m.step(time: 1).strokes.first?.points, [CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 260)])
        var tiny = InkModel()
        tiny.begin(at: CGPoint(x: 100, y: 100), style: .marker, color: .red, kind: .arrow)
        tiny.append(CGPoint(x: 103, y: 102))
        tiny.end(at: 1)
        XCTAssertEqual(tiny.strokeCount, 0)
    }

    func testBoxesAreNotCleanedUpIntoShapes() {
        var m = InkModel()
        m.begin(at: CGPoint(x: 100, y: 100), style: .marker, color: .red, kind: .arrow)
        m.append(CGPoint(x: 300, y: 100))
        m.end(at: 1)
        XCTAssertEqual(m.step(time: 1.1).strokes.first?.points.count, 2)
    }

    func testCoverNeverFades() {
        var m = InkModel()
        m.begin(at: .zero, style: .marker, color: .red, kind: .redact)
        m.append(CGPoint(x: 200, y: 100))
        m.end(at: 1)
        XCTAssertEqual(m.step(time: 500).strokes.first?.alpha, 1)
        line(&m, from: .zero, to: CGPoint(x: 200, y: 0))
        XCTAssertEqual(m.step(time: 500).strokes.count, 1, "the pen line faded away, the cover stayed")
    }

    func testEraserRemovesWhatItTouches() {
        var m = InkModel()
        line(&m, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 200, y: 0))
        line(&m, from: CGPoint(x: 0, y: 100), to: CGPoint(x: 200, y: 100))
        XCTAssertFalse(m.erase(at: CGPoint(x: 100, y: 50), radius: 16))
        XCTAssertTrue(m.erase(at: CGPoint(x: 100, y: 6), radius: 16))
        XCTAssertEqual(m.strokeCount, 1)
        m.placeText("Hello", at: CGPoint(x: 300, y: 300), color: .red, customColor: nil, time: 1)
        XCTAssertTrue(m.erase(at: CGPoint(x: 320, y: 310), radius: 16))
    }

    func testStraightenTurnsTheStrokeIntoALine() {
        var m = InkModel()
        m.begin(at: CGPoint(x: 0, y: 0), style: .marker, color: .red)
        m.append(CGPoint(x: 30, y: 40)); m.append(CGPoint(x: 60, y: 10))
        m.straighten(to: CGPoint(x: 120, y: 0))
        XCTAssertEqual(m.step(time: 0).strokes.first?.points, [CGPoint(x: 0, y: 0), CGPoint(x: 120, y: 0)])
    }

    func testEmptyTextIsNotPlaced() {
        var m = InkModel()
        m.placeText("   ", at: .zero, color: .red, customColor: nil, time: 0)
        XCTAssertEqual(m.strokeCount, 0)
    }

    func testToolKeysAreUnique() {
        XCTAssertEqual(Set(InkTool.allCases.map(\.key)).count, InkTool.allCases.count)
        XCTAssertFalse(InkTool.allCases.map(\.key).contains("c"), "c clears everything")
    }
}

final class WhiteboardShortcutTests: XCTestCase {
    func testWhiteboardShortcutExistsAndRoutes() {
        XCTAssertEqual(TriggerSettings().hotkey(for: .whiteboard)?.displayString, "⌃⌥W")
        XCTAssertEqual(TriggerRouter(settings: TriggerSettings()).route(.hotkey(.whiteboard), active: .init()), [.whiteboard])
        XCTAssertEqual(InkBoard.none.next, .white)
        XCTAssertEqual(InkBoard.black.next, .none)
    }
}

final class CurvedArrowAndBubbleTests: XCTestCase {
    func testCurvedArrowBendsAwayFromTheStraightLine() {
        let a = CGPoint(x: 0, y: 0), b = CGPoint(x: 200, y: 0)
        let mid = InkCurve.point(from: a, to: b, at: 0.5)
        XCTAssertEqual(mid.x, 100, accuracy: 0.001)
        XCTAssertGreaterThan(abs(mid.y), 20, "it bulges to one side")
        XCTAssertEqual(InkCurve.point(from: a, to: b, at: 0), a)
        XCTAssertEqual(InkCurve.point(from: a, to: b, at: 1).x, 200, accuracy: 0.001)
    }

    func testCurvedArrowIsDraggedAndErasedAlongItsCurve() {
        var m = InkModel()
        m.begin(at: CGPoint(x: 0, y: 0), style: .marker, color: .red, kind: .curvedArrow)
        m.append(CGPoint(x: 200, y: 0))
        m.end(at: 1)
        XCTAssertEqual(m.strokeCount, 1)
        XCTAssertFalse(m.erase(at: CGPoint(x: 100, y: 0), radius: 10), "the straight chord is not on the curve")
        let onCurve = InkCurve.point(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 200, y: 0), at: 0.5)
        XCTAssertTrue(m.erase(at: onCurve, radius: 10))
    }

    func testToolsAndStampsIncludeTheNewOnes() {
        XCTAssertEqual(InkTool.curvedArrow.key, "v")
        XCTAssertEqual(Set(InkTool.allCases.map(\.key)).count, InkTool.allCases.count)
        XCTAssertTrue(StampKind.allCases.contains(.bubble))
        var m = InkModel()
        m.placeStamp(.bubble, at: .zero, color: .red, customColor: nil, time: 0)
        XCTAssertEqual(m.strokeCount, 1)
    }
}
