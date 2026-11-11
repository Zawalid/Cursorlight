import AppKit
import BeaconCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var sizeItems: [(scale: Float, item: NSMenuItem)] = []
    private var styleItems: [(style: HighlightStyle, item: NSMenuItem)] = []
    private var highlightItem: NSMenuItem?
    private var ripplesItem: NSMenuItem?
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
        menu.delegate = self

        let settings = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: ",")
        settings.isEnabled = false
        menu.addItem(settings)

        menu.addItem(.separator())

        if let coordinator {
            addHighlightItems(to: menu, coordinator: coordinator)
            menu.addItem(.separator())
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

    private func addHighlightItems(to menu: NSMenu, coordinator: AppCoordinator) {
        let toggle = NSMenuItem(title: "Turn highlight on", action: #selector(toggleHighlight), keyEquivalent: "")
        toggle.target = self
        toggle.toolTip = "Shake the pointer to turn it on or off."
        menu.addItem(toggle)
        highlightItem = toggle

        let submenu = NSMenu(title: "Highlight style")
        submenu.delegate = self
        for style in HighlightStyle.allCases {
            let item = NSMenuItem(title: style.displayName, action: #selector(setStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            submenu.addItem(item)
            styleItems.append((style, item))
        }
        let parent = NSMenuItem(title: "Highlight style", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)

        let ripples = NSMenuItem(title: "Click ripples", action: #selector(toggleRipples), keyEquivalent: "")
        ripples.target = self
        menu.addItem(ripples)
        ripplesItem = ripples

        coordinator.highlight.onChange = { [weak self] in self?.refreshChecks() }
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
        let highlight = coordinator?.highlight
        for (style, item) in styleItems {
            item.state = style == highlight?.style ? .on : .off
        }
        highlightItem?.title = highlight?.isOn == true ? "Turn highlight off" : "Turn highlight on"
        ripplesItem?.state = highlight?.ripplesEnabled == true ? .on : .off
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

    @objc private func toggleHighlight() {
        coordinator?.toggleHighlight()
        refreshChecks()
    }

    @objc private func setStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = HighlightStyle(rawValue: raw) else { return }
        coordinator?.setHighlightStyle(style)
        refreshChecks()
    }

    @objc private func toggleRipples() {
        guard let highlight = coordinator?.highlight else { return }
        coordinator?.setClickRipples(!highlight.ripplesEnabled)
        refreshChecks()
    }

    @objc private func resetSize() {
        coordinator?.resetCursorScale()
    }
}
