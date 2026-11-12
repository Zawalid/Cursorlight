import AppKit
import BeaconCore
import SwiftUI

/// Visual check without a screen: with BEACON_SNAPSHOT_DIR set, renders each page to a PNG there and quits.
/// Needs no Screen Recording permission because nothing is captured from the screen.
@MainActor
enum SnapshotRunner {
    static var directory: String? { ProcessInfo.processInfo.environment["BEACON_SNAPSHOT_DIR"] }

    static func run(into directory: String) {
        let suite = "beacon.snapshot.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        let coordinator = AppCoordinator(
            cursorSize: CursorSizeController(scaling: SystemCursorScale(), markers: UserDefaultsScaleMarker(defaults: defaults)),
            settings: SettingsStore(defaults: defaults)
        )
        coordinator.setAppRule(AppRule(bundleID: "us.zoom.xos", appName: "Zoom", profileID: "meeting"))
        coordinator.setAppRule(AppRule(bundleID: "com.apple.iWork.Keynote", appName: "Keynote", profileID: nil))
        let model = AppModel(coordinator: coordinator, updater: AppUpdater(startingUpdater: false))
        for page in SettingsPage.allCases {
            render(SettingsView(page: page, scrolls: false).environmentObject(model).frame(width: 940, height: 900), name: "settings-\(page.rawValue)", into: directory)
        }
        render(PopoverView().environmentObject(model), name: "popover", into: directory)
        render(FirstRunView(finish: {}).environmentObject(model), name: "firstrun", into: directory)
        defaults.removePersistentDomain(forName: suite)
    }

    private static func render<V: View>(_ view: V, name: String, into directory: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { NSLog("snapshot failed: \(name)"); return }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
}
