import AppKit
import XCTest

@testable import CursorlightCore

@MainActor
private final class FakeLink: FrameLink {
    var isPaused = false
    private(set) var invalidated = false
    let tick: @MainActor (TimeInterval) -> Void

    init(tick: @escaping @MainActor (TimeInterval) -> Void) { self.tick = tick }

    func invalidate() { invalidated = true }
}

final class HostPlanTests: XCTestCase {
    func testPlanRemovesGoneAndAddsNew() {
        let plan = HostPlan.plan(existing: Set([1, 2, 3]), current: Set([2, 3, 4]))
        XCTAssertEqual(plan.remove, [1])
        XCTAssertEqual(plan.add, [4])
        let same = HostPlan.plan(existing: Set([1, 2]), current: Set([1, 2]))
        XCTAssertTrue(same.remove.isEmpty && same.add.isEmpty)
    }
}

@MainActor
final class HighlightControllerTests: XCTestCase {
    private var windows: [OverlayWindow] = []
    private var links: [ObjectIdentifier: FakeLink] = [:]
    private var now: TimeInterval = 100

    override func tearDown() async throws {
        for window in windows { window.close() }
        windows = []
        links = [:]
    }

    private func makeController() -> HighlightController {
        HighlightController(
            windows: { [unowned self] in self.windows }, style: .aura, ripplesEnabled: true,
            pointer: { CGPoint(x: 50, y: 50) }, clock: { [unowned self] in self.now },
            makeLink: { [unowned self] window, tick in
                let link = FakeLink(tick: tick)
                self.links[ObjectIdentifier(window)] = link
                return link
            }
        )
    }

    private func runFrames(until end: TimeInterval) {
        while now < end {
            now += 1.0 / 60
            for link in links.values where !link.isPaused && !link.invalidated { link.tick(now) }
        }
    }

    func testLinkLifecycleFollowsActivityAndWindows() {
        let first = OverlayWindow(displayID: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        windows = [first]
        let controller = makeController()
        controller.start()
        defer { controller.stop() }
        XCTAssertEqual(controller.hostCount, 1)
        runFrames(until: 101)
        let link = links[ObjectIdentifier(first)]
        XCTAssertEqual(link?.isPaused, true, "nothing moves: the link sleeps")

        controller.setOn(true)
        XCTAssertEqual(link?.isPaused, false, "turning on wakes the link")
        runFrames(until: 112)
        XCTAssertEqual(link?.isPaused, true, "at rest after the entrance and breathing")
        XCTAssertTrue(controller.isOn)

        controller.setOn(false)
        XCTAssertEqual(link?.isPaused, false)
        runFrames(until: 113)
        XCTAssertEqual(link?.isPaused, true, "paused once the exit completed")

        // The overlay manager rebuilt its windows: the old host goes, the new one is drawn at once.
        controller.setOn(true)
        runFrames(until: 120)
        let second = OverlayWindow(displayID: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        windows = [second]
        controller.windowsChanged()
        XCTAssertEqual(link?.invalidated, true, "the closed window's link is invalidated")
        XCTAssertTrue(first.rootLayer.sublayers?.isEmpty ?? true, "its layers are removed")
        XCTAssertEqual(controller.hostCount, 1)
        let drawn = second.rootLayer.sublayers ?? []
        XCTAssertFalse(drawn.isEmpty, "the new window hosts the highlight")
        XCTAssertTrue(drawn.contains { $0.sublayers?.contains { !$0.isHidden && ($0.sublayers?.isEmpty == false) } == true },
                      "drawn immediately, without a mouse move")
    }

    func testSleepPausesAndWakeResumes() {
        let window = OverlayWindow(displayID: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        windows = [window]
        let controller = makeController()
        controller.start()
        defer { controller.stop() }
        controller.setOn(true)
        let link = links[ObjectIdentifier(window)]
        XCTAssertEqual(link?.isPaused, false)
        controller.systemWillSleep()
        XCTAssertEqual(link?.isPaused, true)
        controller.pointerMoved()
        XCTAssertEqual(link?.isPaused, true, "input does not wake links while asleep")
        controller.systemDidWake()
        XCTAssertEqual(link?.isPaused, false)
    }

    func testStopInvalidatesEveryLink() {
        windows = [
            OverlayWindow(displayID: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600)),
            OverlayWindow(displayID: 2, frame: CGRect(x: 800, y: 0, width: 800, height: 600)),
        ]
        let controller = makeController()
        controller.start()
        XCTAssertEqual(links.count, 2)
        controller.stop()
        XCTAssertTrue(links.values.allSatisfy(\.invalidated))
        XCTAssertEqual(controller.hostCount, 0)
    }

    func testOverlayManagerAnnouncesRebuilds() {
        let manager = OverlayManager(screens: SystemScreens())
        var count = 0
        manager.onWindowsChanged = { count += 1 }
        manager.rebuild()
        XCTAssertEqual(count, 1)
        manager.stop()
        XCTAssertEqual(count, 2)
    }
}
