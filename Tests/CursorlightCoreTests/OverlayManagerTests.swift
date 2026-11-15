import AppKit
import XCTest
@testable import CursorlightCore

@MainActor
private final class FakeScreens: ScreenProviding {
    var displayIDs: [CGDirectDisplayID]
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    init(_ ids: [CGDirectDisplayID]) { displayIDs = ids }

    var changes: AsyncStream<Void> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    func frame(for displayID: CGDirectDisplayID) -> CGRect? {
        displayID == 99 ? nil : CGRect(x: 0, y: 0, width: 800, height: 600)
    }

    func notifyChange() { for continuation in continuations.values { continuation.yield() } }
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
        XCTAssertEqual(removed?.closeCount, 1)
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
        XCTAssertEqual(before.count, 2)
        XCTAssertTrue(before.allSatisfy { $0.closeCount == 1 }, "stale windows must be closed")
    }

    func testStopThenStartStillHandlesDisplayChanges() async {
        let screens = FakeScreens([1, 2])
        let manager = OverlayManager(screens: screens)
        manager.start()
        manager.stop()
        XCTAssertTrue(manager.windows.isEmpty)
        manager.start()
        defer { manager.stop() }
        XCTAssertEqual(manager.windows.count, 2)
        screens.displayIDs = [1, 2, 3]
        screens.notifyChange()
        await waitUntil { manager.windows.count == 3 }
        XCTAssertEqual(Set(manager.windows.keys), [1, 2, 3])
    }

    func testSkipsDisplayWithUnknownFrame() {
        let manager = OverlayManager(screens: FakeScreens([1, 99]))
        manager.start()
        defer { manager.stop() }
        XCTAssertEqual(Set(manager.windows.keys), [1])
    }
}
