import AppKit
import BeaconCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var sizeItems: [(scale: Float, item: NSMenuItem)] = []
    private var styleItems: [(style: HighlightStyle, item: NSMenuItem)] = []
    private var highlightItem: NSMenuItem?
    private var ripplesItem: NSMenuItem?
    private var laserItem: NSMenuItem?
    private var accentItems: [(accent: AccentChoice, item: NSMenuItem)] = []
    private var sizeLookItems: [(value: Double, item: NSMenuItem)] = []
    private var intensityItems: [(value: Double, item: NSMenuItem)] = []
    private var dimItems: [(value: Double, item: NSMenuItem)] = []
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

        let laser = NSMenuItem(title: "Laser trail on", action: #selector(toggleLaser), keyEquivalent: "")
        laser.target = self
        menu.addItem(laser)
        laserItem = laser

        addLookItems(to: menu)
        coordinator.highlight.onChange = { [weak self] in self?.refreshChecks() }
    }

    private static let lookSizes: [(String, Double)] = [("Small", 0.75), ("Normal", 1.0), ("Large", 1.35), ("Extra large", 1.7)]
    private static let lookIntensities: [(String, Double)] = [("Subtle", 0.5), ("Medium", 0.75), ("Full", 1.0)]
    private static let lookDims: [(String, Double)] = [("Light", 0.3), ("Medium", 0.5), ("Strong", 0.7)]

    private func addLookItems(to menu: NSMenu) {
        let accentMenu = NSMenu(title: "Color")
        accentMenu.delegate = self
        for accent in AccentChoice.allCases {
            let item = NSMenuItem(title: accent.displayName, action: #selector(setAccent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = accent.rawValue
            accentMenu.addItem(item)
            accentItems.append((accent, item))
        }
        let accentParent = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        accentParent.submenu = accentMenu
        menu.addItem(accentParent)

        addValueMenu("Highlight size", Self.lookSizes, action: #selector(setLookSize(_:)), to: menu, store: \.sizeLookItems)
        addValueMenu("Intensity", Self.lookIntensities, action: #selector(setLookIntensity(_:)), to: menu, store: \.intensityItems)
        addValueMenu("Lens dim", Self.lookDims, action: #selector(setLookDim(_:)), to: menu, store: \.dimItems)
    }

    private func addValueMenu(
        _ title: String, _ values: [(String, Double)], action: Selector, to menu: NSMenu,
        store: ReferenceWritableKeyPath<StatusItemController, [(value: Double, item: NSMenuItem)]>
    ) {
        let submenu = NSMenu(title: title)
        submenu.delegate = self
        for (name, value) in values {
            let item = NSMenuItem(title: name, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: value)
            submenu.addItem(item)
            self[keyPath: store].append((value, item))
        }
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
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
        laserItem?.title = highlight?.isLaserOn == true ? "Laser trail off" : "Laser trail on"
        if let current = coordinator?.settings.settings {
            for (accent, item) in accentItems { item.state = accent == current.accent ? .on : .off }
            mark(sizeLookItems, current: current.highlightSize)
            mark(intensityItems, current: current.highlightIntensity)
            mark(dimItems, current: current.lensDim)
        }
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

    private func mark(_ items: [(value: Double, item: NSMenuItem)], current: Double) {
        let nearest = items.min { abs($0.value - current) < abs($1.value - current) }
        for entry in items { entry.item.state = entry.item === nearest?.item ? .on : .off }
    }

    @objc private func toggleLaser() {
        coordinator?.toggleLaser()
        refreshChecks()
    }

    @objc private func setAccent(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let accent = AccentChoice(rawValue: raw) else { return }
        coordinator?.setAccent(accent)
        refreshChecks()
    }

    @objc private func setLookSize(_ sender: NSMenuItem) {
        guard let value = (sender.representedObject as? NSNumber)?.doubleValue else { return }
        coordinator?.setHighlightSize(value)
        refreshChecks()
    }

    @objc private func setLookIntensity(_ sender: NSMenuItem) {
        guard let value = (sender.representedObject as? NSNumber)?.doubleValue else { return }
        coordinator?.setHighlightIntensity(value)
        refreshChecks()
    }

    @objc private func setLookDim(_ sender: NSMenuItem) {
        guard let value = (sender.representedObject as? NSNumber)?.doubleValue else { return }
        coordinator?.setLensDim(value)
        refreshChecks()
    }

    @objc private func resetSize() {
        coordinator?.resetCursorScale()
    }
}
