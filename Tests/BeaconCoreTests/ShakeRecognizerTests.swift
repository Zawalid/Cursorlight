import CoreGraphics
import XCTest

@testable import BeaconCore

final class ShakeRecognizerTests: XCTestCase {
    private let step: TimeInterval = 0.02

    /// Feeds a horizontal sine wobble and returns the times at which a shake fired.
    private func wobble(
        into recognizer: inout ShakeRecognizer,
        amplitude: Double,
        period: TimeInterval,
        from start: TimeInterval = 0,
        duration: TimeInterval
    ) -> [TimeInterval] {
        var fired: [TimeInterval] = []
        var time = start
        while time <= start + duration + 1e-9 {
            let x = 500 + amplitude * sin(2 * .pi * (time - start) / period)
            if recognizer.feed(position: CGPoint(x: x, y: 400), time: time) { fired.append(time) }
            time += step
        }
        return fired
    }

    func testRecognizesFastBackAndForth() {
        var recognizer = ShakeRecognizer(sensitivity: 50)
        // Amplitude 160 gives a 320 pt sweep, three cycles (six reversals) in under 0.5 s.
        let fired = wobble(into: &recognizer, amplitude: 160, period: 0.14, duration: 0.5)
        XCTAssertFalse(fired.isEmpty)
    }

    func testIgnoresSlowDrift() {
        var recognizer = ShakeRecognizer(sensitivity: 50)
        let fired = wobble(into: &recognizer, amplitude: 20, period: 3, duration: 6)
        XCTAssertTrue(fired.isEmpty)
    }

    func testIgnoresStraightFastMove() {
        var recognizer = ShakeRecognizer(sensitivity: 50)
        var fired = false
        var time = 0.0
        while time <= 0.5 {
            // 4000 pt/s in a straight line: long and fast, but never reverses.
            fired = recognizer.feed(position: CGPoint(x: 100 + 4000 * time, y: 300), time: time) || fired
            time += step
        }
        XCTAssertFalse(fired)
    }

    func testCooldownPreventsDoubleFire() {
        var recognizer = ShakeRecognizer(sensitivity: 50)
        let fired = wobble(into: &recognizer, amplitude: 160, period: 0.14, duration: 0.9)
        XCTAssertEqual(fired.count, 1)
        let later = wobble(into: &recognizer, amplitude: 160, period: 0.14, from: 3, duration: 0.6)
        XCTAssertFalse(later.isEmpty)
    }

    func testHigherSensitivityFiresOnSmallerShake() {
        var strict = ShakeRecognizer(sensitivity: 0)
        var eager = ShakeRecognizer(sensitivity: 100)
        let strictFired = wobble(into: &strict, amplitude: 100, period: 0.14, duration: 0.6)
        let eagerFired = wobble(into: &eager, amplitude: 100, period: 0.14, duration: 0.6)
        XCTAssertTrue(strictFired.isEmpty)
        XCTAssertFalse(eagerFired.isEmpty)
    }
}
