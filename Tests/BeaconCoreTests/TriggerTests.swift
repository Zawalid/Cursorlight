import XCTest
@testable import BeaconCore

final class ModifierGestureTests: XCTestCase {
    private let option: UInt = 1 << 19
    private let control: UInt = 1 << 18
    private let l = ModifierKey.leftOption.rawValue
    private let r = ModifierKey.rightOption.rawValue

    private func tap(_ g: inout ModifierGestureRecognizer, key: UInt16, flag: UInt, at t: TimeInterval, length: TimeInterval = 0.08) -> [TriggerEvent] {
        g.flagsChanged(keyCode: key, flags: flag, time: t) + g.flagsChanged(keyCode: key, flags: 0, time: t + length)
    }

    func testDoubleTapWithinWindowFires() {
        var g = ModifierGestureRecognizer()
        XCTAssertEqual(tap(&g, key: l, flag: option, at: 0), [])
        XCTAssertEqual(tap(&g, key: l, flag: option, at: 0.25), [.doubleTap(.leftOption)])
    }

    func testSlowDoubleTapDoesNotFire() {
        var g = ModifierGestureRecognizer()
        _ = tap(&g, key: l, flag: option, at: 0)
        XCTAssertEqual(tap(&g, key: l, flag: option, at: 1.0), [])
    }

    func testTwoDifferentKeysDoNotMakeADoubleTap() {
        var g = ModifierGestureRecognizer()
        _ = tap(&g, key: l, flag: option, at: 0)
        XCTAssertEqual(tap(&g, key: r, flag: option, at: 0.2), [])
    }

    func testOptionPlusOtherKeyDoesNotFire() {
        var g = ModifierGestureRecognizer()
        _ = tap(&g, key: l, flag: option, at: 0)
        _ = g.flagsChanged(keyCode: l, flags: option, time: 0.2)
        g.otherInput()
        XCTAssertEqual(g.flagsChanged(keyCode: l, flags: 0, time: 0.25), [])
        XCTAssertEqual(tap(&g, key: l, flag: option, at: 0.3), [])
    }

    func testHoldBeginsAtDeadlineAndEndsOnRelease() {
        var g = ModifierGestureRecognizer()
        _ = g.flagsChanged(keyCode: r, flags: option, time: 1)
        XCTAssertEqual(g.holdDeadline ?? 0, 1.3, accuracy: 0.0001)
        XCTAssertEqual(g.tick(time: 1.1), [])
        XCTAssertEqual(g.tick(time: 1.31), [.holdBegan(.rightOption)])
        XCTAssertTrue(g.isHolding)
        XCTAssertEqual(g.flagsChanged(keyCode: r, flags: 0, time: 2), [.holdEnded(.rightOption)])
        XCTAssertFalse(g.isHolding)
    }

    func testClickWhileHoldingKeepsTheHold() {
        var g = ModifierGestureRecognizer()
        _ = g.flagsChanged(keyCode: r, flags: option, time: 0)
        _ = g.tick(time: 0.31)
        g.otherInput()
        XCTAssertTrue(g.isHolding)
        XCTAssertEqual(g.flagsChanged(keyCode: r, flags: 0, time: 3), [.holdEnded(.rightOption)])
    }

    func testClickBeforeHoldThresholdCancelsTheHold() {
        var g = ModifierGestureRecognizer()
        _ = g.flagsChanged(keyCode: r, flags: option, time: 0)
        g.otherInput()
        XCTAssertEqual(g.tick(time: 0.5), [])
        XCTAssertFalse(g.isHolding)
    }

    func testSecondModifierMakesItAShortcut() {
        var g = ModifierGestureRecognizer()
        _ = g.flagsChanged(keyCode: ModifierKey.leftControl.rawValue, flags: control, time: 0)
        _ = g.flagsChanged(keyCode: l, flags: control | option, time: 0.05)
        XCTAssertEqual(g.tick(time: 0.5), [])
        XCTAssertNil(g.holdDeadline)
    }

    func testResetReleasesARunningHold() {
        var g = ModifierGestureRecognizer()
        _ = g.flagsChanged(keyCode: r, flags: option, time: 0)
        _ = g.tick(time: 0.4)
        XCTAssertEqual(g.reset(), [.holdEnded(.rightOption)])
        XCTAssertEqual(g.reset(), [])
    }

    func testUnknownKeyCodeIsIgnored() {
        var g = ModifierGestureRecognizer()
        XCTAssertEqual(g.flagsChanged(keyCode: 99, flags: option, time: 0), [])
    }
}

final class TriggerRouterTests: XCTestCase {
    private func router(_ edit: (inout TriggerSettings) -> Void = { _ in }) -> TriggerRouter {
        var settings = TriggerSettings()
        edit(&settings)
        return TriggerRouter(settings: settings)
    }

    func testDefaultsMapShakeDoubleTapAndHold() {
        let r = router()
        XCTAssertEqual(r.route(.shake, active: .init()), [.toggle(.highlight)])
        XCTAssertEqual(r.route(.doubleTap(.leftOption), active: .init()), [.toggle(.laser)])
        XCTAssertEqual(r.route(.holdBegan(.rightOption), active: .init()), [.set(.ink, true)])
        XCTAssertEqual(r.route(.holdEnded(.rightOption), active: .init()), [.set(.ink, false)])
    }

    func testOtherKeysAreIgnored() {
        let r = router()
        XCTAssertEqual(r.route(.doubleTap(.rightOption), active: .init()), [])
        XCTAssertEqual(r.route(.holdBegan(.leftOption), active: .init()), [])
    }

    func testShakeWhileInkOrLaserIsActiveDoesNothing() {
        let r = router()
        XCTAssertEqual(r.route(.shake, active: .init(inkActive: true)), [])
        XCTAssertEqual(r.route(.shake, active: .init(laserOn: true)), [])
    }

    func testDisabledTriggersAreIgnoredButHoldAlwaysReleases() {
        let r = router { $0.shakeEnabled = false; $0.doubleTapEnabled = false; $0.holdEnabled = false }
        XCTAssertEqual(r.route(.shake, active: .init()), [])
        XCTAssertEqual(r.route(.doubleTap(.leftOption), active: .init()), [])
        XCTAssertEqual(r.route(.holdBegan(.rightOption), active: .init()), [])
        XCTAssertEqual(r.route(.holdEnded(.rightOption), active: .init()), [.set(.ink, false)])
    }

    func testPausedIgnoresEverythingExceptThePauseShortcut() {
        var r = router()
        r.isPaused = true
        XCTAssertEqual(r.route(.shake, active: .init()), [])
        XCTAssertEqual(r.route(.hotkey(.ink), active: .init()), [])
        XCTAssertEqual(r.route(.hotkey(.pause), active: .init()), [.togglePause])
    }

    func testHotkeysMapToToggles() {
        let r = router()
        XCTAssertEqual(r.route(.hotkey(.highlight), active: .init()), [.toggle(.highlight)])
        XCTAssertEqual(r.route(.hotkey(.laser), active: .init()), [.toggle(.laser)])
        XCTAssertEqual(r.route(.hotkey(.ink), active: .init()), [.toggle(.ink)])
        XCTAssertEqual(router { $0.hotkeysEnabled = false }.route(.hotkey(.ink), active: .init()), [])
    }

    func testNoneActionDoesNothing() {
        XCTAssertEqual(router { $0.shakeAction = .none }.route(.shake, active: .init()), [])
    }

    func testSettingsDecodeToleratesMissingFieldsAndShowKeyNames() throws {
        let decoded = try JSONDecoder().decode(TriggerSettings.self, from: Data(#"{"shakeEnabled":false}"#.utf8))
        XCTAssertFalse(decoded.shakeEnabled)
        XCTAssertEqual(decoded.holdKey, .rightOption)
        XCTAssertEqual(decoded.hotkey(for: .ink)?.displayString, "⌃⌥I")
    }
}
