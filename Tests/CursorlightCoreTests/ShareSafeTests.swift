import XCTest
@testable import CursorlightCore

final class ShareSafeTests: XCTestCase {
    private let zoom = ConferencingApp(bundleID: "us.zoom.xos", name: "Zoom")

    func testSingleWindowWarns() {
        XCTAssertEqual(ShareSafe.status(declared: .singleWindow, running: []), .warnSingleWindow)
        XCTAssertTrue(ShareSafe.status(declared: .singleWindow, running: []).needsAttention)
    }

    func testWholeScreenIsOkOnlyWhenDeclared() {
        XCTAssertEqual(ShareSafe.status(declared: .wholeScreen, running: []), .ok)
        XCTAssertNotEqual(ShareSafe.status(declared: nil, running: [zoom]), .ok)
        XCTAssertNotEqual(ShareSafe.status(declared: nil, running: []), .ok)
    }

    func testUndeclaredWithConferencingAppRemindsWithItsName() {
        XCTAssertEqual(ShareSafe.status(declared: nil, running: [zoom]), .reminder(app: "Zoom"))
        XCTAssertTrue(ShareSafe.status(declared: nil, running: [zoom]).needsAttention)
    }

    func testNothingRunningAndNothingDeclaredIsIdle() {
        XCTAssertEqual(ShareSafe.status(declared: nil, running: []), .idle)
        XCTAssertEqual(ShareSafe.status(declared: .notSharing, running: [zoom]), .notSharing)
    }

    func testBrowsersAndChatAppsAreNotListed() {
        XCTAssertNil(ShareSafe.conferencingApp(for: "com.google.Chrome"))
        XCTAssertNil(ShareSafe.conferencingApp(for: "com.tinyspeck.slackmacgap"))
        XCTAssertEqual(ShareSafe.conferencingApp(for: "us.zoom.xos")?.name, "Zoom")
    }
}

@MainActor
final class ShareSafeMonitorTests: XCTestCase {
    func testMonitorFindsRunningAppsAndDedupesByName() {
        var ids = ["com.apple.finder", "com.microsoft.teams2", "com.microsoft.teams"]
        let monitor = ShareSafeMonitor(runningBundleIDs: { ids })
        XCTAssertEqual(monitor.running.map(\.name), ["Microsoft Teams"])
        XCTAssertEqual(monitor.status, .reminder(app: "Microsoft Teams"))
        ids = []
        monitor.refresh()
        XCTAssertEqual(monitor.status, .idle)
    }

    func testDeclarationIsDroppedWhenTheLastConferencingAppQuits() {
        var ids = ["us.zoom.xos"]
        let monitor = ShareSafeMonitor(runningBundleIDs: { ids })
        monitor.declare(.wholeScreen)
        XCTAssertEqual(monitor.status, .ok)
        ids = []
        monitor.refresh()
        XCTAssertNil(monitor.declared)
        XCTAssertEqual(monitor.status, .idle)
    }

    func testDeclarationSurvivesWhenNoAppWasEverDetected() {
        let monitor = ShareSafeMonitor(runningBundleIDs: { [] })
        monitor.declare(.singleWindow)
        monitor.refresh()
        XCTAssertEqual(monitor.status, .warnSingleWindow)
    }

    func testOnChangeFiresOnlyForRealChanges() {
        let monitor = ShareSafeMonitor(runningBundleIDs: { [] })
        var calls = 0
        monitor.onChange = { calls += 1 }
        monitor.declare(.wholeScreen)
        monitor.declare(.wholeScreen)
        monitor.refresh()
        XCTAssertEqual(calls, 1)
    }
}
