import AppKit
import CursorlightCore
import Combine
import SwiftUI

/// The menu bar item. Click opens the popover; right click opens a short menu.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var model: AppModel?
    private var eventMonitor: Any?
    private var cancellable: AnyCancellable?
    private var iconState = MenuBarIconState.idle
    private var iconTimer: Timer?
    private var appearanceObservation: NSKeyValueObservation?

    /// The icon's frame in screen coordinates.
    var buttonFrame: NSRect? { statusItem?.button?.window?.frame }

    /// Blinks the icon three times, to show where the app lives.
    func ping() {
        guard let button = statusItem?.button else { return }
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i) * 0.6) { button.highlight(true) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05 + Double(i) * 0.6) { button.highlight(false) }
        }
    }

    func install(model: AppModel?) {
        guard statusItem == nil else { return }
        self.model = model
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel(Branding.appName)
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        // The bar can be light or dark depending on the wallpaper, so follow the button's own appearance and redraw when it changes.
        appearanceObservation = item.button?.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.redrawIcon() } }
        }

        if let model {
            // Tint the icon amber while the share status needs attention.
            cancellable = model.objectWillChange.sink { [weak self, weak model] _ in
                DispatchQueue.main.async {
                    let attention = model?.shareStatus.needsAttention ?? false
                    self?.needsAttention = attention
                    self?.redrawIcon()
                    self?.refreshIcon()
                }
            }
            // Effects can start from a shortcut without the model announcing it, so the icon also checks on a slow beat.
            iconTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshIcon() }
            }
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            popover.contentViewController = NSHostingController(rootView: PopoverView().environmentObject(model))
        }
    }

    private var needsAttention = false

    private func refreshIcon() {
        guard let model else { return }
        let state: MenuBarIconState = model.isPaused ? .paused : (model.anyEffectRunning ? .active : .idle)
        guard state != iconState else { return }
        iconState = state
        redrawIcon()
    }

    private func redrawIcon() {
        guard let button = statusItem?.button else { return }
        let dark = button.effectiveAppearance.bestMatch(from: [.vibrantDark, .darkAqua, .vibrantLight, .aqua]).map { [.vibrantDark, .darkAqua].contains($0) } ?? false
        let color: NSColor = needsAttention ? .systemOrange : (dark ? .white : .black)
        button.image = MenuBarIcon.image(iconState, color: color)
        button.setAccessibilityLabel(Branding.appName)
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

    func showPopover() {
        guard let button = statusItem?.button, model != nil, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closePopover() { popover.performClose(nil) }
}
