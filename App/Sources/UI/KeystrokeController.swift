import AppKit
import BeaconCore
import SwiftUI

private final class KeystrokePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The keystroke display: a click-through strip near the bottom of the main display. Unlike the bar and the timer it
/// is shown to viewers, because it exists for them.
@MainActor
final class KeystrokeController {
    private let coordinator: AppCoordinator
    private let model: AppModel
    private var panel: KeystrokePanel?
    private var host: NSHostingView<AnyView>?
    private var hideTimer: Timer?

    init(coordinator: AppCoordinator, model: AppModel) {
        self.coordinator = coordinator
        self.model = model
        coordinator.onKeystroke = { [weak self] in self?.show() }
    }

    private func show() {
        let panel = self.panel ?? makePanel()
        host?.rootView = AnyView(KeystrokeView(coordinator: coordinator))
        if let host { panel.setContentSize(NSSize(width: 900, height: max(host.fittingSize.height, 70))) }
        place(panel)
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkExpired() }
        }
    }

    private func checkExpired() {
        let now = ProcessInfo.processInfo.systemUptime
        if coordinator.keystrokeBuffer.visible(at: now).isEmpty {
            panel?.orderOut(nil)
            hideTimer?.invalidate()
            hideTimer = nil
        }
    }

    private func makePanel() -> KeystrokePanel {
        let panel = KeystrokePanel(contentRect: NSRect(x: 0, y: 0, width: 900, height: 80), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.title = "Beacon keys"
        let host = NSHostingView(rootView: AnyView(KeystrokeView(coordinator: coordinator)))
        panel.contentView = host
        self.host = host
        self.panel = panel
        return panel
    }

    private func place(_ panel: KeystrokePanel) {
        let area = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let y = area.minY + 28
        switch model.settings.keystrokes.position {
        case .bottomCenter: panel.setFrameOrigin(NSPoint(x: area.midX - panel.frame.width / 2, y: y))
        case .bottomLeft: panel.setFrameOrigin(NSPoint(x: area.minX + 20, y: y))
        case .bottomRight: panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 20, y: y))
        }
    }
}

struct KeystrokeView: View {
    let coordinator: AppCoordinator

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = ProcessInfo.processInfo.systemUptime
            let items = coordinator.keystrokeBuffer.visible(at: now)
            let position = coordinator.settings.settings.keystrokes.position
            HStack(spacing: 10) {
                ForEach(items, id: \.entry.id) { item in
                    Text(item.entry.text)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 48)
                        .background(Color(red: 0.09, green: 0.09, blue: 0.1).opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                        .opacity(item.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: position == .bottomLeft ? .leading : (position == .bottomRight ? .trailing : .center))
            .padding(10)
        }
    }
}
