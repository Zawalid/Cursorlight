import AppKit
import XCTest
import os

@testable import BeaconCore

/// In-memory stand-in for the persisted `cursorHidden` marker.
final class InMemoryCursorMarker: CursorHiddenMarkerStore {
    private let value: OSAllocatedUnfairLock<Bool>
    init(_ initial: Bool = false) { value = OSAllocatedUnfairLock(initialState: initial) }
    var isCursorHidden: Bool {
        get { value.withLock { $0 } }
        set { value.withLock { $0 = newValue } }
    }
}

/// Records every call the hider makes to the system, in order.
final class FakeCursorBackend: CursorVisibilityBackend {
    enum Call: Equatable { case allow, hide, show }
    private let log = OSAllocatedUnfairLock<[Call]>(initialState: [])
    private let allows: Bool
    init(allows: Bool = true) { self.allows = allows }
    var calls: [Call] { log.withLock { $0 } }
    func allowBackgroundCursorControl() -> Bool {
        log.withLock { $0.append(.allow) }
        return allows
    }
    func hideCursor() { log.withLock { $0.append(.hide) } }
    func showCursor() { log.withLock { $0.append(.show) } }
}

/// A hider that only records what it was asked to do.
final class RecordingHider: CursorHider {
    enum Call: Equatable { case hide, restore }
    private let state = OSAllocatedUnfairLock<(calls: [Call], hidden: Bool)>(initialState: ([], false))
    var calls: [Call] { state.withLock { $0.calls } }
    var restoreCount: Int { calls.filter { $0 == .restore }.count }
    var isHidden: Bool { state.withLock { $0.hidden } }
    func hide() { state.withLock { $0.calls.append(.hide); $0.hidden = true } }
    func restore() { state.withLock { $0.calls.append(.restore); $0.hidden = false } }
}

@MainActor
final class CursorHiderTests: XCTestCase {
    func testEachHideIsPairedWithExactlyOneShow() {
        let backend = FakeCursorBackend()
        let hider = SystemCursorHider(backend: backend, markers: InMemoryCursorMarker())
        hider.hide()
        hider.hide()
        XCTAssertTrue(hider.isHidden)
        hider.restore()
        hider.restore()
        XCTAssertFalse(hider.isHidden)
        let hides = backend.calls.filter { $0 == .hide }.count
        let shows = backend.calls.filter { $0 == .show }.count
        XCTAssertEqual(hides, 1)
        XCTAssertEqual(shows, hides)
    }

    func testNeverHidesWithoutTheBackgroundProperty() {
        let backend = FakeCursorBackend(allows: false)
        let markers = InMemoryCursorMarker()
        let hider = SystemCursorHider(backend: backend, markers: markers)
        hider.hide()
        XCTAssertEqual(backend.calls, [.allow])
        XCTAssertFalse(hider.isHidden)
        XCTAssertFalse(markers.isCursorHidden)
        hider.restore()
        XCTAssertFalse(backend.calls.contains(.show))
    }

    func testPropertyIsSetBeforeEveryHide() {
        let backend = FakeCursorBackend()
        let hider = SystemCursorHider(backend: backend, markers: InMemoryCursorMarker())
        hider.hide()
        hider.restore()
        hider.hide()
        hider.restore()
        XCTAssertEqual(backend.calls, [.allow, .hide, .show, .allow, .hide, .show])
    }

    func testMarkerIsSetOnHideAndClearedOnRestore() {
        let markers = InMemoryCursorMarker()
        let hider = SystemCursorHider(backend: FakeCursorBackend(), markers: markers)
        hider.hide()
        XCTAssertTrue(markers.isCursorHidden)
        hider.restore()
        XCTAssertFalse(markers.isCursorHidden)
    }

    func testStaleHiddenFlagRestoredOnRelaunch() {
        // A previous run died while hidden and left the marker behind.
        let markers = InMemoryCursorMarker(true)
        let hider = RecordingHider()
        let restored = CursorRecovery.restoreIfStale(markers: markers, hider: hider)
        XCTAssertTrue(restored)
        XCTAssertEqual(hider.calls, [.restore], "restore() must be the first and only call")
        XCTAssertFalse(markers.isCursorHidden)

        // No marker: nothing is touched.
        let clean = RecordingHider()
        XCTAssertFalse(CursorRecovery.restoreIfStale(markers: InMemoryCursorMarker(false), hider: clean))
        XCTAssertEqual(clean.calls, [])
    }

    func testStaleRecoveryNeverIssuesAnUnbalancedShow() {
        // The new process owns no hide, so the system hider must not call show (which would unbalance the count).
        let markers = InMemoryCursorMarker(true)
        let backend = FakeCursorBackend()
        let hider = SystemCursorHider(backend: backend, markers: markers)
        CursorRecovery.restoreIfStale(markers: markers, hider: hider)
        XCTAssertEqual(backend.calls, [])
        XCTAssertFalse(markers.isCursorHidden)
    }

    func testFallbackHiderNeverHides() {
        let hider = FallbackCursorHider()
        hider.hide()
        XCTAssertFalse(hider.isHidden)
        hider.restore()
        XCTAssertFalse(hider.isHidden)
    }

    func testUserDefaultsMarkerUsesCursorHiddenKey() throws {
        let suite = "beacon.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let marker = UserDefaultsCursorMarker(suiteName: suite)
        marker.isCursorHidden = true
        XCTAssertTrue(defaults.bool(forKey: "cursorHidden"))
        marker.isCursorHidden = false
        XCTAssertFalse(defaults.bool(forKey: "cursorHidden"))
    }

    func testRestoreIsCalledOnStopAndOnDeinit() {
        let hider = RecordingHider()
        let tracker = CursorTracker()
        let overlays = OverlayManager(screens: TestScreens([1]))
        overlays.start()
        defer { overlays.stop() }
        let skin = BuiltInSkins.all[0]

        let renderer = SkinRenderer(hider: hider, tracker: tracker, overlays: overlays, detector: FixedKindDetector())
        renderer.apply(skin, sizeMultiplier: 1)
        XCTAssertEqual(hider.calls, [.hide])
        renderer.stop()
        XCTAssertEqual(hider.calls, [.hide, .restore])

        let deinitHider = RecordingHider()
        var scoped: SkinRenderer? = SkinRenderer(
            hider: deinitHider, tracker: tracker, overlays: overlays, detector: FixedKindDetector()
        )
        scoped?.apply(skin, sizeMultiplier: 1)
        XCTAssertEqual(deinitHider.calls, [.hide])
        scoped = nil
        XCTAssertNil(scoped)
        XCTAssertEqual(deinitHider.calls, [.hide, .restore])
    }
}
