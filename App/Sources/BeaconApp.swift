import AppKit
import BeaconCore
import SwiftUI

@main
struct BeaconApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let environment = AppEnvironment()
    private let statusItemController = StatusItemController()
    private let cursorMarker = UserDefaultsCursorMarker()
    private lazy var cursorHider: CursorHider = CursorHiders.makeDefault(markers: cursorMarker)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Before anything else: a previous run that died with the cursor hidden left the marker set.
        CursorRecovery.restoreIfStale(markers: cursorMarker, hider: cursorHider)
        statusItemController.install()
        // Launch-at-login and Sparkle are added in later tasks; both are gated
        // on environment.allowsLaunchAtLogin / environment.allowsUpdater.
    }

    func applicationWillTerminate(_ notification: Notification) {
        cursorHider.restore()
    }
}
