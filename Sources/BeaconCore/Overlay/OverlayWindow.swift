import AppKit
import QuartzCore

/// A borderless, click-through window covering one display. Effects attach to `rootLayer`.
@MainActor
public final class OverlayWindow: NSPanel {
    public let displayID: CGDirectDisplayID
    /// How many times close() ran; lets tests prove stale windows were really closed.
    public private(set) var closeCount = 0

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
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // A panel hides when its app is inactive unless told otherwise; the overlay must stay up.
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let host = NSView(frame: CGRect(origin: .zero, size: frame.size))
        host.wantsLayer = true
        host.autoresizingMask = [.width, .height]
        contentView = host
        setFrame(frame, display: false)
    }

    public override func close() {
        closeCount += 1
        super.close()
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
