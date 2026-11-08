import AppKit
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController.install()
        // Launch-at-login and Sparkle are added in later tasks; both are gated
        // on environment.allowsLaunchAtLogin / environment.allowsUpdater.
    }
}
