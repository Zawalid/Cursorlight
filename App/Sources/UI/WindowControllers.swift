import AppKit
import BeaconCore
import SwiftUI

/// Owns the settings window and the welcome window. Both are plain titled windows hosting SwiftUI.
@MainActor
final class WindowControllers {
    private let model: AppModel
    private var settings: NSWindow?
    private var welcome: NSWindow?

    init(model: AppModel) {
        self.model = model
        model.openSettings = { [weak self] page in self?.showSettings(page) }
        model.openWelcome = { [weak self] in self?.showWelcome() }
    }

    func showSettings(_ page: SettingsPage) {
        let root = SettingsView(page: page).environmentObject(model)
        if let window = settings {
            window.contentViewController = NSHostingController(rootView: root)
        } else {
            let window = Self.makeWindow(size: NSSize(width: 940, height: 680), resizable: true)
            window.title = Branding.appName
            window.contentViewController = NSHostingController(rootView: root)
            window.setContentSize(NSSize(width: 940, height: 680))
            window.contentMinSize = NSSize(width: 860, height: 600)
            window.center()
            window.setFrameAutosaveName("BeaconSettings")
            settings = window
        }
        present(settings)
    }

    func showWelcome() {
        let view = FirstRunView { [weak self] in self?.welcome?.close() }.environmentObject(model)
        let window = Self.makeWindow(size: NSSize(width: 580, height: 520), resizable: false)
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        welcome = window
        present(window)
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private static func makeWindow(size: NSSize, resizable: Bool) -> NSWindow {
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if resizable { mask.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: mask, backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.106, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        return window
    }
}
