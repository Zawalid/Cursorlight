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

final class PenWidthTests: XCTestCase {
    func testStrokeCarriesItsWidthScale() {
        var model = InkModel()
        model.begin(at: .zero, style: .marker, color: .red, widthScale: 2)
        model.append(CGPoint(x: 30, y: 0))
        let frame = model.step(time: 0)
        XCTAssertEqual(frame.strokes.first?.widthScale, 2)
    }

    func testPenWidthSurvivesSettingsAndSnapshot() throws {
        var settings = BeaconSettings.defaults
        settings.inkWidth = 1.8
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.inkWidth, 1.8)
        XCTAssertEqual(decoded.snapshot.inkWidth, 1.8)
        settings.inkWidth = 99
        XCTAssertEqual(settings.sanitized().inkWidth, BeaconSettings.inkWidthRange.upperBound)
    }
}

final class InkChoicesTests: XCTestCase {
    private func circle() -> [CGPoint] {
        (0..<64).map { i in
            let a = 2 * Double.pi * Double(i) / 63
            return CGPoint(x: 200 + 80 * cos(a), y: 200 + 80 * sin(a))
        }
    }

    private func draw(_ model: inout InkModel, _ points: [CGPoint]) {
        model.begin(at: points[0], style: .marker, color: .red)
        for p in points.dropFirst() { model.append(p) }
        model.end(at: 1)
    }

    func testDisabledShapeIsNotCleanedUp() {
        var on = InkModel()
        draw(&on, circle())
        XCTAssertNotNil(on.strokes.last?.morphTo)
        var off = InkModel()
        off.enabledShapes = [.rectangle, .arrow]
        draw(&off, circle())
        XCTAssertNil(off.strokes.last?.morphTo, "circles are switched off, so the raw stroke stays")
    }

    func testStrokesStayWhenFadeIsOff() {
        var model = InkModel()
        model.fades = false
        draw(&model, circle())
        let frame = model.step(time: 1000)
        XCTAssertEqual(frame.strokes.first?.alpha, 1)
        var fading = InkModel()
        draw(&fading, circle())
        XCTAssertTrue(fading.step(time: 1000).strokes.isEmpty)
    }

    func testMoreColorsAndStyles() {
        XCTAssertEqual(InkColor.allCases.count, 8)
        XCTAssertEqual(Set(InkColor.allCases.map(\.rawValue)).count, 8)
        XCTAssertNotNil(InkStyle.dashed.dash)
        XCTAssertFalse(InkStyle.dashed.hasKeyline)
        XCTAssertLessThan(InkStyle.pencil.width, InkStyle.marker.width)
    }

    func testShapeSetRoundTrips() throws {
        var settings = BeaconSettings.defaults
        settings.inkShapes = [.ellipse, .arrow]
        settings.inkFades = false
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.inkShapes, [.ellipse, .arrow])
        XCTAssertFalse(decoded.inkFades)
        XCTAssertEqual(decoded.snapshot.inkShapes, [.ellipse, .arrow])
    }
}

final class ToolbarSettingsTests: XCTestCase {
    func testIsOffByDefaultAndHiddenFromViewers() {
        let t = ToolbarSettings()
        XCTAssertFalse(t.enabled)
        XCTAssertTrue(t.hiddenFromViewers)
        XCTAssertFalse(t.isShown(effectRunning: true))
    }

    func testVisibilityRules() {
        var t = ToolbarSettings()
        t.enabled = true
        XCTAssertTrue(t.isShown(effectRunning: false))
        t.visibility = .whileEffectOn
        XCTAssertFalse(t.isShown(effectRunning: false))
        XCTAssertTrue(t.isShown(effectRunning: true))
    }

    func testRoundTripKeepsPosition() throws {
        var settings = BeaconSettings.defaults
        settings.toolbar.enabled = true
        settings.toolbar.originX = 120
        settings.toolbar.originY = 48
        settings.toolbar.collapsed = true
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.toolbar.origin, CGPoint(x: 120, y: 48))
        XCTAssertTrue(decoded.toolbar.collapsed)
        XCTAssertNil(ToolbarSettings().origin)
    }

    func testShortcutDefaultAndRouting() {
        XCTAssertEqual(TriggerSettings().hotkey(for: .toggleToolbar)?.displayString, "⌃⌥B")
        XCTAssertEqual(TriggerRouter(settings: TriggerSettings()).route(.hotkey(.toggleToolbar), active: .init()), [.toggleToolbar])
    }
}

final class CustomColorTests: XCTestCase {
    func testCustomAccentDrawsInTheChosenColor() {
        var options = HighlightOptions()
        options.customAccent = "#12AB34"
        let look = HighlightLook(accent: .custom, options: options)
        XCTAssertEqual(look.accentColor(for: .comet).hexString, "#12AB34")
        XCTAssertEqual(look.resolvedAccent?.hexString, "#12AB34")
        XCTAssertEqual(HighlightLook(accent: .coral).accentColor(for: .comet), Palette.accent(for: .comet) == RGBA(hex: Branding.accentHex) ? Palette.accent(for: .comet) : RGBA(hex: Branding.accentHex))
        XCTAssertNil(HighlightLook(accent: .styleDefault).resolvedAccent)
    }

    func testHexHelpers() {
        XCTAssertTrue(RGBA.isValidHex("#a1B2c3"))
        XCTAssertTrue(RGBA.isValidHex("A1B2C3"))
        XCTAssertFalse(RGBA.isValidHex("#12345"))
        XCTAssertFalse(RGBA.isValidHex("#GGGGGG"))
        XCTAssertEqual(RGBA(hex: "#336699").hexString, "#336699")
    }

    func testBadCustomAccentFallsBack() {
        var options = HighlightOptions()
        options.customAccent = "nope"
        XCTAssertEqual(options.sanitized().customAccent, HighlightOptions().customAccent)
    }

    func testCustomPenColorTravelsWithTheStroke() {
        var model = InkModel()
        model.begin(at: .zero, style: .marker, color: .red, customColor: RGBA(hex: "#0099FF"))
        model.append(CGPoint(x: 30, y: 0))
        XCTAssertEqual(model.step(time: 0).strokes.first?.rgba.hexString, "#0099FF")
        var plain = InkModel()
        plain.begin(at: .zero, style: .marker, color: .red)
        plain.append(CGPoint(x: 30, y: 0))
        XCTAssertEqual(plain.step(time: 0).strokes.first?.rgba, InkColor.red.rgba)
    }

    func testPenAndAccentColorsSurviveSettingsRoundTrip() throws {
        var settings = BeaconSettings.defaults
        settings.accent = .custom
        settings.highlightOptions.customAccent = "#AA00FF"
        settings.inkCustom = "#00FFAA"
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.look.resolvedAccent?.hexString, "#AA00FF")
        XCTAssertEqual(decoded.penColor.hexString, "#00FFAA")
        XCTAssertEqual(decoded.snapshot.inkCustom, "#00FFAA")
        let scene = Profile(id: "x", name: "X", snapshot: decoded.snapshot)
        XCTAssertEqual(scene.penColor.hexString, "#00FFAA")
        XCTAssertEqual(scene.highlightColor.hexString, "#AA00FF")
    }
}
