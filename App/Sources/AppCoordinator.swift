import AppKit
import BeaconCore

/// Owns the live pieces (overlays, pointer and button tracking, the highlight, cursor size).
@MainActor
final class AppCoordinator {
    private static let styleKey = "highlightStyle"
    private static let ripplesKey = "clickRipples"

    private let overlays = OverlayManager(screens: SystemScreens())
    private let tracker = CursorTracker()
    private let clicks = ClickMonitor()
    private var shake = ShakeRecognizer(sensitivity: 50)
    private let defaults: UserDefaults
    let highlight: HighlightController
    let cursorSize: CursorSizeController

    /// Called after the cursor size changes, so the menu can refresh its checkmark.
    var onSizeChange: (() -> Void)?

    init(cursorSize: CursorSizeController, defaults: UserDefaults = .standard) {
        self.cursorSize = cursorSize
        self.defaults = defaults
        let style = defaults.string(forKey: Self.styleKey).flatMap(HighlightStyle.init(rawValue:)) ?? .aura
        let ripples = defaults.object(forKey: Self.ripplesKey) as? Bool ?? true
        highlight = HighlightController(overlays: overlays, style: style, ripplesEnabled: ripples)
    }

    func start() {
        overlays.start()
        highlight.start()
        tracker.onMove = { [weak self] position, time in
            self?.pointerMoved(to: position, at: time)
        }
        tracker.start()
        clicks.onButton = { [weak self] button, isDown, position in
            self?.highlight.mouseButton(button, isDown: isDown, at: position)
        }
        clicks.start()
    }

    private func pointerMoved(to position: CGPoint, at time: TimeInterval) {
        highlight.pointerMoved()
        if shake.feed(position: position, time: time) {
            highlight.toggle()
        }
    }

    func toggleHighlight() {
        highlight.toggle()
    }

    /// Picking a style also turns the highlight on, so the choice is visible right away.
    func setHighlightStyle(_ style: HighlightStyle) {
        highlight.setStyle(style)
        highlight.setOn(true)
        defaults.set(style.rawValue, forKey: Self.styleKey)
    }

    func setClickRipples(_ enabled: Bool) {
        highlight.setRipplesEnabled(enabled)
        defaults.set(enabled, forKey: Self.ripplesKey)
    }

    func setCursorScale(_ scale: Float) {
        cursorSize.apply(scale)
        onSizeChange?()
    }

    func resetCursorScale() {
        cursorSize.reset()
        onSizeChange?()
    }

    func shutdown() {
        cursorSize.reset()
        tracker.onMove = nil
        tracker.stop()
        clicks.onButton = nil
        clicks.stop()
        highlight.stop()
        overlays.stop()
    }
}
