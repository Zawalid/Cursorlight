import CoreGraphics
import XCTest

@testable import CursorlightCore

final class HighlightModelTests: XCTestCase {
    /// Steps the model at `hz` from `start` to `end` with a pointer path, returning the last frame.
    @discardableResult
    private func run(
        _ model: inout HighlightModel, from start: TimeInterval, to end: TimeInterval, hz: Double = 120,
        pointer: (TimeInterval) -> CGPoint
    ) -> HighlightFrame {
        var t = start
        var frame = model.step(pointer: pointer(t), time: t)
        while t < end - 1e-9 {
            t = min(t + 1 / hz, end)
            frame = model.step(pointer: pointer(t), time: t)
        }
        return frame
    }

    func testShakeTogglesAndTheHighlightStaysOnAtRest() {
        var model = HighlightModel(style: .aura, pointer: CGPoint(x: 100, y: 100))
        model.toggleHighlight(at: 0, pointer: CGPoint(x: 100, y: 100))
        XCTAssertTrue(model.isOn)
        let frame = run(&model, from: 0, to: 20) { _ in CGPoint(x: 100, y: 100) }
        XCTAssertTrue(model.isOn, "no fade at rest")
        XCTAssertTrue(frame.isShown)
        XCTAssertEqual(frame.level, 1)
        XCTAssertEqual(frame.bodyScale, 1, accuracy: 1e-9, "breathing has come to rest")
        XCTAssertFalse(model.needsFrames, "nothing moves once it rests")

        model.toggleHighlight(at: 20, pointer: CGPoint(x: 100, y: 100))
        XCTAssertFalse(model.isOn)
        let gone = run(&model, from: 20, to: 20.3) { _ in CGPoint(x: 100, y: 100) }
        XCTAssertFalse(gone.isShown)
    }

    func testEveryStyleLandsAtExactlyZeroOffsetAtRest() {
        for style in HighlightStyle.allCases {
            var model = HighlightModel(style: style, pointer: CGPoint(x: -1200.5, y: 300.25))
            model.setHighlight(true, at: 0, pointer: CGPoint(x: -1200.5, y: 300.25))
            let target = CGPoint(x: -900.75, y: 512.5)
            let frame = run(&model, from: 0, to: 1.2) { t in
                t < 0.3 ? CGPoint(x: -1200.5 + 1000 * t, y: 300.25 + 700 * t) : target
            }
            XCTAssertEqual(frame.center, target, "\(style)")
            XCTAssertTrue(frame.isSettled, "\(style)")
            XCTAssertEqual(frame.stretch, .identity, "\(style)")
        }
    }

    func testHighlightAppearsOnThePointerNotWhereItWasLastTime() {
        var model = HighlightModel(style: .keyline, pointer: .zero)
        model.setHighlight(true, at: 0, pointer: .zero)
        run(&model, from: 0, to: 1) { _ in .zero }
        model.setHighlight(false, at: 1, pointer: .zero)
        run(&model, from: 1, to: 2) { _ in .zero }
        model.setHighlight(true, at: 5, pointer: CGPoint(x: 800, y: 600))
        let frame = model.step(pointer: CGPoint(x: 800, y: 600), time: 5)
        XCTAssertEqual(frame.center, CGPoint(x: 800, y: 600))
    }

    func testFollowerTrailsAMovingPointerWithoutOvershoot() {
        var model = HighlightModel(style: .aura, pointer: .zero)
        model.setHighlight(true, at: 0, pointer: .zero)
        var maxX: CGFloat = 0
        var t = 0.0
        while t < 1 {
            t += 1.0 / 120
            let frame = model.step(pointer: CGPoint(x: t < 0.25 ? 1600 * t : 400, y: 0), time: t)
            maxX = max(maxX, frame.center.x)
            if t > 0.05 && t < 0.25 {
                XCTAssertLessThan(frame.center.x, 1600 * t, "the follower lags behind a moving pointer")
                XCTAssertGreaterThan(frame.stretch.along, 1, "and the lag reads as stretch")
            }
        }
        XCTAssertLessThanOrEqual(maxX, 400, "never overshoots the pointer")
    }

    func testEntrancePulsesMarkTheMomentItAppears() {
        var aura = HighlightModel(style: .aura, pointer: .zero)
        aura.setHighlight(true, at: 0, pointer: .zero)
        let early = run(&aura, from: 0, to: 0.1) { _ in .zero }
        XCTAssertNotNil(early.pulse)
        XCTAssertLessThan(early.level, 1)
        let late = run(&aura, from: 0.1, to: 1) { _ in .zero }
        XCTAssertNil(late.pulse)
        XCTAssertEqual(late.level, 1)

        var sonar = HighlightModel(style: .sonar, pointer: .zero)
        sonar.setHighlight(true, at: 0, pointer: .zero)
        let rings = run(&sonar, from: 0, to: 0.2) { _ in .zero }
        XCTAssertEqual(rings.sonarRings.count, 3)
        XCTAssertLessThan(rings.dotLevel, 0.01, "the dot waits for the rings")
        let dot = run(&sonar, from: 0.2, to: 2) { _ in .zero }
        XCTAssertTrue(dot.sonarRings.isEmpty)
        XCTAssertEqual(dot.dotLevel, 1, "the dot stays")
        XCTAssertTrue(sonar.isOn)
    }

    func testAuraBreathesOnlyAtRestAndThenStops() {
        var model = HighlightModel(style: .aura, pointer: .zero)
        model.setHighlight(true, at: 0, pointer: .zero)
        var scales: [CGFloat] = []
        var t = 0.0
        var frame = model.step(pointer: .zero, time: 0)
        while t < 12 {
            t += 1.0 / 60
            frame = model.step(pointer: .zero, time: t)
            if t > 1 { scales.append(frame.bodyScale) }
        }
        XCTAssertGreaterThan(scales.max() ?? 0, 1.02, "breathes up to about 4 %")
        XCTAssertLessThanOrEqual(scales.max() ?? 2, 1.04 + 1e-9)
        XCTAssertGreaterThanOrEqual(scales.min() ?? 0, 1 - 1e-9)
        XCTAssertEqual(frame.bodyScale, 1, accuracy: 1e-9, "stops after three cycles")

        // Moving makes breathing fade out (no jump in scale between frames).
        var moving = HighlightModel(style: .aura, pointer: .zero)
        moving.setHighlight(true, at: 0, pointer: .zero)
        var previous = run(&moving, from: 0, to: 1.8) { _ in .zero }.bodyScale
        t = 1.8
        while t < 2.4 {
            t += 1.0 / 120
            let scale = moving.step(pointer: CGPoint(x: 300 * (t - 1.8), y: 0), time: t).bodyScale
            XCTAssertLessThan(abs(scale - previous), 0.004, "smooth")
            previous = scale
        }
        XCTAssertEqual(previous, 1, accuracy: 0.002, "no breathing while moving")
    }

    func testLensClosesInAndShrinksOnMouseDown() {
        var model = HighlightModel(style: .lens, pointer: .zero)
        model.setHighlight(true, at: 0, pointer: .zero)
        let first = model.step(pointer: .zero, time: 0)
        XCTAssertEqual(first.lensScale, 2.2, accuracy: 1e-9)
        XCTAssertEqual(first.dimLevel, 0)
        let open = run(&model, from: 0, to: 1) { _ in .zero }
        XCTAssertEqual(open.lensScale, 1)
        XCTAssertEqual(open.dimLevel, 1)

        model.mouseDown(.left, at: 1)
        let pressed = run(&model, from: 1, to: 1.4) { _ in .zero }
        XCTAssertEqual(pressed.lensScale, 0.8, accuracy: 1e-3)
        model.mouseUp(.left, at: .zero, time: 1.4)
        let released = run(&model, from: 1.4, to: 1.8) { _ in .zero }
        XCTAssertEqual(released.lensScale, 1, accuracy: 1e-3)
    }

    func testClickRippleFiresOnMouseUpFromThePressRing() {
        var model = HighlightModel(style: .aura, pointer: CGPoint(x: 50, y: 50))
        model.mouseDown(.left, at: 0)
        let held = run(&model, from: 0, to: 0.2) { _ in CGPoint(x: 50, y: 50) }
        XCTAssertEqual(held.press?.radius ?? 0, 10, accuracy: 1e-9)
        XCTAssertTrue(held.ripples.isEmpty)
        XCTAssertFalse(held.isShown, "ripples work while the highlight is off")

        model.mouseUp(.left, at: CGPoint(x: 50, y: 50), time: 0.2)
        let fired = model.step(pointer: CGPoint(x: 50, y: 50), time: 0.2)
        XCTAssertNil(fired.press)
        XCTAssertEqual(fired.ripples.count, 1)
        XCTAssertEqual(fired.ripples[0].radius, 10, accuracy: 1e-9, "no jump from the press ring")
        XCTAssertEqual(fired.ripples[0].alpha, 0.7, accuracy: 1e-9)

        let half = run(&model, from: 0.2, to: 0.46) { _ in CGPoint(x: 50, y: 50) }
        XCTAssertEqual(half.ripples.first?.radius ?? 0, 36.25, accuracy: 1e-6)
        let done = run(&model, from: 0.46, to: 0.8) { _ in CGPoint(x: 50, y: 50) }
        XCTAssertTrue(done.ripples.isEmpty)
        XCTAssertFalse(model.needsFrames)
    }

    func testRightClickRippleIsMarkedRight() {
        var model = HighlightModel(style: .comet, pointer: .zero)
        model.mouseDown(.right, at: 0)
        model.mouseUp(.right, at: .zero, time: 0.05)
        let frame = model.step(pointer: .zero, time: 0.06)
        XCTAssertEqual(frame.ripples.first?.button, .right)
    }

    func testRipplesCanBeTurnedOff() {
        var model = HighlightModel(style: .aura, ripplesEnabled: false, pointer: .zero)
        model.mouseDown(.left, at: 0)
        model.mouseUp(.left, at: .zero, time: 0.1)
        let frame = model.step(pointer: .zero, time: 0.1)
        XCTAssertNil(frame.press)
        XCTAssertTrue(frame.ripples.isEmpty)
    }

    func testAtMostSixRipples() {
        var model = HighlightModel(style: .aura, pointer: .zero)
        for i in 0..<10 {
            model.mouseDown(.left, at: Double(i) * 0.02)
            model.mouseUp(.left, at: .zero, time: Double(i) * 0.02 + 0.01)
        }
        XCTAssertEqual(model.step(pointer: .zero, time: 0.2).ripples.count, 6)
    }

    func testCometTrailExistsOnlyWhileMoving() {
        var model = HighlightModel(style: .comet, pointer: .zero)
        model.setHighlight(true, at: 0, pointer: .zero)
        let moving = run(&model, from: 0, to: 0.5) { t in CGPoint(x: 1500 * t, y: 0) }
        XCTAssertGreaterThan(moving.trail.count, 4)
        XCTAssertEqual(moving.trail.last?.width, 10)
        let resting = run(&model, from: 0.5, to: 1.5) { _ in CGPoint(x: 750, y: 0) }
        XCTAssertLessThan(resting.trail.count, 2, "the tail pulls in at rest")
        XCTAssertFalse(model.needsFrames)
    }

    func testKeylineLeadsButNeverPassesThePointer() {
        var model = HighlightModel(style: .keyline, pointer: .zero)
        model.setHighlight(true, at: 0, pointer: .zero)
        var t = 0.0
        while t < 0.5 {
            t += 1.0 / 120
            let pointer = CGPoint(x: min(2000 * t, 600), y: 0)
            let frame = model.step(pointer: pointer, time: t)
            XCTAssertLessThanOrEqual(frame.center.x, pointer.x + 1e-9)
            XCTAssertGreaterThanOrEqual(frame.center.x, model.follower.position.x - 1e-9)
        }
    }

    func testStyleChangeReplaysTheEntranceAndRestsAgain() {
        var model = HighlightModel(style: .aura, pointer: .zero)
        model.setHighlight(true, at: 0, pointer: .zero)
        run(&model, from: 0, to: 10) { _ in .zero }
        model.setStyle(.keyline, at: 10)
        XCTAssertEqual(model.toggle.phase, .appearing(start: 10))
        XCTAssertEqual(model.follower.parameters, .standard)
        let frame = run(&model, from: 10, to: 11) { _ in .zero }
        XCTAssertEqual(frame.style, .keyline)
        XCTAssertEqual(frame.bodyScale, 1, accuracy: 1e-9)
        XCTAssertFalse(model.needsFrames)
    }

    func testPausedClockRestartsInsteadOfJumping() {
        var model = HighlightModel(style: .aura, pointer: .zero)
        model.setHighlight(true, at: 0, pointer: .zero)
        run(&model, from: 0, to: 1) { _ in .zero }
        let frame = model.step(pointer: CGPoint(x: 200, y: 0), time: 30)
        XCTAssertEqual(frame.center, .zero, "a long pause is not integrated")
        let next = model.step(pointer: CGPoint(x: 200, y: 0), time: 30 + 1.0 / 60)
        XCTAssertGreaterThan(next.center.x, 0)
        XCTAssertLessThan(next.center.x, 200)
    }
}

final class PixelGeometryTests: XCTestCase {
    func testRingBandEdgesLandOnDevicePixels() {
        for scale: CGFloat in [1, 2, 3] {
            let bands = PointerGeometry.ringBands(edges: [24.5, 26.5, 29.5, 30.5], scale: scale)
            XCTAssertEqual(bands.count, 3)
            for band in bands {
                let inner = (band.radius - band.width / 2) * scale
                let outer = (band.radius + band.width / 2) * scale
                XCTAssertEqual(inner, inner.rounded(), accuracy: 1e-9, "scale \(scale)")
                XCTAssertEqual(outer, outer.rounded(), accuracy: 1e-9, "scale \(scale)")
                XCTAssertGreaterThanOrEqual(band.width * scale, 1 - 1e-9)
            }
        }
        let retina = PointerGeometry.ringBands(edges: [25.5, 26.5, 29.5, 30.5], scale: 2)
        XCTAssertEqual(retina.map(\.width), [1, 3, 1], "Keyline stack is unchanged on Retina")
        XCTAssertEqual(PointerGeometry.snapped(28.3, scale: 2), 28.5)
        XCTAssertEqual(PointerGeometry.snapped(-10.3, scale: 2), -10.5)
    }

    func testSettledHighlightIsPixelSnappedOnMixedScaleNegativeOriginDisplays() {
        // A 2x display left of and above a 1x main display.
        let retina = CGRect(x: -1512, y: 200, width: 1512, height: 982)
        let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let pointer = CGPoint(x: -1000.3, y: 250.8)
        XCTAssertEqual(PointerGeometry.owner(of: pointer, in: [1: main, 2: retina]), 2)

        let local = PointerGeometry.layerPoint(for: pointer, windowFrame: retina)
        XCTAssertEqual(local.x, 511.7, accuracy: 1e-9)
        XCTAssertEqual(local.y, 50.8, accuracy: 1e-9)
        XCTAssertEqual(PointerGeometry.pixelAligned(local, scale: 2), CGPoint(x: 511.5, y: 51))
        let onMain = PointerGeometry.layerPoint(for: CGPoint(x: 100.3, y: 50.7), windowFrame: main)
        XCTAssertEqual(PointerGeometry.pixelAligned(onMain, scale: 1), CGPoint(x: 100, y: 51))
    }
}
