import AppKit
import BeaconCore

/// Owns the live pieces (overlays, pointer tracking, skin drawing) and the temporary skin trial.
@MainActor
final class AppCoordinator {
    static let trialDuration: TimeInterval = 10

    private let overlays = OverlayManager(screens: SystemScreens())
    private let tracker = CursorTracker()
    private let hider: CursorHider
    private let renderer: SkinRenderer
    private var trialTimer: Timer?

    private(set) var trialSkinID: String?
    /// Called after a trial starts or ends, so the menu can refresh its checkmark.
    var onTrialChange: (() -> Void)?

    init(hider: CursorHider) {
        self.hider = hider
        renderer = SkinRenderer(hider: hider, tracker: tracker, overlays: overlays)
    }

    func start() {
        overlays.start()
    }

    /// Shows `skin` for `trialDuration` seconds, then restores the real cursor. Replaces any running trial.
    func tryTrial(_ skin: Skin) {
        trialTimer?.invalidate()
        renderer.apply(skin, sizeMultiplier: 1)
        trialSkinID = skin.id
        let timer = Timer(timeInterval: Self.trialDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.restoreCursor() }
        }
        // Common modes so the restore still fires while a menu is being tracked.
        RunLoop.main.add(timer, forMode: .common)
        trialTimer = timer
        onTrialChange?()
    }

    /// Restores the real cursor immediately. Safe to call at any time.
    func restoreCursor() {
        trialTimer?.invalidate()
        trialTimer = nil
        renderer.stop()
        hider.restore()
        trialSkinID = nil
        onTrialChange?()
    }

    func shutdown() {
        restoreCursor()
        tracker.stop()
        overlays.stop()
    }
}
