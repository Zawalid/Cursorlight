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
    private var settingsHost: FirstClickHostingView<AnyView>?
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
        if settings != nil, let host = settingsHost {
            host.rootView = root
        } else {
            let window = Self.makeWindow(size: NSSize(width: 980, height: 700), resizable: true)
            window.title = Branding.appName
            let host = FirstClickHostingView(rootView: root)
            Self.install(host, in: window)
            settingsHost = host
            window.setContentSize(NSSize(width: 980, height: 700))
            window.contentMinSize = NSSize(width: 900, height: 640)
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
        Self.install(host, in: window)
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

    /// Puts the SwiftUI view on a translucent material, so the window is glass and the wallpaper tints it.
    static func install(_ host: NSView, in window: NSWindow) {
        let glass = NSVisualEffectView()
        glass.material = .underWindowBackground
        glass.blendingMode = .behindWindow
        glass.state = .active
        window.contentView = glass
        if let host = host as? NSHostingView<AnyView> { host.sizingOptions = [] }
        host.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: glass.leadingAnchor), host.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            host.topAnchor.constraint(equalTo: glass.topAnchor), host.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
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
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .aqua)
        // An empty unified toolbar makes the title bar tall, which centers the traffic lights in a row of their own.
        window.toolbar = NSToolbar(identifier: "beacon.window")
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        return window
    }
}
