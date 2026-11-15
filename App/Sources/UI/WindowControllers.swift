import AppKit
import CursorlightCore
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
    private var settingsController: NSHostingController<AnyView>?
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
        let root = AnyView(SettingsView(page: page).environmentObject(model).tint(Theme.accent))
        if settings != nil, let controller = settingsController {
            controller.rootView = root
        } else {
            let window = Self.makeWindow(size: NSSize(width: 1180, height: 740), resizable: true)
            window.title = Branding.appName
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(red: 0.055, green: 0.055, blue: 0.063, alpha: 1)
            let controller = NSHostingController(rootView: root)
            window.contentViewController = controller
            settingsController = controller
            window.setContentSize(NSSize(width: 1180, height: 740))
            window.contentMinSize = NSSize(width: 980, height: 640)
            window.center()
            window.setFrameAutosaveName("CursorlightSettings.v7")
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

    /// Puts the SwiftUI view in the window. Solid, no translucency.
    static func install(_ host: NSView, in window: NSWindow) {
        if let host = host as? NSHostingView<AnyView> { host.sizingOptions = [] }
        window.contentView = host
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
        // System appearance and background: the app follows light and dark like any other Mac app.
        return window
    }

    /// Makes the title bar `height` tall and centers the traffic lights in it, so they share a row with the top bar. There
    /// is deliberately no toolbar: a toolbar view sits above the content and swallows clicks on anything under it.
    static func centerTrafficLights(of window: NSWindow, height: CGFloat = 52) {
        guard let close = window.standardWindowButton(.closeButton),
              let bar = close.superview?.superview else { return }
        var frame = bar.frame
        frame.size.height = height
        frame.origin.y = window.frame.height - height
        bar.frame = frame
        var x: CGFloat = 20
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(kind) else { continue }
            button.setFrameOrigin(NSPoint(x: x, y: (height - button.frame.height) / 2))
            x += button.frame.width + 8
        }
    }

    /// Keeps the traffic lights centered whenever AppKit lays the title bar out again.
    func keepTrafficLightsCentered(_ window: NSWindow) {
        for name in [NSWindow.didResizeNotification, NSWindow.didBecomeKeyNotification, NSWindow.didEndLiveResizeNotification,
                     NSWindow.didExitFullScreenNotification] {
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak window] _ in
                MainActor.assumeIsolated { if let window { Self.centerTrafficLights(of: window) } }
            }
        }
        Self.centerTrafficLights(of: window)
        DispatchQueue.main.async { MainActor.assumeIsolated { Self.centerTrafficLights(of: window) } }
    }
}
