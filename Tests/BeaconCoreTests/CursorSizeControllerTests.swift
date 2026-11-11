import XCTest
@testable import BeaconCore

private final class FakeScaling: CursorScaling {
    var scale: Float?
    var setSucceeds = true
    var setCalls: [Float] = []
    init(scale: Float?) { self.scale = scale }
    func currentScale() -> Float? { scale }
    func setScale(_ value: Float) -> Bool {
        setCalls.append(value)
        guard setSucceeds else { return false }
        scale = value
        return true
    }
}

private final class FakeMarkers: ScaleMarkerStore {
    var originalScale: Float?
}

@MainActor
final class CursorSizeControllerTests: XCTestCase {
    private func make(scale: Float? = 1.0) -> (CursorSizeController, FakeScaling, FakeMarkers) {
        let scaling = FakeScaling(scale: scale)
        let markers = FakeMarkers()
        return (CursorSizeController(scaling: scaling, markers: markers), scaling, markers)
    }

    func testApplyStoresOriginalOnceAndSetsScale() {
        let (controller, scaling, markers) = make(scale: 1.0)
        controller.apply(2)
        XCTAssertEqual(markers.originalScale, 1.0)
        XCTAssertEqual(scaling.scale, 2)
    }

    func testResetRestoresOriginalAndClearsMarker() {
        let (controller, scaling, markers) = make(scale: 1.0)
        controller.apply(3)
        controller.reset()
        XCTAssertEqual(scaling.scale, 1.0)
        XCTAssertNil(markers.originalScale)
    }

    func testApplyTwiceKeepsFirstOriginal() {
        let (controller, _, markers) = make(scale: 1.0)
        controller.apply(2)
        controller.apply(3)
        XCTAssertEqual(markers.originalScale, 1.0)
    }

    func testClampsToHalfAndFour() {
        let (controller, scaling, _) = make()
        controller.apply(10)
        XCTAssertEqual(scaling.scale, 4.0)
        controller.apply(0.1)
        XCTAssertEqual(scaling.scale, 0.5)
    }

    func testNaNIsIgnored() {
        let (controller, scaling, markers) = make()
        controller.apply(.nan)
        controller.apply(0)
        controller.apply(-1)
        XCTAssertTrue(scaling.setCalls.isEmpty)
        XCTAssertNil(markers.originalScale)
    }

    func testRestoreIfStaleRestoresOriginalFromMarker() {
        let (controller, scaling, markers) = make(scale: 3.0)
        markers.originalScale = 1.0
        controller.restoreIfStale()
        XCTAssertEqual(scaling.scale, 1.0)
        XCTAssertNil(markers.originalScale)
    }

    func testFailedSetDoesNotWriteMarker() {
        let (controller, scaling, markers) = make()
        scaling.setSucceeds = false
        controller.apply(2)
        XCTAssertNil(markers.originalScale)
    }

    func testUnreadableScaleDoesNotChangeAnything() {
        let (controller, scaling, markers) = make(scale: nil)
        controller.apply(2)
        XCTAssertTrue(scaling.setCalls.isEmpty)
        XCTAssertNil(markers.originalScale)
    }

    func testUserDefaultsMarkerRoundTrip() throws {
        let suite = "beacon.test.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let marker = UserDefaultsScaleMarker(defaults: defaults)
        XCTAssertNil(marker.originalScale)
        marker.originalScale = 1.5
        XCTAssertEqual(marker.originalScale, 1.5)
        marker.originalScale = nil
        XCTAssertNil(marker.originalScale)
    }
}
