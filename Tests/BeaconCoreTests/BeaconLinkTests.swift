import XCTest
@testable import BeaconCore

final class BeaconLinkTests: XCTestCase {
    private func parse(_ s: String) -> BeaconLinkCommand? { URL(string: s).flatMap(BeaconLink.parse) }

    func testEffectsToggleOnAndOff() {
        XCTAssertEqual(parse("beacon://highlight"), .highlight(.toggle))
        XCTAssertEqual(parse("beacon://highlight/on"), .highlight(.on))
        XCTAssertEqual(parse("beacon://laser/off"), .laser(.off))
        XCTAssertEqual(parse("beacon://ink/toggle"), .ink(.toggle))
        XCTAssertEqual(parse("beacon://draw/on"), .ink(.on))
        XCTAssertEqual(parse("BEACON://Highlight/ON"), .highlight(.on), "case does not matter")
        XCTAssertNil(parse("beacon://highlight/sideways"))
    }

    func testTimerWhiteboardAndClear() {
        XCTAssertEqual(parse("beacon://timer/start?minutes=10"), .timerStart(minutes: 10))
        XCTAssertEqual(parse("beacon://timer/start"), .timerStart(minutes: nil))
        XCTAssertEqual(parse("beacon://timer/start?minutes=99999"), .timerStart(minutes: 600))
        XCTAssertEqual(parse("beacon://timer/stop"), .timerStop)
        XCTAssertEqual(parse("beacon://whiteboard/black"), .whiteboard(.black))
        XCTAssertEqual(parse("beacon://whiteboard/off"), .whiteboard(.none))
        XCTAssertEqual(parse("beacon://clear"), .clearInk)
        XCTAssertEqual(parse("beacon://undo"), .undoInk)
    }

    func testScenesByNameOrNext() {
        XCTAssertEqual(parse("beacon://scene/next"), .nextScene)
        XCTAssertEqual(parse("beacon://scene?name=Meeting"), .scene(name: "Meeting"))
        XCTAssertEqual(parse("beacon://scene/High%20visibility"), .scene(name: "High visibility"))
        XCTAssertNil(parse("beacon://scene"))
    }

    func testPenColorAndTool() {
        XCTAssertEqual(parse("beacon://color/blue"), .penColor(.blue))
        XCTAssertEqual(parse("beacon://color?name=pink"), .penColor(.pink))
        XCTAssertNil(parse("beacon://color/chartreuse"))
        XCTAssertEqual(parse("beacon://tool/eraser"), .penTool(.eraser))
        XCTAssertEqual(parse("beacon://tool/doubleArrow"), .penTool(.doubleArrow))
    }

    func testRefusesOtherSchemesAndUnknownCommands() {
        XCTAssertNil(parse("https://highlight/on"))
        XCTAssertNil(parse("beacon://format-disk"))
        XCTAssertNil(parse("beacon://"))
    }

    func testEveryExampleLinkParses() {
        for example in BeaconLink.examples {
            XCTAssertNotNil(parse(example.link), example.link)
        }
    }
}
