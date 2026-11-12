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
    var debugInkActive: Bool { coordinator?.ink.isActive ?? false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["BEACON_DEBUG_EVENTS"] == "1" {
            // Diagnostic only: appends every mouse and scroll event the app receives, and main-thread stalls, to a file.
            FileManager.default.createFile(atPath: "/tmp/beacon-events.log", contents: nil)
            func write(_ text: String) { DebugLog.write(text) }
            write("started")
            NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .scrollWheel, .rightMouseDown]) { event in
                let hit = event.window?.contentView?.hitTest(event.locationInWindow)
                let ink = (NSApp.delegate as? AppDelegate)?.debugInkActive ?? false
                write("event \(event.type.rawValue) modal=\(NSApp.modalWindow != nil) keyWin=\(NSApp.keyWindow?.title ?? "none") window=\(event.window?.title ?? "none") key=\(event.window?.isKeyWindow ?? false) active=\(NSApp.isActive) ink=\(ink) hit=\(hit.map { String(describing: type(of: $0)) } ?? "nil")")
                return event
            }
            var last = ProcessInfo.processInfo.systemUptime
            Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                let now = ProcessInfo.processInfo.systemUptime
                if now - last > 0.08 { write("STALL \(String(format: "%.2f", now - last))s") }
                last = now
            }
        }
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

    /// Opening the app again (Finder, `open`, the Dock) shows the settings window on the current Space.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows?.showSettings(.highlight)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.shutdown()
    }
}
