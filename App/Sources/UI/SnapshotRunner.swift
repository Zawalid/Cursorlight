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
            renderWindowed(SettingsView(page: page).environmentObject(model), size: CGSize(width: 1040, height: 720), name: "settings-\(page.rawValue)", into: directory)
        }
        render(PopoverView().environmentObject(model), name: "popover", into: directory)
        for step in 0..<3 {
            render(FirstRunView(startAt: step, finish: {}).environmentObject(model), name: "firstrun-\(step + 1)", into: directory)
        }
        defaults.removePersistentDomain(forName: suite)
    }

    /// Renders in a real but never-shown window, so native controls (switch, slider, menus) draw as they do on screen.
    private static func renderWindowed<V: View>(_ view: V, size: CGSize, name: String, into directory: String) {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        window.close()
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
