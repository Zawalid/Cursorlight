import AppKit
import BeaconCore
import SwiftUI

/// A hosting view that accepts the click that brings its window forward. Without this, the first click on a window
/// of an inactive menu bar app is spent on activation and never reaches the SwiftUI button under it.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

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
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] _ in
            // The closing window is still visible during this notification; check again right after.
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.windowClosed() } }
        }
    }

    func showSettings(_ page: SettingsPage) {
        let root = AnyView(SettingsView(page: page).environmentObject(model))
        if let window = settings, let host = window.contentView as? FirstClickHostingView<AnyView> {
            host.rootView = root
        } else {
            let window = Self.makeWindow(size: NSSize(width: 940, height: 680), resizable: true)
            window.title = Branding.appName
            let host = FirstClickHostingView(rootView: root)
            host.sizingOptions = []
            window.contentView = host
            window.setContentSize(NSSize(width: 940, height: 680))
            window.contentMinSize = NSSize(width: 860, height: 600)
            window.center()
            window.setFrameAutosaveName("BeaconSettings")
            settings = window
        }
        Self.present(settings)
    }

    func showWelcome() {
        let view = AnyView(FirstRunView { [weak self] in self?.welcome?.close() }.environmentObject(model))
        let window = Self.makeWindow(size: NSSize(width: 580, height: 520), resizable: false)
        let host = FirstClickHostingView(rootView: view)
        host.sizingOptions = []
        window.contentView = host
        window.setContentSize(NSSize(width: 580, height: 520))
        window.center()
        welcome = window
        Self.present(window)
    }

    /// A menu bar app is an accessory app, and accessory apps are not reliably activated when one of their windows is
    /// clicked: the window stays inactive and its buttons never fire. While a window is open the app becomes a regular
    /// app (Dock icon, real activation); it goes back to accessory when the last window closes.
    static func becomeRegular() {
        NSApp.setActivationPolicy(.regular)
    }

    func windowClosed() {
        let open = [settings, welcome].compactMap { $0 }.contains { $0.isVisible }
        if !open { NSApp.setActivationPolicy(.accessory) }
    }

    static func present(_ window: NSWindow?) {
        guard let window else { return }
        becomeRegular()
        // Cooperative activation (macOS 14 and later): the old ignoringOtherApps form no longer forces it.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    static func makeWindow(size: NSSize, resizable: Bool) -> NSWindow {
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if resizable { mask.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: mask, backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // Not movable by background: that swallows clicks on SwiftUI buttons. The title bar still drags the window.
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        // Open on the Space the person is looking at, including a full-screen one, instead of on another Space.
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.backgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.106, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        return window
    }
}
