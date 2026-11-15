import AppKit
import CursorlightCore
import SwiftUI

final class GuidePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Shows the welcome guide as a native HUD over the real screen and moves it between its three places: the middle of the
/// screen to say hello, the bottom while you try things (out of the way of your pointer), and under the menu bar icon at the end.
@MainActor
final class GuideController {
    private let model: AppModel
    private var panel: GuidePanel?

    init(model: AppModel) { self.model = model }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        if let panel {
            panel.orderFrontRegardless()
            return
        }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = Self.frame(for: .intro, on: screen, model: model)
        let panel = GuidePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // A system HUD material with rounded corners, so the guide looks like part of macOS and is cheap to move and redraw.
        let material = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 22
        material.layer?.cornerCurve = .continuous
        material.layer?.masksToBounds = true
        material.layer?.borderWidth = 1
        material.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        material.autoresizingMask = [.width, .height]

        let view = GuideView(
            stepChanged: { [weak self] step in self?.move(to: step) },
            finish: { [weak self] in self?.close() }
        ).environmentObject(model)
        let host = FirstClickHostingView(rootView: AnyView(view))
        host.sizingOptions = []
        host.frame = material.bounds
        host.autoresizingMask = [.width, .height]
        material.addSubview(host)
        panel.contentView = material

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
        let frame = Self.frame(for: step, on: screen, model: model)
        if step.isCoach == false { panel.makeKey() }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.55
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
            panel.animator().setFrame(frame, display: true)
        }, completionHandler: { panel.invalidateShadow() })
    }

    static func frame(for step: GuideStep, on screen: NSScreen, model: AppModel) -> NSRect {
        let size = step.panelSize
        let visible = screen.visibleFrame
        let centered = NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)
        switch step {
        case .intro:
            return centered
        case .shake, .laser, .ink:
            return NSRect(x: visible.midX - size.width / 2, y: visible.minY + 36, width: size.width, height: size.height)
        case .done:
            guard let item = model.statusItemFrame(), screen.frame.contains(NSPoint(x: item.midX, y: item.midY)) else { return centered }
            let right = min(visible.maxX - 12, item.midX + 90)
            return NSRect(x: right - size.width, y: visible.maxY - 12 - size.height, width: size.width, height: size.height)
        }
    }
}
