import AppKit
import BeaconCore

/// Owns the live pieces (overlays, pointer tracking, effects, cursor size).
@MainActor
final class AppCoordinator {
    private static let themeKey = "haloTheme"

    private let overlays = OverlayManager(screens: SystemScreens())
    private let tracker = CursorTracker()
    private var shake = ShakeRecognizer(sensitivity: 50)
    private let defaults: UserDefaults
    let effects: EffectEngine
    let cursorSize: CursorSizeController

    /// Called after the cursor size changes, so the menu can refresh its checkmark.
    var onSizeChange: (() -> Void)?

    init(cursorSize: CursorSizeController, defaults: UserDefaults = .standard) {
        self.cursorSize = cursorSize
        self.defaults = defaults
        effects = EffectEngine(overlays: overlays, tracker: tracker)
        if let id = defaults.string(forKey: Self.themeKey), let theme = Theme.named(id) {
            effects.theme = theme
        }
    }

    func start() {
        overlays.start()
        tracker.onMove = { [weak self] position, time in
            self?.pointerMoved(to: position, at: time)
        }
        tracker.start()
    }

    private func pointerMoved(to position: CGPoint, at time: TimeInterval) {
        effects.pointerMoved(to: position, at: time)
        if shake.feed(position: position, time: time) {
            effects.activate(.beacon)
        }
    }

    /// From the menu: the tracker may not have seen the latest position while the menu was open.
    func showHalo() {
        effects.activate(.beacon)
        effects.pointerMoved(to: NSEvent.mouseLocation, at: ProcessInfo.processInfo.systemUptime)
    }

    var haloTheme: Theme { effects.theme }

    func setHaloTheme(_ theme: Theme) {
        effects.theme = theme
        defaults.set(theme.id, forKey: Self.themeKey)
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
        effects.deactivateAll()
        overlays.stop()
    }
}
