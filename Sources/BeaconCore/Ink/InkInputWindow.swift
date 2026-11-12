import AppKit

/// Receives the mouse while Ink is active, so the drag never reaches the app underneath. Covers the display minus the
/// menu bar and Dock, which stay usable.
@MainActor
final class InkInputWindow: NSWindow {
    var onDown: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onUp: ((CGPoint) -> Void)?
    var onKey: ((NSEvent) -> Void)?
    private let takesKey: Bool

    init(frame: CGRect, takesKey: Bool) {
        self.takesKey = takesKey
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        // Nearly invisible but not clear: fully clear pixels would let the window server skip hit-testing.
        backgroundColor = NSColor.black.withAlphaComponent(0.004)
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        acceptsMouseMovedEvents = false
        let view = InkInputView(frame: CGRect(origin: .zero, size: frame.size))
        view.autoresizingMask = [.width, .height]
        contentView = view
        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { takesKey }
    override var canBecomeMain: Bool { false }

    private func global(_ event: NSEvent) -> CGPoint {
        convertPoint(toScreen: event.locationInWindow)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown: onDown?(global(event))
        case .leftMouseDragged: onDrag?(global(event))
        case .leftMouseUp: onUp?(global(event))
        case .keyDown: onKey?(event)
        default: super.sendEvent(event)
        }
    }
}

private final class InkInputView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
}
