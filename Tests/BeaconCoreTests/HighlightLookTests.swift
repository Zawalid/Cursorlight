import XCTest
@testable import BeaconCore

final class HighlightLookTests: XCTestCase {
    func testStandardLookLeavesRecipesUnchanged() {
        for style in HighlightStyle.allCases {
            XCTAssertEqual(style.recipe.applying(.standard), style.recipe)
        }
    }

    func testSizeScalesRadiiButNotTiming() {
        let look = HighlightLook(size: 1.5)
        let base = HighlightStyle.aura.recipe
        let scaled = base.applying(look)
        XCTAssertEqual(scaled.aura.radius, base.aura.radius * 1.5, accuracy: 0.001)
        XCTAssertEqual(scaled.appearDuration, base.appearDuration)
        XCTAssertEqual(scaled.spring, base.spring)
        XCTAssertEqual(scaled.pulse?.endRadius ?? 0, (base.pulse?.endRadius ?? 0) * 1.5, accuracy: 0.001)
        XCTAssertEqual(HighlightStyle.lens.recipe.applying(look).lens.radius, 180, accuracy: 0.001)
    }

    func testLensDimComesFromLook() {
        let recipe = HighlightStyle.lens.recipe.applying(HighlightLook(lensDim: 0.7))
        XCTAssertEqual(recipe.lens.dim, 0.7, accuracy: 0.0001)
    }

    func testValuesAreClamped() {
        let look = HighlightLook(size: 99, intensity: -4, lensDim: .nan)
        XCTAssertEqual(Double(look.size), HighlightLook.sizeRange.upperBound, accuracy: 0.0001)
        XCTAssertEqual(Double(look.intensity), HighlightLook.intensityRange.lowerBound, accuracy: 0.0001)
        XCTAssertEqual(look.lensDim, 0.5, accuracy: 0.0001)
    }

    func testHighContrastForcesFullIntensity() {
        XCTAssertEqual(HighlightLook(accent: .highContrast, intensity: 0.4).intensity, 1)
    }

    func testAccentFallsBackToStyleColor() {
        XCTAssertEqual(HighlightLook.standard.accentColor(for: .sonar), Palette.accent(for: .sonar))
        XCTAssertEqual(HighlightLook(accent: .blue).accentColor(for: .sonar), RGBA(hex: "#4DA3FF"))
    }

    func testLaserRecipeHasLongTrailAndNoRipples() {
        let laser = StyleRecipe.laser
        XCTAssertGreaterThan(laser.comet.lifetime, StyleRecipe.recipe(for: .comet).comet.lifetime)
        XCTAssertEqual(laser.ripple.maxConcurrent, 0)
        XCTAssertNil(laser.pulse)
    }

    func testLaserSpecUsesLaserColorUnlessChosen() {
        XCTAssertEqual(RenderSpec(laserLook: .standard).accent, Palette.laserDefault)
        XCTAssertEqual(RenderSpec(laserLook: HighlightLook(accent: .teal)).accent, RGBA(hex: "#14B8A6"))
    }
}

final class LaserModelTests: XCTestCase {
    private func run(_ model: inout HighlightModel, seconds: Double) -> HighlightFrame {
        var frame = model.step(pointer: .zero, time: 0)
        var t = 0.0
        while t < seconds {
            t += 1.0 / 120
            frame = model.step(pointer: CGPoint(x: t * 600, y: 0), time: t)
        }
        return frame
    }

    func testLaserModelIsAlwaysCometAndIgnoresStyleChanges() {
        var model = HighlightModel(style: .aura, look: .standard, laser: true)
        XCTAssertEqual(model.style, .comet)
        model.setStyle(.lens, at: 0)
        XCTAssertEqual(model.style, .comet)
        XCTAssertFalse(model.ripplesEnabled)
    }

    func testLaserTrailIsLongerThanCometTrail() {
        var laser = HighlightModel(style: .comet, look: .standard, laser: true)
        var comet = HighlightModel(style: .comet)
        laser.setHighlight(true, at: 0, pointer: .zero)
        comet.setHighlight(true, at: 0, pointer: .zero)
        let a = run(&laser, seconds: 1.0)
        let b = run(&comet, seconds: 1.0)
        let lengthA = (a.trail.first.map { a.center.x - $0.point.x }) ?? 0
        let lengthB = (b.trail.first.map { b.center.x - $0.point.x }) ?? 0
        XCTAssertGreaterThan(lengthA, lengthB * 1.5)
    }

    func testSetLookChangesRecipeWithoutTurningOff() {
        var model = HighlightModel(style: .aura)
        model.setHighlight(true, at: 0, pointer: .zero)
        model.setLook(HighlightLook(size: 1.5))
        XCTAssertTrue(model.isOn)
        XCTAssertEqual(model.recipe.aura.radius, StyleRecipe.recipe(for: .aura).aura.radius * 1.5, accuracy: 0.001)
    }
}
