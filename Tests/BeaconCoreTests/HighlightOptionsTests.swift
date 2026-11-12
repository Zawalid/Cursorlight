import XCTest
@testable import BeaconCore

final class HighlightOptionsTests: XCTestCase {
    func testDefaultsChangeNothing() {
        let base = StyleHighlight.recipe(.comet).applying(.standard)
        XCTAssertEqual(base.comet.lifetime, HighlightStyle.comet.recipe.comet.lifetime)
        XCTAssertEqual(base.sonar.ringCount, HighlightStyle.sonar.recipe.sonar.ringCount)
        XCTAssertEqual(base.lens.feather, HighlightStyle.lens.recipe.lens.feather)
    }

    func testOptionsChangeTheRecipe() {
        var options = HighlightOptions()
        options.cometTail = 2
        options.keylineWidth = 2
        options.sonarRings = 5
        options.lensSoftness = 0.5
        options.auraBreathing = false
        let look = HighlightLook(options: options)
        XCTAssertEqual(HighlightStyle.comet.recipe.applying(look).comet.lifetime, HighlightStyle.comet.recipe.comet.lifetime * 2, accuracy: 1e-9)
        XCTAssertEqual(HighlightStyle.keyline.recipe.applying(look).keyline.lightWidth, HighlightStyle.keyline.recipe.keyline.lightWidth * 2, accuracy: 1e-9)
        XCTAssertEqual(HighlightStyle.sonar.recipe.applying(look).sonar.ringCount, 5)
        XCTAssertEqual(HighlightStyle.lens.recipe.applying(look).lens.feather, 0.5, accuracy: 1e-9)
        XCTAssertEqual(HighlightStyle.aura.recipe.applying(look).aura.breathCycles, 0)
    }

    func testLaserIgnoresStyleOptions() {
        var options = HighlightOptions()
        options.cometTail = 2
        let look = HighlightLook(options: options)
        XCTAssertEqual(StyleRecipe.laser.applying(look, includesStyleOptions: false).comet.lifetime, StyleRecipe.laser.comet.lifetime)
    }

    func testSanitizeClampsAndTreatsSmallFadeAsOff() {
        var o = HighlightOptions()
        o.cometTail = 99
        o.sonarRings = 40
        o.fadeAfterStill = 0.3
        var clean = o.sanitized()
        XCTAssertEqual(clean.cometTail, HighlightOptions.tailRange.upperBound)
        XCTAssertEqual(clean.sonarRings, 5)
        XCTAssertEqual(clean.fadeAfterStill, 0)
        o.fadeAfterStill = 60
        clean = o.sanitized()
        XCTAssertEqual(clean.fadeAfterStill, HighlightOptions.fadeRange.upperBound)
    }

    func testOptionsSurviveSettingsAndSnapshotRoundTrip() throws {
        var settings = BeaconSettings.defaults
        settings.highlightOptions.cometTail = 1.5
        settings.highlightOptions.fadeAfterStill = 4
        settings.hideRules.fullScreenApps = true
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.highlightOptions.cometTail, 1.5)
        XCTAssertEqual(decoded.highlightOptions.fadeAfterStill, 4)
        XCTAssertTrue(decoded.hideRules.fullScreenApps)
        XCTAssertEqual(decoded.snapshot.options.fadeAfterStill, 4)
        var other = BeaconSettings.defaults
        other.apply(decoded.snapshot)
        XCTAssertEqual(other.highlightOptions.cometTail, 1.5)
    }

    func testOldSettingsWithoutOptionsStillDecode() throws {
        let old = Data(#"{"version":1,"highlightStyle":"comet"}"#.utf8)
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: old)
        XCTAssertEqual(decoded.highlightOptions, HighlightOptions())
        XCTAssertFalse(decoded.hideRules.isActive)
    }
}

private enum StyleHighlight {
    static func recipe(_ style: HighlightStyle) -> StyleRecipe { style.recipe }
}

final class FadeWhenStillTests: XCTestCase {
    private func model(fade: Double) -> HighlightModel {
        var options = HighlightOptions()
        options.fadeAfterStill = fade
        var m = HighlightModel(style: .keyline, pointer: .zero, look: HighlightLook(options: options))
        m.setHighlight(true, at: 0, pointer: .zero)
        return m
    }

    /// Steps 60 times a second from `from` to `to` with the pointer at `point`; returns the last frame.
    private func run(_ m: inout HighlightModel, from: Double, to: Double, at point: CGPoint) -> HighlightFrame {
        var frame = m.step(pointer: point, time: from)
        var t = from
        while t < to {
            t += 1.0 / 60
            frame = m.step(pointer: point, time: t)
        }
        return frame
    }

    func testStaysVisibleWhileOptionIsOff() {
        var m = model(fade: 0)
        let frame = run(&m, from: 0, to: 30, at: .zero)
        XCTAssertEqual(frame.level, 1, accuracy: 1e-6)
    }

    func testFadesOutAfterStillnessAndKeepsFramesUntilThen() {
        var m = model(fade: 3)
        var frame = run(&m, from: 0, to: 2, at: .zero)
        XCTAssertEqual(frame.level, 1, accuracy: 1e-6)
        XCTAssertTrue(m.needsFrames, "the timer needs frames to run")
        frame = run(&m, from: 2, to: 5, at: .zero)
        XCTAssertEqual(frame.level, 0, accuracy: 1e-3)
        XCTAssertFalse(m.needsFrames, "once faded nothing animates, so the display link may pause")
    }

    func testMovingBringsItBackQuickly() {
        var m = model(fade: 2)
        _ = run(&m, from: 0, to: 4, at: .zero)
        let frame = run(&m, from: 4, to: 4.3, at: CGPoint(x: 100, y: 100))
        XCTAssertGreaterThan(frame.level, 0.95)
    }

    func testClickCountsAsActivity() {
        var m = model(fade: 2)
        _ = run(&m, from: 0, to: 1.9, at: .zero)
        m.mouseDown(.left, at: 1.9)
        let frame = run(&m, from: 1.9, to: 3.5, at: .zero)
        XCTAssertGreaterThan(frame.level, 0.9, "the click restarted the stillness timer")
    }

    func testLaserNeverFades() {
        var options = HighlightOptions()
        options.fadeAfterStill = 1
        var laser = HighlightModel(style: .comet, pointer: .zero, look: HighlightLook(options: options), laser: true)
        laser.setHighlight(true, at: 0, pointer: .zero)
        var frame = laser.step(pointer: .zero, time: 0)
        var t = 0.0
        while t < 6 { t += 1.0 / 60; frame = laser.step(pointer: .zero, time: t) }
        XCTAssertEqual(frame.level, 1, accuracy: 1e-6)
    }
}

final class HideRulesTests: XCTestCase {
    func testNothingHidesByDefault() {
        XCTAssertNil(HideRules().reason(frontBundleID: "com.apple.QuickTimePlayerX", frontIsFullScreen: true))
    }

    func testFullScreenRule() {
        let rules = HideRules(fullScreenApps: true)
        XCTAssertEqual(rules.reason(frontBundleID: "com.apple.Safari", frontIsFullScreen: true), .fullScreen)
        XCTAssertNil(rules.reason(frontBundleID: "com.apple.Safari", frontIsFullScreen: false))
    }

    func testVideoRuleMatchesPlayersOnly() {
        let rules = HideRules(videoPlayers: true)
        XCTAssertEqual(rules.reason(frontBundleID: "org.videolan.vlc", frontIsFullScreen: false), .videoPlayer)
        XCTAssertNil(rules.reason(frontBundleID: "com.apple.Safari", frontIsFullScreen: false))
        XCTAssertNil(rules.reason(frontBundleID: nil, frontIsFullScreen: false))
    }

    func testFullScreenDetection() {
        let display = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let full = WindowSnapshot(ownerPID: 7, layer: 0, bounds: display)
        let normal = WindowSnapshot(ownerPID: 7, layer: 0, bounds: CGRect(x: 100, y: 80, width: 1000, height: 700))
        let menuBarExcluded = WindowSnapshot(ownerPID: 7, layer: 0, bounds: CGRect(x: 0, y: 38, width: 1728, height: 1079))
        let otherApp = WindowSnapshot(ownerPID: 9, layer: 0, bounds: display)
        let overlay = WindowSnapshot(ownerPID: 7, layer: 1000, bounds: display)
        XCTAssertTrue(FullScreenDetector.isFullScreen(pid: 7, windows: [normal, full], displays: [display]))
        XCTAssertFalse(FullScreenDetector.isFullScreen(pid: 7, windows: [normal, menuBarExcluded], displays: [display]), "a maximized window under the menu bar is not full screen")
        XCTAssertFalse(FullScreenDetector.isFullScreen(pid: 7, windows: [otherApp, overlay], displays: [display]))
        let second = CGRect(x: 1728, y: 0, width: 1920, height: 1080)
        XCTAssertTrue(FullScreenDetector.isFullScreen(pid: 7, windows: [WindowSnapshot(ownerPID: 7, layer: 0, bounds: second)], displays: [display, second]))
    }
}
