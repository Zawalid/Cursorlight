import AppKit
import CursorlightCore
import Combine
import SwiftUI

/// A panel that never takes focus: clicking the bar must not change the front app, which would switch app rules.
private final class ToolbarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Shows the floating bar above everything, including the ink layer, and keeps it in step with the settings.
@MainActor
final class ToolbarController {
    private let model: AppModel
    private var panel: ToolbarPanel?
    private var host: NSHostingView<AnyView>?
    private var subscription: AnyCancellable?
    private var moveObserver: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        subscription = model.$revision.sink { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.refresh() } }
        }
        refresh()
    }

    private func refresh() {
        let settings = model.settings
        let hiddenByRule = model.hideReason != nil
        let show = settings.toolbar.isShown(effectRunning: model.anyEffectRunning) && !hiddenByRule
        guard show else {
            panel?.orderOut(nil)
            return
        }
        let panel = self.panel ?? makePanel()
        panel.sharingType = settings.toolbar.hiddenFromViewers ? .none : .readOnly
        resize(panel)
        if !panel.isVisible {
            place(panel, saved: settings.toolbar.origin)
            panel.orderFrontRegardless()
        }
    }

    private func makePanel() -> ToolbarPanel {
        let panel = ToolbarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 48),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.title = "Cursorlight bar"
        let host = NSHostingView(rootView: AnyView(ToolbarView().environmentObject(model).tint(Theme.accent)))
        panel.contentView = host
        self.host = host
        self.panel = panel
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveOrigin() }
        }
        return panel
    }

    /// Fits the panel to its content, keeping the left edge and baseline where they are.
    private func resize(_ panel: ToolbarPanel) {
        guard let host else { return }
        let size = host.fittingSize
        guard size.width > 0, size.height > 0, panel.frame.size != size else { return }
        panel.setContentSize(size)
    }

    private func place(_ panel: ToolbarPanel, saved: CGPoint?) {
        resize(panel)
        let screens = NSScreen.screens
        if let saved, screens.contains(where: { $0.frame.insetBy(dx: -40, dy: -40).contains(saved) }) {
            panel.setFrameOrigin(saved)
            return
        }
        let area = (NSScreen.main ?? screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        panel.setFrameOrigin(NSPoint(x: area.midX - panel.frame.width / 2, y: area.minY + 28))
    }

    private func saveOrigin() {
        guard let panel, panel.isVisible else { return }
        let origin = panel.frame.origin
        model.setToolbar { $0.originX = origin.x; $0.originY = origin.y }
    }
}

/// A grip that drags the window by hand. The window itself is not movable by background, because that swallows clicks.
struct DragGrip: NSViewRepresentable {
    func makeNSView(context: Context) -> GripView { GripView() }
    func updateNSView(_ nsView: GripView, context: Context) {}

    final class GripView: NSView {
        private var start: NSPoint?
        private var originAtStart: NSPoint?

        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

        override func mouseDown(with event: NSEvent) {
            start = NSEvent.mouseLocation
            originAtStart = window?.frame.origin
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start, let originAtStart, let window else { return }
            let now = NSEvent.mouseLocation
            window.setFrameOrigin(NSPoint(x: originAtStart.x + now.x - start.x, y: originAtStart.y + now.y - start.y))
        }
    }
}
