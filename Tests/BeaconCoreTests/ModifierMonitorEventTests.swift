import AppKit
import XCTest
@testable import BeaconCore

final class ModifierMonitorEventTests: XCTestCase {
    /// Regression: reading keyCode on a mouse event raised an NSException inside the monitor, which made every click in
    /// Beacon's own windows do nothing.
    func testSnapshotOfAMouseEventDoesNotRaise() throws {
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 1, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1
        ))
        let snapshot = ModifierGestureMonitor.Snapshot(event)
        XCTAssertEqual(snapshot.type, .leftMouseDown)
        XCTAssertEqual(snapshot.keyCode, 0)
    }

    func testSnapshotOfAScrollAndKeyEventKeepsWhatItShould() throws {
        let key = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1, windowNumber: 0, context: nil,
            characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0
        ))
        XCTAssertEqual(ModifierGestureMonitor.Snapshot(key).type, .keyDown)
    }
}
