import AppKit
import BeaconCore

/// Owns the live pieces (overlays, pointer and button tracking, the highlight, cursor size).
@MainActor
final class AppCoordinator {
    private let overlays = OverlayManager(screens: SystemScreens())
    private let tracker = CursorTracker()
    private let clicks = ClickMonitor()
    private var shake: ShakeRecognizer
    let settings: SettingsStore
    let highlight: HighlightController
    let cursorSize: CursorSizeController

    /// Called after the cursor size changes, so the menu can refresh its checkmark.
    var onSizeChange: (() -> Void)?

    init(cursorSize: CursorSizeController, settings: SettingsStore = SettingsStore()) {
        self.cursorSize = cursorSize
        self.settings = settings
        let current = settings.settings
        shake = ShakeRecognizer(sensitivity: current.shakeSensitivity)
        highlight = HighlightController(
            overlays: overlays,
            style: current.highlightStyle,
            ripplesEnabled: current.clickRipples
        )
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

    func setShakeSensitivity(_ value: Double) {
        settings.update { $0.shakeSensitivity = value }
        shake = ShakeRecognizer(sensitivity: settings.settings.shakeSensitivity)
    }

    func toggleHighlight() {
        highlight.toggle()
    }

    /// Picking a style also turns the highlight on, so the choice is visible right away.
    func setHighlightStyle(_ style: HighlightStyle) {
        highlight.setStyle(style)
        highlight.setOn(true)
        settings.update { $0.highlightStyle = style }
    }

    func setClickRipples(_ enabled: Bool) {
        highlight.setRipplesEnabled(enabled)
        settings.update { $0.clickRipples = enabled }
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
