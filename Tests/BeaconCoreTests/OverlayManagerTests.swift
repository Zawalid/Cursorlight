import AppKit
import XCTest
@testable import BeaconCore

@MainActor
private final class FakeScreens: ScreenProviding {
    var displayIDs: [CGDirectDisplayID]
    let changes: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init(_ ids: [CGDirectDisplayID]) {
        displayIDs = ids
        (changes, continuation) = AsyncStream<Void>.makeStream()
    }

    func notifyChange() { continuation.yield() }
}

@MainActor
final class OverlayManagerTests: XCTestCase {
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testCreatesOneWindowPerDisplay() {
        let manager = OverlayManager(screens: FakeScreens([1, 2]))
        manager.start()
        defer { manager.stop() }
        XCTAssertEqual(Set(manager.windows.keys), [1, 2])
        for window in manager.windows.values {
            XCTAssertTrue(window.ignoresMouseEvents)
            XCTAssertEqual(window.level, .screenSaver)
            XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
            XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
            XCTAssertTrue(window.collectionBehavior.contains(.stationary))
        }
    }

    func testRemovesWindowWhenDisplayUnplugged() async {
        let screens = FakeScreens([1, 2])
        let manager = OverlayManager(screens: screens)
        manager.start()
        defer { manager.stop() }
        let removed = manager.windows[2]
        screens.displayIDs = [1]
        screens.notifyChange()
        await waitUntil { manager.windows.count == 1 }
        XCTAssertEqual(Set(manager.windows.keys), [1])
        XCTAssertNotNil(removed)
        XCTAssertFalse(removed?.isVisible ?? true)
    }

    func testRebuildOnSleepWakeLeavesNoOrphans() async {
        let screens = FakeScreens([1, 2])
        let manager = OverlayManager(screens: screens)
        manager.start()
        defer { manager.stop() }
        let before = Array(manager.windows.values)
        screens.displayIDs = [1]
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        await waitUntil { manager.windows.count == 1 }
        XCTAssertEqual(manager.windows.count, screens.displayIDs.count)
        XCTAssertEqual(Set(manager.windows.keys), [1])
        XCTAssertTrue(before.allSatisfy { !$0.isVisible }, "stale windows must be closed")
    }
}
