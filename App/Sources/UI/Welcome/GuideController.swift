import AppKit
import CursorlightCore
import SwiftUI

final class GuidePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Shows the welcome guide as a floating card over the real screen and moves it between its three places: the middle of the
/// screen to say hello, the bottom while you try things (out of the way of your pointer), and under the menu bar icon at the end.
@MainActor
final class GuideController {
    private let model: AppModel
    private let state = GuideState()
    private var panel: GuidePanel?

    init(model: AppModel) { self.model = model }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        if let panel {
            panel.orderFrontRegardless()
            return
        }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = Self.frame(for: .intro, on: screen, model: model, state: state)
        let panel = GuidePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = GuideView(
            state: state,
            stepChanged: { [weak self] step in self?.move(to: step) },
            finish: { [weak self] in self?.close() }
        ).environmentObject(model)
        let host = FirstClickHostingView(rootView: AnyView(view))
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrame(frame, display: true)
        self.panel = panel
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    private func move(to step: GuideStep) {
        guard let panel else { return }
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = Self.frame(for: step, on: screen, model: model, state: state)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
            panel.animator().setFrame(frame, display: true)
        }
    }

    static func frame(for step: GuideStep, on screen: NSScreen, model: AppModel, state: GuideState) -> NSRect {
        let size = step.panelSize
        let visible = screen.visibleFrame
        let margin = GuideView.margin
        switch step {
        case .intro:
            return NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)
        case .shake, .laser, .ink:
            return NSRect(x: visible.midX - size.width / 2, y: visible.minY + 44 - margin, width: size.width, height: size.height)
        case .done:
            guard let item = model.statusItemFrame(), screen.frame.contains(NSPoint(x: item.midX, y: item.midY)) else {
                return NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)
            }
            let cardWidth = step.cardSize.width
            let cardRight = min(visible.maxX - 12, item.midX + 90)
            state.caretFromRight = cardRight - item.midX
            let cardTop = visible.maxY - 14
            return NSRect(x: cardRight - cardWidth - margin, y: cardTop - step.cardSize.height - margin, width: size.width, height: size.height)
        }
    }
}
