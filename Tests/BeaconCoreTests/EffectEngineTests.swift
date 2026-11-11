import AppKit
import XCTest

@testable import BeaconCore

@MainActor
private final class FakeEffect: Effect {
    let id: EffectID
    var onFinish: (() -> Void)?
    private(set) var activations = 0
    private(set) var deactivations = 0
    private(set) var themes: [Theme] = []
    private(set) var moves: [CGPoint?] = []
    private(set) var window: OverlayWindow?

    init(id: EffectID) { self.id = id }

    func activate(on window: OverlayWindow, tracker: CursorTracker) {
        activations += 1
        self.window = window
    }

    func deactivate() { deactivations += 1 }
    func apply(theme: Theme) { themes.append(theme) }
    func pointerMoved(to layerPoint: CGPoint?, at time: TimeInterval) { moves.append(layerPoint) }
}

@MainActor
final class EffectEngineTests: XCTestCase {
    private var made: [FakeEffect] = []
    private var windows: [OverlayWindow] = []

    override func tearDown() async throws {
        for window in windows { window.close() }
        windows = []
        made = []
    }

    private func makeEngine(frames: [CGDirectDisplayID: CGRect]) -> EffectEngine {
        windows = frames.sorted { $0.key < $1.key }.map { OverlayWindow(displayID: $0.key, frame: $0.value) }
        let list = windows
        return EffectEngine(tracker: CursorTracker(), windows: { list }) { [weak self] id in
            let effect = FakeEffect(id: id)
            self?.made.append(effect)
            return effect
        }
    }

    func testActivatingBeaconTwiceIsIdempotent() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        engine.activate(.beacon)
        engine.activate(.beacon)
        XCTAssertEqual(engine.active, [.beacon])
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(made.first?.activations, 1)
    }

    func testDeactivateAllClearsActive() {
        let engine = makeEngine(frames: [
            1: CGRect(x: 0, y: 0, width: 800, height: 600),
            2: CGRect(x: 800, y: 0, width: 800, height: 600),
        ])
        engine.activate(.beacon)
        engine.activate(.laser)
        XCTAssertEqual(engine.active, [.beacon, .laser])
        XCTAssertEqual(made.count, 4, "one instance per effect per display")
        engine.deactivateAll()
        XCTAssertTrue(engine.active.isEmpty)
        XCTAssertTrue(made.allSatisfy { $0.deactivations == 1 })
    }

    func testThemeChangeAppliesToActiveEffects() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        engine.activate(.beacon)
        XCTAssertEqual(made.first?.themes.last, .neon)
        engine.theme = .spotlight
        XCTAssertEqual(made.first?.themes.last, .spotlight)
        engine.deactivate(.beacon)
        engine.theme = .ink
        XCTAssertEqual(made.first?.themes.last, .spotlight, "inactive effects are not touched")
    }

    func testDeactivateOneLeavesOthers() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        engine.activate(.beacon)
        engine.activate(.pulse)
        engine.deactivate(.beacon)
        XCTAssertEqual(engine.active, [.pulse])
    }

    func testFinishedEffectLeavesActiveSet() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        engine.activate(.beacon)
        made.first?.onFinish?()
        XCTAssertTrue(engine.active.isEmpty)
        XCTAssertEqual(made.first?.deactivations, 1)
    }

    func testPointerIsRoutedOnlyToTheDisplayItIsOn() {
        // Display 1 is a 1x screen at the origin, display 2 a 2x screen to its left, offset vertically.
        let engine = makeEngine(frames: [
            1: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            2: CGRect(x: -1512, y: 200, width: 1512, height: 982),
        ])
        engine.activate(.beacon)
        let first = made.first { $0.window?.displayID == 1 }
        let second = made.first { $0.window?.displayID == 2 }

        engine.pointerMoved(to: CGPoint(x: -500, y: 700), at: 1)
        XCTAssertEqual(second?.moves.last, CGPoint(x: 1012, y: 500))
        XCTAssertEqual(first?.moves.last, .some(nil), "the display without the pointer hides its effect")

        engine.pointerMoved(to: CGPoint(x: 100, y: 50), at: 2)
        XCTAssertEqual(first?.moves.last, CGPoint(x: 100, y: 50))
        XCTAssertEqual(second?.moves.last, .some(nil))
    }

    func testUnavailableEffectIsNotMarkedActive() {
        windows = [OverlayWindow(displayID: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600))]
        let list = windows
        let engine = EffectEngine(tracker: CursorTracker(), windows: { list }) { _ in nil }
        engine.activate(.ink)
        XCTAssertTrue(engine.active.isEmpty)
    }

    func testDimIsClamped() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        XCTAssertEqual(engine.beaconDim, 0.25)
        engine.beaconDim = 0.9
        XCTAssertEqual(engine.beaconDim, 0.6)
        engine.beaconDim = -1
        XCTAssertEqual(engine.beaconDim, 0)
    }

    func testThemesAreDistinctAndLookedUpById() {
        let all = Theme.all
        XCTAssertEqual(all.map(\.id), ["neon", "ink", "spotlight", "minimal"])
        XCTAssertEqual(Set(all.map(\.name)).count, 4)
        XCTAssertEqual(Theme.named("ink"), .ink)
        XCTAssertNil(Theme.named("nope"))
        XCTAssertTrue(all.allSatisfy { (0...1).contains($0.glow) })
    }
}

final class PointerGeometryTests: XCTestCase {
    private let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let retinaLeft = CGRect(x: -1512, y: 200, width: 1512, height: 982)
    private let above = CGRect(x: 0, y: 1080, width: 2560, height: 1440)

    func testLayerPointIsScreenPointRelativeToWindowOrigin() {
        XCTAssertEqual(PointerGeometry.layerPoint(for: CGPoint(x: 300, y: 200), windowFrame: main), CGPoint(x: 300, y: 200))
        XCTAssertEqual(
            PointerGeometry.layerPoint(for: CGPoint(x: -1000.5, y: 250.25), windowFrame: retinaLeft),
            CGPoint(x: 511.5, y: 50.25),
            "points, not pixels: the 2x backing scale is applied by Core Animation"
        )
        XCTAssertEqual(PointerGeometry.layerPoint(for: CGPoint(x: 10, y: 2000), windowFrame: above), CGPoint(x: 10, y: 920))
    }

    func testOwnerIsTheDisplayContainingThePoint() {
        let frames: [CGDirectDisplayID: CGRect] = [1: main, 2: retinaLeft, 3: above]
        XCTAssertEqual(PointerGeometry.owner(of: CGPoint(x: 5, y: 5), in: frames), 1)
        XCTAssertEqual(PointerGeometry.owner(of: CGPoint(x: -5, y: 500), in: frames), 2)
        XCTAssertEqual(PointerGeometry.owner(of: CGPoint(x: 100, y: 1500), in: frames), 3)
    }

    func testSharedEdgeBelongsToExactlyOneDisplay() {
        let frames: [CGDirectDisplayID: CGRect] = [1: main, 2: retinaLeft, 3: above]
        // x == 0 is the left edge of main and the right edge of the left display: half-open gives it to main.
        XCTAssertEqual(PointerGeometry.owner(of: CGPoint(x: 0, y: 500), in: frames), 1)
        // y == 1080 is the top of main and the bottom of the display above.
        XCTAssertEqual(PointerGeometry.owner(of: CGPoint(x: 100, y: 1080), in: frames), 3)
    }

    func testTopRowOfTopmostDisplayStillHasAnOwner() {
        // NSEvent.mouseLocation reports y == maxY on the top pixel row.
        XCTAssertEqual(PointerGeometry.owner(of: CGPoint(x: 100, y: 1080), in: [1: main]), 1)
        XCTAssertEqual(PointerGeometry.owner(of: CGPoint(x: 1920, y: 500), in: [1: main]), 1)
    }

    func testPointOutsideEveryDisplayGoesToTheNearest() {
        let frames: [CGDirectDisplayID: CGRect] = [1: main, 2: retinaLeft]
        XCTAssertEqual(PointerGeometry.owner(of: CGPoint(x: -100, y: 1500), in: frames), 2)
        XCTAssertNil(PointerGeometry.owner(of: .zero, in: [:]))
    }

    func testPixelAlignmentSnapsToDevicePixels() {
        XCTAssertEqual(PointerGeometry.pixelAligned(CGPoint(x: 10.3, y: 4.8), scale: 1), CGPoint(x: 10, y: 5))
        XCTAssertEqual(PointerGeometry.pixelAligned(CGPoint(x: 10.3, y: 4.8), scale: 2), CGPoint(x: 10.5, y: 5))
    }
}

@MainActor
final class BeaconHaloTests: XCTestCase {
    private var window: OverlayWindow?

    override func tearDown() async throws {
        window?.close()
        window = nil
    }

    private func makeHalo(restDelay: TimeInterval = 10, fade: TimeInterval = 0.02) -> BeaconHalo {
        let window = OverlayWindow(displayID: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        self.window = window
        let halo = BeaconHalo(dim: 0.25, restDelay: restDelay, fadeDuration: fade)
        halo.activate(on: window, tracker: CursorTracker())
        return halo
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testHaloIsCenteredOnThePointerAndHiddenElsewhere() {
        let halo = makeHalo()
        halo.pointerMoved(to: CGPoint(x: 123.5, y: 456.25), at: 0)
        XCTAssertEqual(halo.body.position, CGPoint(x: 123.5, y: 456.25))
        XCTAssertFalse(halo.root.isHidden)
        halo.pointerMoved(to: nil, at: 0.1)
        XCTAssertTrue(halo.root.isHidden)
        halo.deactivate()
        XCTAssertNil(halo.root.superlayer)
    }

    func testHaloFinishesAfterRest() async {
        let halo = makeHalo(restDelay: 0.05)
        var finished = false
        halo.onFinish = { finished = true }
        halo.pointerMoved(to: CGPoint(x: 10, y: 10), at: 0)
        await waitUntil { finished }
        XCTAssertTrue(finished)
    }

    func testMovementPostponesTheFade() async {
        let halo = makeHalo(restDelay: 0.3)
        var finished = false
        halo.onFinish = { finished = true }
        for step in 0..<8 {
            halo.pointerMoved(to: CGPoint(x: 10 + step, y: 10), at: Double(step) * 0.1)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertFalse(finished, "a moving pointer keeps the halo alive")
        await waitUntil { finished }
        XCTAssertTrue(finished)
    }

    func testHiddenHaloDoesNotFinish() async {
        let halo = makeHalo(restDelay: 0.05)
        var finished = false
        halo.onFinish = { finished = true }
        halo.pointerMoved(to: nil, at: 0)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(finished, "only the display that has the pointer runs the rest timer")
    }

    func testThemeColorsTheRing() {
        let halo = makeHalo()
        halo.apply(theme: .ink)
        XCTAssertEqual(halo.ring.strokeColor, Theme.ink.primary)
        halo.apply(theme: .minimal)
        XCTAssertEqual(halo.ring.strokeColor, Theme.minimal.primary)
    }
}
