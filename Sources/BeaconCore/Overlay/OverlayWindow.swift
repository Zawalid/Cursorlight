import AppKit
import QuartzCore

/// A borderless, click-through window covering one display. Effects attach to `rootLayer`.
@MainActor
public final class OverlayWindow: NSWindow {
    public let displayID: CGDirectDisplayID

    /// Layer that effects (spotlight, ripples, ink) are added to.
    public var rootLayer: CALayer {
        guard let layer = contentView?.layer else {
            let fallback = CALayer()
            contentView?.layer = fallback
            return fallback
        }
        return layer
    }

    init(displayID: CGDirectDisplayID, frame: CGRect) {
        self.displayID = displayID
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = NSView(frame: CGRect(origin: .zero, size: frame.size))
        host.wantsLayer = true
        host.autoresizingMask = [.width, .height]
        contentView = host
        setFrame(frame, display: false)
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
