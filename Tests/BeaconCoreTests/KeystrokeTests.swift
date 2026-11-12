import XCTest
@testable import BeaconCore

final class KeystrokeTests: XCTestCase {
    private let cmd: UInt = 1 << 20, shift: UInt = 1 << 17, opt: UInt = 1 << 19, ctrl: UInt = 1 << 18

    private func press(_ code: UInt16, _ chars: String, _ flags: UInt = 0, repeatKey: Bool = false) -> KeyPress {
        KeyPress(keyCode: code, flags: flags, characters: chars, isRepeat: repeatKey)
    }

    func testShortcutLabelsPutModifiersFirst() {
        XCTAssertEqual(KeystrokeFormatter.label(for: press(40, "k", cmd)), "⌘ K")
        XCTAssertEqual(KeystrokeFormatter.label(for: press(0, "a", ctrl | opt | shift | cmd)), "⌃⌥⇧⌘ A")
        XCTAssertEqual(KeystrokeFormatter.label(for: press(36, "\r")), "Return")
        XCTAssertEqual(KeystrokeFormatter.label(for: press(123, "", cmd)), "⌘ ←")
        XCTAssertNil(KeystrokeFormatter.label(for: press(200, "")))
    }

    func testShiftAloneIsTypingNotAShortcut() {
        XCTAssertFalse(KeystrokeFormatter.isShortcut(press(0, "A", shift)))
        XCTAssertTrue(KeystrokeFormatter.isShortcut(press(0, "a", cmd)))
    }

    func testShortcutsOnlyIgnoresTyping() {
        var b = KeystrokeBuffer()
        b.push(press(0, "a"), shortcutsOnly: true, at: 0)
        XCTAssertTrue(b.entries.isEmpty)
        b.push(press(40, "k", cmd), shortcutsOnly: true, at: 0.1)
        XCTAssertEqual(b.entries.map(\.text), ["⌘ K"])
    }

    func testTypingJoinsIntoAWordAndSpecialKeysStartANewChip() {
        var b = KeystrokeBuffer()
        for (i, ch) in ["h", "e", "l", "l", "o"].enumerated() { b.push(press(UInt16(i), ch), shortcutsOnly: false, at: Double(i) * 0.1) }
        XCTAssertEqual(b.entries.map(\.text), ["hello"])
        b.push(press(36, "\r"), shortcutsOnly: false, at: 0.6)
        XCTAssertEqual(b.entries.map(\.text), ["hello", "Return"])
        b.push(press(0, "a"), shortcutsOnly: false, at: 0.7)
        XCTAssertEqual(b.entries.map(\.text), ["hello", "Return", "a"])
    }

    func testEntriesFadeAndExpire() {
        var b = KeystrokeBuffer()
        b.push(press(40, "k", cmd), shortcutsOnly: true, at: 0)
        XCTAssertEqual(b.visible(at: 0.5).first?.opacity, 1)
        let fading = b.visible(at: 1.6).first?.opacity ?? 2
        XCTAssertLessThan(fading, 1)
        XCTAssertGreaterThan(fading, 0)
        XCTAssertTrue(b.visible(at: 2).isEmpty)
    }

    func testOnlyFourEntriesAreKept() {
        var b = KeystrokeBuffer()
        for i in 0..<8 { b.push(press(UInt16(i), "k", cmd), shortcutsOnly: true, at: Double(i) * 0.05) }
        XCTAssertEqual(b.entries.count, KeystrokeBuffer.maxEntries)
    }

    func testHideWhileTypingFadesUntilThePointerMoves() {
        var o = HighlightOptions(); o.hideWhileTyping = true
        var m = HighlightModel(style: .keyline, pointer: .zero, look: HighlightLook(options: o))
        m.setHighlight(true, at: 0, pointer: .zero)
        var t = 0.0
        var frame = m.step(pointer: .zero, time: t)
        while t < 0.6 { t += 1.0 / 60; frame = m.step(pointer: .zero, time: t) }
        XCTAssertEqual(frame.level, 1, accuracy: 1e-6)
        m.typed()
        while t < 1.8 { t += 1.0 / 60; frame = m.step(pointer: .zero, time: t) }
        XCTAssertEqual(frame.level, 0, accuracy: 1e-3)
        XCTAssertFalse(m.needsFrames)
        while t < 2.1 { t += 1.0 / 60; frame = m.step(pointer: CGPoint(x: 80, y: 40), time: t) }
        XCTAssertGreaterThan(frame.level, 0.9)
    }

    func testTypingDoesNothingWhenTheOptionIsOff() {
        var m = HighlightModel(style: .keyline, pointer: .zero)
        m.setHighlight(true, at: 0, pointer: .zero)
        var t = 0.0
        var frame = m.step(pointer: .zero, time: t)
        while t < 0.6 { t += 1.0 / 60; frame = m.step(pointer: .zero, time: t) }
        m.typed()
        while t < 2 { t += 1.0 / 60; frame = m.step(pointer: .zero, time: t) }
        XCTAssertEqual(frame.level, 1, accuracy: 1e-6)
    }

    func testSettingsRoundTrip() throws {
        var s = BeaconSettings.defaults
        s.keystrokes.enabled = true
        s.keystrokes.shortcutsOnly = false
        s.keystrokes.position = .bottomRight
        s.highlightOptions.hideWhileTyping = true
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded.keystrokes.position, .bottomRight)
        XCTAssertFalse(decoded.keystrokes.shortcutsOnly)
        XCTAssertTrue(decoded.highlightOptions.hideWhileTyping)
        XCTAssertFalse(BeaconSettings.defaults.keystrokes.enabled)
    }
}
