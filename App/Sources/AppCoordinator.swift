import AppKit
import BeaconCore

/// Owns the live pieces (overlays, cursor size).
@MainActor
final class AppCoordinator {
    private let overlays = OverlayManager(screens: SystemScreens())
    private let tracker = CursorTracker()
    let cursorSize: CursorSizeController

    /// Called after the cursor size changes, so the menu can refresh its checkmark.
    var onSizeChange: (() -> Void)?

    init(cursorSize: CursorSizeController) {
        self.cursorSize = cursorSize
    }

    func start() {
        overlays.start()
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
        tracker.stop()
        overlays.stop()
    }
}
