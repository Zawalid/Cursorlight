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
    private var inkItem: NSMenuItem?
    private var pauseItem: NSMenuItem?
    private var shakeTriggerItem: NSMenuItem?
    private var doubleTapTriggerItem: NSMenuItem?
    private var holdTriggerItem: NSMenuItem?
    private var hotkeysTriggerItem: NSMenuItem?
    private var permissionItem: NSMenuItem?
    private var inkCleanupItem: NSMenuItem?
    private var inkStyleItems: [(style: InkStyle, item: NSMenuItem)] = []
    private var inkColorItems: [(color: InkColor, item: NSMenuItem)] = []
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
            let pause = NSMenuItem(title: "Pause Beacon", action: #selector(togglePause), keyEquivalent: "")
            pause.target = self
            menu.addItem(pause)
            pauseItem = pause
            menu.addItem(.separator())
            addHighlightItems(to: menu, coordinator: coordinator)
            menu.addItem(.separator())
            addInkItems(to: menu, coordinator: coordinator)
            menu.addItem(.separator())
            addCursorItems(to: menu, coordinator: coordinator)
            menu.addItem(.separator())
            addTriggerItems(to: menu, coordinator: coordinator)
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

    private func addInkItems(to menu: NSMenu, coordinator: AppCoordinator) {
        let toggle = NSMenuItem(title: "Start ink", action: #selector(toggleInk), keyEquivalent: "")
        toggle.target = self
        toggle.toolTip = "Draw on the screen. Escape stops, Cmd-Z undoes, C clears, 1 to 5 pick a color."
        menu.addItem(toggle)
        inkItem = toggle

        let styles = NSMenu(title: "Ink style")
        styles.delegate = self
        for style in InkStyle.allCases {
            let item = NSMenuItem(title: style.displayName, action: #selector(setInkStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            styles.addItem(item)
            inkStyleItems.append((style, item))
        }
        let styleParent = NSMenuItem(title: "Ink style", action: nil, keyEquivalent: "")
        styleParent.submenu = styles
        menu.addItem(styleParent)

        let colors = NSMenu(title: "Ink color")
        colors.delegate = self
        for color in InkColor.allCases {
            let item = NSMenuItem(title: color.displayName, action: #selector(setInkColor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = color.rawValue
            colors.addItem(item)
            inkColorItems.append((color, item))
        }
        let colorParent = NSMenuItem(title: "Ink color", action: nil, keyEquivalent: "")
        colorParent.submenu = colors
        menu.addItem(colorParent)

        let cleanup = NSMenuItem(title: "Clean up shapes", action: #selector(toggleInkCleanup), keyEquivalent: "")
        cleanup.target = self
        menu.addItem(cleanup)
        inkCleanupItem = cleanup

        coordinator.ink.onChange = { [weak self] in self?.refreshChecks() }
    }

    private func addTriggerItems(to menu: NSMenu, coordinator: AppCoordinator) {
        let submenu = NSMenu(title: "Triggers")
        submenu.delegate = self
        func add(_ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
            item.target = self
            submenu.addItem(item)
            return item
        }
        shakeTriggerItem = add(#selector(toggleShakeTrigger))
        doubleTapTriggerItem = add(#selector(toggleDoubleTapTrigger))
        holdTriggerItem = add(#selector(toggleHoldTrigger))
        hotkeysTriggerItem = add(#selector(toggleHotkeysTrigger))
        submenu.addItem(.separator())
        let permission = NSMenuItem(title: "", action: #selector(requestInputMonitoring), keyEquivalent: "")
        permission.target = self
        submenu.addItem(permission)
        permissionItem = permission

        let parent = NSMenuItem(title: "Triggers", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
        coordinator.onTriggersChange = { [weak self] in self?.refreshChecks() }
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
        coordinator?.refreshInputMonitoring()
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
        refreshTriggerItems()
        inkItem?.title = coordinator?.ink.isActive == true ? "Stop ink" : "Start ink"
        if let ink = coordinator?.ink {
            for (style, item) in inkStyleItems { item.state = style == ink.style ? .on : .off }
            for (color, item) in inkColorItems { item.state = color == ink.color ? .on : .off }
        }
        inkCleanupItem?.state = coordinator?.settings.settings.inkCleanup == true ? .on : .off
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

    private func refreshTriggerItems() {
        guard let coordinator else { return }
        let t = coordinator.settings.settings.triggers
        pauseItem?.title = coordinator.isPaused ? "Resume Beacon" : "Pause Beacon"
        pauseItem?.state = coordinator.isPaused ? .on : .off
        shakeTriggerItem?.title = "Shake: \(t.shakeAction.displayName)"
        shakeTriggerItem?.state = t.shakeEnabled ? .on : .off
        doubleTapTriggerItem?.title = "Double-tap \(t.doubleTapKey.displayName): \(t.doubleTapAction.displayName)"
        doubleTapTriggerItem?.state = t.doubleTapEnabled ? .on : .off
        holdTriggerItem?.title = "Hold \(t.holdKey.displayName): \(t.holdAction.displayName)"
        holdTriggerItem?.state = t.holdEnabled ? .on : .off
        let keys = HotKeyAction.allCases.compactMap { action in
            t.hotkey(for: action).map { "\($0.displayString) \(action.displayName)" }
        }
        hotkeysTriggerItem?.title = "Keyboard shortcuts"
        hotkeysTriggerItem?.state = t.hotkeysEnabled ? .on : .off
        hotkeysTriggerItem?.toolTip = keys.joined(separator: "\n")
        let failed = coordinator.failedHotkeys
        if !failed.isEmpty, t.hotkeysEnabled {
            hotkeysTriggerItem?.title = "Keyboard shortcuts (taken by another app: \(failed.map(\.displayName).joined(separator: ", ")))"
        }
        permissionItem?.isHidden = !coordinator.needsInputMonitoring
        permissionItem?.title = "Allow Input Monitoring for modifier triggers…"
    }

    @objc private func togglePause() {
        guard let coordinator else { return }
        coordinator.setPaused(!coordinator.isPaused)
    }

    @objc private func toggleShakeTrigger() { coordinator?.updateTriggers { $0.shakeEnabled.toggle() } }
    @objc private func toggleDoubleTapTrigger() { coordinator?.updateTriggers { $0.doubleTapEnabled.toggle() } }
    @objc private func toggleHoldTrigger() { coordinator?.updateTriggers { $0.holdEnabled.toggle() } }
    @objc private func toggleHotkeysTrigger() { coordinator?.updateTriggers { $0.hotkeysEnabled.toggle() } }
    @objc private func requestInputMonitoring() { coordinator?.requestInputMonitoring() }

    private func mark(_ items: [(value: Double, item: NSMenuItem)], current: Double) {
        let nearest = items.min { abs($0.value - current) < abs($1.value - current) }
        for entry in items { entry.item.state = entry.item === nearest?.item ? .on : .off }
    }

    @objc private func toggleInk() {
        coordinator?.toggleInk()
        refreshChecks()
    }

    @objc private func setInkStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = InkStyle(rawValue: raw) else { return }
        coordinator?.setInkStyle(style)
        refreshChecks()
    }

    @objc private func setInkColor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let color = InkColor(rawValue: raw) else { return }
        coordinator?.setInkColor(color)
        refreshChecks()
    }

    @objc private func toggleInkCleanup() {
        guard let current = coordinator?.settings.settings.inkCleanup else { return }
        coordinator?.setInkCleanup(!current)
        refreshChecks()
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
