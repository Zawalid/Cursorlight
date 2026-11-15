import AppKit
import XCTest

@testable import CursorlightCore

@MainActor
private final class FakeEffect: Effect {
    let id: EffectID
    var onFinish: (() -> Void)?
    private(set) var activations = 0
    private(set) var deactivations = 0
    private(set) var styles: [HighlightStyle] = []
    private(set) var moves: [CGPoint?] = []
    private(set) var window: OverlayWindow?

    init(id: EffectID) { self.id = id }

    func activate(on window: OverlayWindow, tracker: CursorTracker) {
        activations += 1
        self.window = window
    }

    func deactivate() { deactivations += 1 }
    func apply(style: HighlightStyle) { styles.append(style) }
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

    func testActivatingCursorlightTwiceIsIdempotent() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        engine.activate(.cursorlight)
        engine.activate(.cursorlight)
        XCTAssertEqual(engine.active, [.cursorlight])
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(made.first?.activations, 1)
    }

    func testDeactivateAllClearsActive() {
        let engine = makeEngine(frames: [
            1: CGRect(x: 0, y: 0, width: 800, height: 600),
            2: CGRect(x: 800, y: 0, width: 800, height: 600),
        ])
        engine.activate(.cursorlight)
        engine.activate(.laser)
        XCTAssertEqual(engine.active, [.cursorlight, .laser])
        XCTAssertEqual(made.count, 4, "one instance per effect per display")
        engine.deactivateAll()
        XCTAssertTrue(engine.active.isEmpty)
        XCTAssertTrue(made.allSatisfy { $0.deactivations == 1 })
    }

    func testStyleChangeAppliesToActiveEffects() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        engine.activate(.cursorlight)
        XCTAssertEqual(made.first?.styles.last, .aura)
        engine.style = .comet
        XCTAssertEqual(made.first?.styles.last, .comet)
        engine.deactivate(.cursorlight)
        engine.style = .lens
        XCTAssertEqual(made.first?.styles.last, .comet, "inactive effects are not touched")
    }

    func testDeactivateOneLeavesOthers() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        engine.activate(.cursorlight)
        engine.activate(.pulse)
        engine.deactivate(.cursorlight)
        XCTAssertEqual(engine.active, [.pulse])
    }

    func testFinishedEffectLeavesActiveSet() {
        let engine = makeEngine(frames: [1: CGRect(x: 0, y: 0, width: 800, height: 600)])
        engine.activate(.cursorlight)
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
        engine.activate(.cursorlight)
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

    func testBuiltInsLeaveTheHighlightToItsController() {
        windows = [OverlayWindow(displayID: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600))]
        let list = windows
        let engine = EffectEngine(tracker: CursorTracker(), windows: { list })
        engine.activate(.cursorlight)
        engine.activate(.pulse)
        XCTAssertTrue(engine.active.isEmpty)
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
