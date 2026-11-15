import AppKit
import CursorlightCore
import SwiftUI

@main
struct CursorlightApp: App {
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
    private var toolbar: ToolbarController?
    private var timer: TimerController?
    private var keystrokes: KeystrokeController?
    var debugInkActive: Bool { coordinator?.ink.isActive ?? false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["CURSORLIGHT_DEBUG_EVENTS"] == "1" {
            // Diagnostic only: appends every mouse and scroll event the app receives, and main-thread stalls, to a file.
            let path = "/tmp/cursorlight-events.log"
            FileManager.default.createFile(atPath: path, contents: nil)
            let handle = FileHandle(forWritingAtPath: path)
            func write(_ text: String) {
                handle?.seekToEndOfFile()
                handle?.write(Data((text + "\n").utf8))
            }
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
                if now - last > 0.5 { write("STALL \(String(format: "%.2f", now - last))s") }
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
            self.toolbar = ToolbarController(model: model)
            let timer = TimerController(model: model)
            self.timer = timer
            self.keystrokes = KeystrokeController(coordinator: coordinator, model: model)
            model.toggleTimer = { [weak timer] in timer?.toggle() }
            coordinator.onToggleTimer = { [weak timer] in timer?.toggle() }
            coordinator.onTimerLink = { [weak timer] command in timer?.run(command) }
            statusItemController.install(model: model)
            if environment.opensSettingsAtLaunch {
                windows.showSettings(environment.launchPage.flatMap(SettingsPage.init(rawValue:)) ?? .highlight)
            } else if !coordinator.settings.settings.welcomeSeen && !environment.isAgentMode {
                // Shown once. Counting it as seen when it opens means an unfinished guide never pops up again on its own.
                windows.showWelcome()
                coordinator.markWelcomeSeen()
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

    /// `cursorlight://` links from Stream Deck, Raycast, Shortcuts, scripts and the Terminal.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let command = CursorlightLink.parse(url) { coordinator?.runLink(command) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.shutdown()
    }
}
