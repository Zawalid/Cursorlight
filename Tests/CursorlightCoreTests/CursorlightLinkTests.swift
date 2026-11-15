import XCTest
@testable import CursorlightCore

final class CursorlightLinkTests: XCTestCase {
    private func parse(_ s: String) -> CursorlightLinkCommand? { URL(string: s).flatMap(CursorlightLink.parse) }

    func testEffectsToggleOnAndOff() {
        XCTAssertEqual(parse("cursorlight://highlight"), .highlight(.toggle))
        XCTAssertEqual(parse("cursorlight://highlight/on"), .highlight(.on))
        XCTAssertEqual(parse("cursorlight://laser/off"), .laser(.off))
        XCTAssertEqual(parse("cursorlight://ink/toggle"), .ink(.toggle))
        XCTAssertEqual(parse("cursorlight://draw/on"), .ink(.on))
        XCTAssertEqual(parse("CURSORLIGHT://Highlight/ON"), .highlight(.on), "case does not matter")
        XCTAssertNil(parse("cursorlight://highlight/sideways"))
    }

    func testTimerWhiteboardAndClear() {
        XCTAssertEqual(parse("cursorlight://timer/start?minutes=10"), .timerStart(minutes: 10))
        XCTAssertEqual(parse("cursorlight://timer/start"), .timerStart(minutes: nil))
        XCTAssertEqual(parse("cursorlight://timer/start?minutes=99999"), .timerStart(minutes: 600))
        XCTAssertEqual(parse("cursorlight://timer/stop"), .timerStop)
        XCTAssertEqual(parse("cursorlight://whiteboard/black"), .whiteboard(.black))
        XCTAssertEqual(parse("cursorlight://whiteboard/off"), .whiteboard(.none))
        XCTAssertEqual(parse("cursorlight://clear"), .clearInk)
        XCTAssertEqual(parse("cursorlight://undo"), .undoInk)
    }

    func testScenesByNameOrNext() {
        XCTAssertEqual(parse("cursorlight://scene/next"), .nextScene)
        XCTAssertEqual(parse("cursorlight://scene?name=Meeting"), .scene(name: "Meeting"))
        XCTAssertEqual(parse("cursorlight://scene/High%20visibility"), .scene(name: "High visibility"))
        XCTAssertNil(parse("cursorlight://scene"))
    }

    func testPenColorAndTool() {
        XCTAssertEqual(parse("cursorlight://color/blue"), .penColor(.blue))
        XCTAssertEqual(parse("cursorlight://color?name=pink"), .penColor(.pink))
        XCTAssertNil(parse("cursorlight://color/chartreuse"))
        XCTAssertEqual(parse("cursorlight://tool/eraser"), .penTool(.eraser))
        XCTAssertEqual(parse("cursorlight://tool/doubleArrow"), .penTool(.doubleArrow))
    }

    func testRefusesOtherSchemesAndUnknownCommands() {
        XCTAssertNil(parse("https://highlight/on"))
        XCTAssertNil(parse("cursorlight://format-disk"))
        XCTAssertNil(parse("cursorlight://"))
    }

    func testEveryExampleLinkParses() {
        for example in CursorlightLink.examples {
            XCTAssertNotNil(parse(example.link), example.link)
        }
    }
}
