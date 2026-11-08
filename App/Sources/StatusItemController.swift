import AppKit
import BeaconCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var skinItems: [String: NSMenuItem] = [:]
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

    private func addCursorItems(to menu: NSMenu, coordinator: AppCoordinator) {
        let submenu = NSMenu(title: "Try cursor skin")
        for skin in BuiltInSkins.all {
            let item = NSMenuItem(title: skin.name, action: #selector(trySkin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = skin.id
            submenu.addItem(item)
            skinItems[skin.id] = item
        }
        let parent = NSMenuItem(title: "Try cursor skin", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)

        let restore = NSMenuItem(title: "Restore cursor", action: #selector(restoreCursor), keyEquivalent: "")
        restore.target = self
        menu.addItem(restore)

        coordinator.onTrialChange = { [weak self] in self?.refreshChecks() }
    }

    private func refreshChecks() {
        let active = coordinator?.trialSkinID
        for (id, item) in skinItems { item.state = id == active ? .on : .off }
    }

    @objc private func trySkin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let skin = BuiltInSkins.skin(id: id) else { return }
        coordinator?.tryTrial(skin)
    }

    @objc private func restoreCursor() {
        coordinator?.restoreCursor()
    }
}
