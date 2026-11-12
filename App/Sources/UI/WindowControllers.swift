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
    }

    func showSettings(_ page: SettingsPage) {
        let root = AnyView(SettingsView(page: page).environmentObject(model))
        if let window = settings, let host = window.contentView as? FirstClickHostingView<AnyView> {
            host.rootView = root
        } else {
            let window = Self.makeWindow(size: NSSize(width: 940, height: 680), resizable: true)
            window.title = Branding.appName
            window.contentView = FirstClickHostingView(rootView: root)
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
        window.contentView = FirstClickHostingView(rootView: view)
        window.setContentSize(NSSize(width: 580, height: 520))
        window.center()
        welcome = window
        Self.present(window)
    }

    static func present(_ window: NSWindow?) {
        guard let window else { return }
        // Cooperative activation (macOS 14 and later): the old ignoringOtherApps form no longer forces it.
        NSApp.activate()
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
