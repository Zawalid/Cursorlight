import CoreGraphics
import XCTest

@testable import BeaconCore

final class SpringFollowerTests: XCTestCase {
    func testPresetsMatchTheBrief() {
        XCTAssertEqual(SpringParameters.standard.omega, 20, accuracy: 1e-9)
        XCTAssertEqual(SpringParameters.standard.zeta, 1, accuracy: 1e-9)
        XCTAssertEqual(SpringParameters.silk.omega, 14, accuracy: 1e-9)
        XCTAssertEqual(SpringParameters.silk.zeta, 1, accuracy: 1e-9)
        XCTAssertEqual(SpringParameters.snappy.omega, 25, accuracy: 1e-9)
        XCTAssertEqual(SpringParameters.snappy.zeta, 1, accuracy: 1e-9)
        XCTAssertEqual(SpringParameters.standard, SpringParameters(tension: 400, mass: 1, friction: 40))
    }

    func testConvergesToExactlyZeroOffset() {
        var follower = SpringFollower(parameters: .standard, position: .zero)
        follower.target = CGPoint(x: 40, y: -12)
        var elapsed = 0.0
        while !follower.isSettled && elapsed < 2 {
            follower.step(dt: 1.0 / 120)
            elapsed += 1.0 / 120
        }
        XCTAssertEqual(follower.position, CGPoint(x: 40, y: -12), "exact, not approximately")
        XCTAssertEqual(follower.velocity, .zero)
        XCTAssertLessThan(elapsed, 0.4, "a 42 pt gap settles in well under 400 ms at omega 20")
    }

    func testLargeJumpSettlesWithinHalfASecondAndAHalf() {
        var follower = SpringFollower(parameters: .standard, position: .zero)
        follower.target = CGPoint(x: 300, y: 120)
        for _ in 0..<72 { follower.step(dt: 1.0 / 120) }  // 0.6 s
        XCTAssertTrue(follower.isSettled)
        XCTAssertEqual(follower.position, follower.target)
    }

    func testNoOvershootOnPositionAtAnyFrameRate() {
        for dt in [1.0 / 30, 1.0 / 60, 1.0 / 120, 1.0 / 240, 0.05] {
            for parameters in [SpringParameters.standard, .silk, .snappy] {
                var follower = SpringFollower(parameters: parameters, position: .zero)
                follower.target = CGPoint(x: 500, y: -500)
                var previous = follower.position
                for _ in 0..<Int(1.5 / dt) {
                    follower.step(dt: dt)
                    XCTAssertLessThanOrEqual(follower.position.x, 500)
                    XCTAssertGreaterThanOrEqual(follower.position.y, -500)
                    XCTAssertGreaterThanOrEqual(follower.position.x, previous.x, "monotonic, no wobble")
                    previous = follower.position
                }
                XCTAssertEqual(follower.position, follower.target)
            }
        }
    }

    func testRetargetKeepsPositionAndVelocityContinuous() {
        var follower = SpringFollower(parameters: .standard, position: .zero)
        follower.target = CGPoint(x: 400, y: 0)
        for _ in 0..<6 { follower.step(dt: 1.0 / 120) }
        let position = follower.position
        let velocity = follower.velocity
        follower.target = CGPoint(x: 400, y: 300)
        XCTAssertEqual(follower.position, position, "retargeting does not move the follower")
        XCTAssertEqual(follower.velocity, velocity, "nor restart its motion")
        follower.step(dt: 1.0 / 120)
        let moved = hypot(follower.position.x - position.x, follower.position.y - position.y)
        let speed = hypot(velocity.dx, velocity.dy)
        XCTAssertLessThan(moved, speed / 120 * 1.5 + 1, "the next step continues smoothly from the old velocity")
        XCTAssertGreaterThan(follower.position.x, position.x, "still travelling in the old direction")
    }

    func testStepIsExactRegardlessOfFrameRate() {
        var slow = SpringFollower(parameters: .snappy, position: .zero)
        var fast = slow
        slow.target = CGPoint(x: 200, y: 50)
        fast.target = slow.target
        for _ in 0..<15 { slow.step(dt: 1.0 / 60) }
        for _ in 0..<60 { fast.step(dt: 1.0 / 240) }
        XCTAssertEqual(slow.position.x, fast.position.x, accuracy: 1e-6)
        XCTAssertEqual(slow.position.y, fast.position.y, accuracy: 1e-6)
    }

    func testLongGapIsClamped() {
        var a = SpringFollower(parameters: .standard, position: .zero)
        var b = a
        a.target = CGPoint(x: 100, y: 0)
        b.target = a.target
        a.step(dt: 5)
        b.step(dt: SpringFollower.maximumStep)
        XCTAssertEqual(a, b)
    }

    func testScalarSpringSettlesExactly() {
        var spring = ScalarSpring(value: 1, omega: 33)
        spring.target = 0.8
        for _ in 0..<60 { spring.step(dt: 1.0 / 120) }
        XCTAssertEqual(spring.value, 0.8)
        XCTAssertTrue(spring.isSettled)
    }
}

final class EasingTests: XCTestCase {
    func testCurvesHitTheirEndsAndAreMonotonic() {
        for curve in [Easing.outExpo, Easing.easeIn] {
            XCTAssertEqual(curve(0), 0)
            XCTAssertEqual(curve(1), 1)
            var previous = 0.0
            for i in 1...100 {
                let value = curve(Double(i) / 100)
                XCTAssertGreaterThanOrEqual(value, previous - 1e-9)
                previous = value
            }
        }
        XCTAssertGreaterThan(Easing.outExpo(0.5), 0.85, "out-expo lands early")
        XCTAssertLessThan(Easing.easeIn(0.5), 0.5, "ease-in starts gently")
        XCTAssertEqual(Easing.outCubic(0.5), 0.875, accuracy: 1e-12)
        for y in [0.0, 0.1, 0.37, 0.8, 0.99, 1.0] {
            XCTAssertEqual(Easing.outExpo(Easing.outExpo.inverse(y)), y, accuracy: 1e-6)
        }
    }

    func testPopOvershootsOnlySlightly() {
        var peak = 0.0
        for i in 0...200 { peak = max(peak, Easing.pop(Double(i) / 200, from: 0.6)) }
        XCTAssertGreaterThan(peak, 1, "a scale pop may overshoot")
        XCTAssertLessThan(peak, 1.04, "but only by a few percent")
        XCTAssertEqual(Easing.pop(2, from: 0.6), 1, accuracy: 1e-6)
        XCTAssertEqual(Easing.pop(0, from: 0.6), 0.6)
    }
}

final class RippleCurveTests: XCTestCase {
    private let curve = RippleCurve()

    func testCurveValuesAtStartMiddleAndEnd() {
        XCTAssertEqual(curve.radius(0), 10)
        XCTAssertEqual(curve.alpha(0), 0.7, accuracy: 1e-12)
        XCTAssertEqual(curve.lineWidth(0), 3)
        XCTAssertEqual(curve.fillAlpha(0), 0.18, accuracy: 1e-12)

        XCTAssertEqual(curve.radius(0.5), 36.25, accuracy: 1e-9, "10 + 30 * (1 - 0.5^3)")
        XCTAssertEqual(curve.alpha(0.5), 0.7 * pow(0.5, 1.5), accuracy: 1e-9)
        XCTAssertEqual(curve.alpha(0.5), 0.24749, accuracy: 1e-5)
        XCTAssertEqual(curve.lineWidth(0.5), 2.25, accuracy: 1e-12)

        XCTAssertEqual(curve.radius(1), 40)
        XCTAssertEqual(curve.alpha(1), 0)
        XCTAssertEqual(curve.lineWidth(1), 1.5)
        XCTAssertEqual(curve.fillAlpha(1), 0)
    }

    func testPressRingHandsOverToTheRippleWithoutAJump() {
        let press = curve.press(elapsed: 0.12, center: .zero, button: .left)
        XCTAssertEqual(press.radius, curve.radius(0), accuracy: 1e-9)
        XCTAssertEqual(curve.press(elapsed: 0, center: .zero, button: .left).radius, 10 / 0.85, accuracy: 1e-9)
        XCTAssertEqual(curve.press(elapsed: 0, center: .zero, button: .left).alpha, 0, "fades in, never pops")
    }

    func testSummonPulseAndSonarRings() {
        let pulse = PulseRecipe(startRadius: 42, endRadius: 92)
        XCTAssertEqual(SummonPulse.ring(pulse, elapsed: 0, center: .zero)?.radius, 42)
        XCTAssertNil(SummonPulse.ring(pulse, elapsed: 0.6, center: .zero))
        let sonar = SonarRecipe()
        XCTAssertEqual(SummonPulse.sonarRings(sonar, elapsed: 0.2, center: .zero).count, 3)
        XCTAssertEqual(SummonPulse.sonarRings(sonar, elapsed: 0.01, center: .zero).count, 1, "staggered 80 ms")
        XCTAssertTrue(SummonPulse.sonarRings(sonar, elapsed: 0.8, center: .zero).isEmpty)
        let first = SummonPulse.sonarRings(sonar, elapsed: 0.0001, center: .zero)[0]
        XCTAssertEqual(first.radius, 140, accuracy: 0.1)
        XCTAssertLessThan(first.alpha, 0.01, "rings fade in")
    }
}

final class TrailBufferTests: XCTestCase {
    /// Moves the head along x at `speed` pt/s for `duration` seconds at `hz`, optionally skipping frames.
    private func run(hz: Double, speed: CGFloat = 1000, duration: Double = 1, drop: ClosedRange<Double>? = nil) -> TrailBuffer {
        var trail = TrailBuffer()
        let frames = Int(duration * hz)
        for i in 0...frames {
            let t = Double(i) / hz
            if let drop, drop.contains(t) { continue }
            trail.append(CGPoint(x: speed * CGFloat(t), y: 0), at: 10 + t, speed: speed)
        }
        return trail
    }

    private func length(_ trail: TrailBuffer) -> CGFloat {
        let points = trail.tapered()
        guard let first = points.first, let last = points.last else { return 0 }
        return last.point.x - first.point.x
    }

    func testLifetimeIsEventTimeNotPointCount() {
        let at60 = run(hz: 60)
        let at120 = run(hz: 120)
        XCTAssertEqual(at60.span, 0.4, accuracy: 3.0 / 60, "within one commit interval")
        XCTAssertEqual(at120.span, 0.4, accuracy: 3.0 / 120)
        XCTAssertEqual(length(at60), length(at120), accuracy: 20, "same tail length at any frame rate")
        XCTAssertEqual(length(at120), 400, accuracy: 20)
    }

    func testDroppedFramesDoNotLengthenTheTail() {
        let trail = run(hz: 60, drop: 0.8...0.9)
        XCTAssertLessThanOrEqual(trail.span, 0.4)
        XCTAssertLessThanOrEqual(length(trail), 400 + 1)
    }

    func testPointCountIsCappedWithoutShorteningTheTail() {
        let trail = run(hz: 240, speed: 3000)
        XCTAssertLessThanOrEqual(trail.samples.count, CometRecipe().maxPoints)
        XCTAssertEqual(trail.span, 0.4, accuracy: 4.0 / 240, "speed-adaptive spacing keeps the whole lifetime")
    }

    func testTaperValues() {
        let recipe = CometRecipe()
        XCTAssertEqual(TrailBuffer.width(age: 0, recipe: recipe), 10)
        XCTAssertEqual(TrailBuffer.width(age: 1, recipe: recipe), 1)
        XCTAssertEqual(TrailBuffer.width(age: 0.5, recipe: recipe), 1 + 9 * pow(0.5, 1.6), accuracy: 1e-9)
        XCTAssertEqual(TrailBuffer.alpha(age: 0, recipe: recipe), 0.95, accuracy: 1e-12)
        XCTAssertEqual(TrailBuffer.alpha(age: 0.5, recipe: recipe), 0.95 * pow(0.5, 1.5), accuracy: 1e-9)
        XCTAssertEqual(TrailBuffer.alpha(age: 1, recipe: recipe), 0)

        let points = run(hz: 120).tapered()
        XCTAssertEqual(points.last?.age, 0, "the head is last and fresh")
        XCTAssertEqual(points.last?.width, 10)
        XCTAssertGreaterThan(points.first?.age ?? 0, 0.9)
        let widths = points.map(\.width)
        XCTAssertEqual(widths, widths.sorted(), "width only grows toward the head")
    }

    func testDwellRetractsTheTailWithin150Milliseconds() {
        var trail = run(hz: 120, duration: 0.5)
        XCTAssertFalse(trail.isEmpty)
        let stop = CGPoint(x: 500, y: 0)
        var t = 10.5
        while t < 10.5 + 0.16 {
            t += 1.0 / 120
            trail.append(stop, at: t, speed: 0)
        }
        XCTAssertTrue(trail.isEmpty, "a dwelling head pulls its tail in, it does not smear")
    }

    func testFastMotionFromRestBuildsAFullTail() {
        var trail = TrailBuffer()
        for i in 0..<30 { trail.append(CGPoint(x: 0, y: 0), at: Double(i) / 120, speed: 0) }
        var t = 30.0 / 120
        for i in 1...60 {
            t += 1.0 / 120
            trail.append(CGPoint(x: CGFloat(i) * 2500 / 120, y: 0), at: t, speed: 2500)
        }
        XCTAssertGreaterThan(trail.samples.count, 20)
        XCTAssertEqual(length(trail), 1000, accuracy: 60, "0.4 s of tail at 2500 pt/s")
    }

    func testRestingHeadNeverRefillsTheBuffer() {
        var trail = TrailBuffer()
        for i in 0..<200 { trail.append(CGPoint(x: 5, y: 5), at: Double(i) / 120, speed: 0) }
        XCTAssertTrue(trail.isEmpty)
    }

    func testCatmullRomPassesThroughItsPoints() {
        let points = (0..<4).map { TrailPoint(point: CGPoint(x: $0 * 10, y: $0 % 2 == 0 ? 0 : 10), age: 0, width: 1, alpha: 1) }
        let smooth = CatmullRom.smooth(points, subdivisions: 3)
        XCTAssertEqual(smooth.count, 10)
        XCTAssertEqual(smooth[0].point, points[0].point)
        XCTAssertEqual(smooth[3].point, points[1].point)
        XCTAssertEqual(smooth.last?.point, points.last?.point)
    }
}

final class HighlightToggleTests: XCTestCase {
    func testToggleStateMachine() {
        var toggle = HighlightToggle(appearDuration: 0.4, disappearDuration: 0.25)
        XCTAssertFalse(toggle.isOn)
        XCTAssertFalse(toggle.isVisible)

        toggle.toggle(at: 1)
        XCTAssertEqual(toggle.phase, .appearing(start: 1))
        XCTAssertTrue(toggle.isOn)
        XCTAssertEqual(toggle.level(at: 1), 0)
        toggle.advance(to: 1.39)
        XCTAssertEqual(toggle.phase, .appearing(start: 1))
        toggle.advance(to: 1.4)
        XCTAssertEqual(toggle.phase, .on(appearedAt: 1))
        XCTAssertEqual(toggle.level(at: 100), 1, "stays fully on at rest, no fade")

        toggle.toggle(at: 100)
        XCTAssertFalse(toggle.isOn)
        XCTAssertTrue(toggle.isVisible)
        XCTAssertEqual(toggle.level(at: 100), 1)
        XCTAssertLessThan(toggle.level(at: 100.2), toggle.level(at: 100.1))
        toggle.advance(to: 100.25)
        XCTAssertEqual(toggle.phase, .off)
        XCTAssertEqual(toggle.level(at: 100.25), 0)
    }

    func testTogglingMidEntranceExitsFromTheCurrentLevel() {
        var toggle = HighlightToggle(appearDuration: 0.4, disappearDuration: 0.25)
        toggle.turnOn(at: 0)
        let level = toggle.level(at: 0.1)
        toggle.toggle(at: 0.1)
        XCTAssertEqual(toggle.level(at: 0.1), level, accuracy: 1e-12, "no jump")
        toggle.toggle(at: 0.15)
        XCTAssertTrue(toggle.isOn)
        XCTAssertEqual(toggle.level(at: 0.15), level * (1 - Easing.easeIn(0.2)), accuracy: 1e-6, "continues from the exit")
    }

    func testTurningOnMidExitIsContinuousAndRisesToFull() {
        var toggle = HighlightToggle(appearDuration: 0.45, disappearDuration: 0.25)
        toggle.turnOn(at: 0)
        toggle.advance(to: 1)
        toggle.turnOff(at: 1)
        let mid = 1.125
        let before = toggle.level(at: mid)
        XCTAssertGreaterThan(before, 0.2)
        XCTAssertLessThan(before, 0.95)
        toggle.turnOn(at: mid)
        XCTAssertEqual(toggle.level(at: mid), before, accuracy: 1e-6, "no drop to zero when turned back on")
        var previous = before
        var t = mid
        while t < mid + 0.6 {
            t += 1.0 / 120
            toggle.advance(to: t)
            let level = toggle.level(at: t)
            XCTAssertGreaterThanOrEqual(level, previous - 1e-9, "rises monotonically")
            previous = level
        }
        XCTAssertEqual(toggle.phase, .on(appearedAt: toggle.appearStart ?? -1))
        XCTAssertEqual(previous, 1)
    }

    func testTurningOnFromOffStartsTheEntranceNow() {
        var toggle = HighlightToggle(appearDuration: 0.4, disappearDuration: 0.25)
        toggle.turnOn(at: 3)
        XCTAssertEqual(toggle.phase, .appearing(start: 3))
    }

    func testTurningOnTwiceIsIdempotent() {
        var toggle = HighlightToggle(appearDuration: 0.4, disappearDuration: 0.25)
        toggle.turnOn(at: 0)
        toggle.turnOn(at: 0.2)
        XCTAssertEqual(toggle.phase, .appearing(start: 0))
        toggle.turnOff(at: 1)
        toggle.turnOff(at: 1.1)
        XCTAssertEqual(toggle.phase, .disappearing(start: 1, from: 1))
    }
}

final class MotionShapingTests: XCTestCase {
    func testStretchFollowsVelocity() {
        XCTAssertEqual(VelocityStretch.of(velocity: .zero, stretch: 1.3, squash: 0.9, fullSpeed: 1800), .identity)
        let full = VelocityStretch.of(velocity: CGVector(dx: 0, dy: 4000), stretch: 1.3, squash: 0.9, fullSpeed: 1800)
        XCTAssertEqual(full.along, 1.3, accuracy: 1e-9)
        XCTAssertEqual(full.across, 0.9, accuracy: 1e-9)
        XCTAssertEqual(full.angle, .pi / 2, accuracy: 1e-9)
        let transformed = CGPoint(x: 0, y: 10).applying(full.transform)
        XCTAssertEqual(transformed.y, 13, accuracy: 1e-9, "stretched along the motion")
        XCTAssertEqual(transformed.x, 0, accuracy: 1e-9)
    }

    func testLeadNeverPassesThePointer() {
        let follower = CGPoint(x: 0, y: 0)
        let pointer = CGPoint(x: 5, y: 0)
        let fast = PredictiveLead.drawn(
            follower: follower, velocity: CGVector(dx: 3000, dy: 0), pointer: pointer, lead: 0.012, clamp: 12
        )
        XCTAssertEqual(fast, pointer, "clamped to the remaining gap")
        let far = PredictiveLead.drawn(
            follower: follower, velocity: CGVector(dx: 3000, dy: 0), pointer: CGPoint(x: 100, y: 0), lead: 0.012, clamp: 12
        )
        XCTAssertEqual(far.x, 12, accuracy: 1e-9, "clamped to 12 pt")
        let away = PredictiveLead.drawn(
            follower: follower, velocity: CGVector(dx: -500, dy: 0), pointer: pointer, lead: 0.012, clamp: 12
        )
        XCTAssertEqual(away, follower, "a velocity away from the pointer adds no lead")
        XCTAssertEqual(
            PredictiveLead.drawn(follower: pointer, velocity: .zero, pointer: pointer, lead: 0.012, clamp: 12), pointer
        )
    }
}

final class StyleRecipeTests: XCTestCase {
    func testAuraMatchesTheBrief() {
        let r = HighlightStyle.aura.recipe
        XCTAssertEqual(r.spring, .standard)
        XCTAssertEqual(r.aura.radius, 42)
        XCTAssertEqual(r.aura.core.radiusFactor, 0.45)
        XCTAssertEqual(r.aura.core.alpha, 0.35)
        XCTAssertEqual(r.aura.mid, GlowLayerRecipe(radiusFactor: 1, alpha: 0.16, blur: 12))
        XCTAssertEqual(r.aura.outer, GlowLayerRecipe(radiusFactor: 1.9, alpha: 0.06, blur: 32))
        XCTAssertEqual(r.aura.stretch, 1.3)
        XCTAssertEqual(r.aura.squash, 0.9)
        XCTAssertEqual(r.aura.breathScale, 1.04)
        XCTAssertEqual(r.aura.breathPeriod, 2.4)
        XCTAssertEqual(r.aura.breathAlpha, 0.03)
        XCTAssertEqual(r.ripple.fillAlpha, 0.18)
        XCTAssertGreaterThanOrEqual(2 * r.aura.radius, 72, "halo diameter survives screen-share downscale")
    }

    func testLensMatchesTheBrief() {
        let r = HighlightStyle.lens.recipe
        XCTAssertEqual(r.spring, .silk)
        XCTAssertEqual(r.lens.radius, 120)
        XCTAssertEqual(r.lens.feather, 0.23)
        XCTAssertEqual(r.lens.dim, 0.5)
        XCTAssertLessThanOrEqual(r.lens.dim, 0.65)
        XCTAssertEqual(r.lens.entranceScale, 2.2)
        XCTAssertEqual(r.appearDuration, 0.4)
        XCTAssertEqual(r.disappearDuration, 0.25)
        XCTAssertEqual(r.lens.pressScale, 0.8)
        XCTAssertEqual(r.lens.pressDuration, 0.12)
        XCTAssertTrue(r.ripple.lightRing)
        XCTAssertEqual(r.ripple.startWidth, 2)
        XCTAssertEqual(r.ripple.endWidth, 2)
        XCTAssertEqual(r.ripple.fillAlpha, 0)
    }

    func testCometMatchesTheBrief() {
        let r = HighlightStyle.comet.recipe
        XCTAssertEqual(r.spring, .snappy)
        XCTAssertEqual(r.comet.lifetime, 0.4)
        XCTAssertEqual(r.comet.headWidth, 10)
        XCTAssertEqual(r.comet.tailWidth, 1)
        XCTAssertEqual(r.comet.widthPower, 1.6)
        XCTAssertEqual(r.comet.alphaPower, 1.5)
        XCTAssertEqual(r.comet.coreWidth, 3)
        XCTAssertEqual(r.comet.glowWidth, 14)
        XCTAssertEqual(r.comet.glowAlpha, 0.45)
        XCTAssertEqual(r.comet.headDiameter, 14)
        XCTAssertEqual(r.comet.headHaloDiameter, 28)
        XCTAssertEqual(abs(r.comet.hueShift), 25)
        XCTAssertEqual(r.comet.maxPoints, 48)
        XCTAssertEqual(r.comet.dwellSpeed, 40)
        XCTAssertEqual(r.comet.dwellShrink, 0.15)
    }

    func testKeylineMatchesTheBrief() {
        let r = HighlightStyle.keyline.recipe
        XCTAssertEqual(r.spring, .standard)
        XCTAssertEqual(r.keyline.radius, 28)
        XCTAssertEqual(r.keyline.lightWidth, 3)
        XCTAssertEqual(r.keyline.darkWidth, 1)
        XCTAssertEqual(r.keyline.darkAlpha, 0.35)
        XCTAssertEqual(r.keyline.dotDiameter, 4)
        XCTAssertEqual(r.keyline.predictionLead, 0.012)
        XCTAssertEqual(r.keyline.predictionClamp, 12)
        XCTAssertEqual(r.keyline.pressScale, 0.85)
        XCTAssertEqual(r.ripple.duration, 0.45)
        XCTAssertEqual(r.ripple.startWidth, 3)
        XCTAssertEqual(r.ripple.endWidth, 1.5)
        XCTAssertEqual(r.ripple.fillAlpha, 0, "outline only")
        XCTAssertNil(r.pulse, "the ring settling in is the entrance; no second ring")
    }

    func testSonarMatchesTheBrief() {
        let r = HighlightStyle.sonar.recipe
        XCTAssertEqual(r.spring, .standard)
        XCTAssertEqual(r.sonar.ringCount, 3)
        XCTAssertEqual(r.sonar.startRadius, 140)
        XCTAssertEqual(r.sonar.endRadius, 20)
        XCTAssertEqual(r.sonar.ringDuration, 0.6)
        XCTAssertEqual(r.sonar.stagger, 0.08)
        XCTAssertEqual(r.sonar.ringAlpha, 0.5)
        XCTAssertEqual(r.sonar.dotRadius, 18)
    }

    func testDefaultRippleMatchesTheBrief() {
        let r = RippleRecipe()
        XCTAssertEqual(r.duration, 0.52)
        XCTAssertEqual(r.startRadius, 10)
        XCTAssertEqual(r.endRadius, 40)
        XCTAssertEqual(r.startWidth, 3)
        XCTAssertEqual(r.endWidth, 1.5)
        XCTAssertEqual(r.fillAlpha, 0.18)
        XCTAssertEqual(r.alpha, 0.7)
        XCTAssertEqual(r.alphaPower, 1.5)
        XCTAssertEqual(r.pressScale, 0.85)
        XCTAssertEqual(r.pressDuration, 0.12)
        XCTAssertEqual(r.maxConcurrent, 6)
    }

    func testNoEffectIsShorterThanAScreenShareFrameCanCatch() {
        for style in HighlightStyle.allCases {
            let r = style.recipe
            XCTAssertGreaterThanOrEqual(r.appearDuration, 0.25, "\(style)")
            XCTAssertGreaterThanOrEqual(r.disappearDuration, 0.25, "\(style)")
            XCTAssertGreaterThanOrEqual(r.ripple.duration, 0.45, "\(style)")
            XCTAssertGreaterThanOrEqual(r.pulse?.duration ?? 0.6, 0.45, "\(style)")
        }
    }

    func testStylesPersistByRawValue() {
        XCTAssertEqual(HighlightStyle.allCases.map(\.rawValue), ["aura", "lens", "comet", "keyline", "sonar"])
        XCTAssertEqual(HighlightStyle(rawValue: "comet"), .comet)
        XCTAssertEqual(Set(HighlightStyle.allCases.map(\.displayName)).count, 5)
    }
}

final class PaletteTests: XCTestCase {
    private let white = RGBA(1, 1, 1)
    private let black = RGBA(0, 0, 0)

    func testAccentsReadOnLightAndDarkBackgrounds() {
        for style in HighlightStyle.allCases {
            let accent = Palette.accent(for: style)
            XCTAssertGreaterThanOrEqual(accent.contrast(with: white), 2.0, "\(style) on white")
            XCTAssertGreaterThanOrEqual(accent.contrast(with: black), 4.5, "\(style) on black")
        }
        XCTAssertEqual(Set(HighlightStyle.allCases.map(Palette.accent(for:))).count, 5)
    }

    func testLightCoreAndDarkKeylineAreLuminanceOpposites() {
        XCTAssertGreaterThan(Palette.light.luminance, 0.9)
        XCTAssertLessThan(Palette.keyline.luminance, 0.01)
        XCTAssertGreaterThan(Palette.light.contrast(with: Palette.keyline), 15)
    }

    func testHueRotation() {
        let accent = Palette.accent(for: .comet)
        let full = accent.hueRotated(by: 360)
        XCTAssertEqual(full.red, accent.red, accuracy: 1e-9)
        XCTAssertEqual(full.green, accent.green, accuracy: 1e-9)
        XCTAssertEqual(full.blue, accent.blue, accuracy: 1e-9)
        XCTAssertNotEqual(accent.hueRotated(by: -25), accent)
        XCTAssertEqual(RGBA(1, 0, 0).hueRotated(by: 120).green, 1, accuracy: 1e-9)
        XCTAssertEqual(Palette.rippleAccent(for: .aura, button: .left), Palette.accent(for: .aura))
        XCTAssertNotEqual(Palette.rippleAccent(for: .aura, button: .right), Palette.accent(for: .aura))
        XCTAssertEqual(RGBA(hex: "#FF5A36"), RGBA(1, 90.0 / 255, 54.0 / 255))
    }
}
