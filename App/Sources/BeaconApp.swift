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
    private var model: AppModel?
    private var windows: WindowControllers?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ClickSelfTest.isRequested {
            ClickSelfTest.run()
            NSApp.terminate(nil)
            return
        }
        if let directory = SnapshotRunner.directory {
            SnapshotRunner.run(into: directory)
            NSApp.terminate(nil)
            return
        }
        if environment.startsCoordinator {
            // Before anything else: a previous run that died with the cursor resized left the marker set.
            cursorSize.restoreIfStale()
            let coordinator = AppCoordinator(cursorSize: cursorSize)
            coordinator.start()
            self.coordinator = coordinator
            let updater = AppUpdater(startingUpdater: environment.allowsUpdater)
            let model = AppModel(coordinator: coordinator, updater: updater)
            let windows = WindowControllers(model: model)
            self.model = model
            self.windows = windows
            statusItemController.install(model: model)
            if environment.opensSettingsAtLaunch {
                windows.showSettings(.highlight)
            } else if !coordinator.settings.settings.welcomeSeen && !environment.isAgentMode {
                windows.showWelcome()
            }
        } else {
            statusItemController.install(model: nil)
        }
        // Launch-at-login and Sparkle are added in later tasks; both are gated
        // on environment.allowsLaunchAtLogin / environment.allowsUpdater.
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.shutdown()
    }
}
