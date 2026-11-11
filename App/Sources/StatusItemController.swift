import AppKit
import BeaconCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var sizeItems: [(scale: Float, item: NSMenuItem)] = []
    var coordinator: AppCoordinator?

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "scope",
            accessibilityDescription: Branding.appName
        )
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: Branding.appName)

        let settings = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: ",")
        settings.isEnabled = false
        menu.addItem(settings)

        menu.addItem(.separator())

        if let coordinator {
            addCursorItems(to: menu, coordinator: coordinator)
            menu.addItem(.separator())
        }

        let quit = NSMenuItem(
            title: "Quit \(Branding.appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    private static let sizes: [(title: String, scale: Float)] = [
        ("1x", 1.0), ("1.5x", 1.5), ("2x", 2.0), ("3x", 3.0),
    ]

    private func addCursorItems(to menu: NSMenu, coordinator: AppCoordinator) {
        let submenu = NSMenu(title: "Cursor size")
        submenu.delegate = self
        for size in Self.sizes {
            let item = NSMenuItem(title: size.title, action: #selector(setSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: size.scale)
            submenu.addItem(item)
            sizeItems.append((size.scale, item))
        }
        submenu.addItem(.separator())
        let reset = NSMenuItem(title: "Reset", action: #selector(resetSize), keyEquivalent: "")
        reset.target = self
        submenu.addItem(reset)

        let parent = NSMenuItem(title: "Cursor size", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)

        coordinator.onSizeChange = { [weak self] in self?.refreshChecks() }
        refreshChecks()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshChecks()
    }

    private func refreshChecks() {
        let current = coordinator?.cursorSize.currentScale
        for (scale, item) in sizeItems {
            let isCurrent = current.map { abs($0 - scale) < 0.05 } ?? false
            item.state = isCurrent ? .on : .off
        }
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        coordinator?.setCursorScale(number.floatValue)
    }

    @objc private func resetSize() {
        coordinator?.resetCursorScale()
    }
}
