import AppKit
import BeaconCore
import SwiftUI

/// The menu bar item. Click opens the popover; right click opens a short menu.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var model: AppModel?
    private var eventMonitor: Any?

    func install(model: AppModel?) {
        guard statusItem == nil else { return }
        self.model = model
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "scope", accessibilityDescription: Branding.appName)
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        if let model {
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            popover.contentViewController = NSHostingController(rootView: PopoverView().environmentObject(model))
        }
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard model != nil else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        guard let model, let item = statusItem else { return }
        let menu = NSMenu(title: Branding.appName)
        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let pause = NSMenuItem(title: model.isPaused ? "Resume" : "Pause", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit \(Branding.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openSettings() { model?.openSettings(.highlight) }
    @objc private func togglePause() { model.map { $0.setPaused(!$0.isPaused) } }

    func closePopover() { popover.performClose(nil) }
}
