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
    private let cursorSize = CursorSizeController(scaling: SystemCursorScale(), markers: UserDefaultsScaleMarker())
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if environment.startsCoordinator {
            // Before anything else: a previous run that died with the cursor resized left the marker set.
            cursorSize.restoreIfStale()
            let coordinator = AppCoordinator(cursorSize: cursorSize)
            coordinator.start()
            self.coordinator = coordinator
            statusItemController.coordinator = coordinator
        }
        statusItemController.install()
        // Launch-at-login and Sparkle are added in later tasks; both are gated
        // on environment.allowsLaunchAtLogin / environment.allowsUpdater.
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.shutdown()
    }
}
