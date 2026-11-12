import AppKit

/// Receives the mouse while Ink is active, so the drag never reaches the app underneath. Covers the display minus the
/// menu bar and Dock, which stay usable.
@MainActor
final class InkInputWindow: NSPanel {
    var onDown: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onUp: ((CGPoint) -> Void)?
    var onKey: ((NSEvent) -> Void)?
    private let takesKey: Bool

    init(frame: CGRect, takesKey: Bool) {
        self.takesKey = takesKey
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        hidesOnDeactivate = false
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

    // MARK: Text entry

    private var textField: NSTextField?
    private var textDelegate: TextEntryDelegate?
    private var onTextCommit: ((String) -> Void)?
    var isEditingText: Bool { textField != nil }

    /// Puts a text field at `point` (global coordinates) and calls `commit` with what was typed when Return is pressed.
    func beginTextEntry(at point: CGPoint, color: NSColor, commit: @escaping (String) -> Void) {
        finishText(commit: true)
        let local = convertPoint(fromScreen: point)
        let field = NSTextField(frame: CGRect(x: local.x, y: local.y - 17, width: 360, height: 34))
        field.font = .systemFont(ofSize: 24, weight: .bold)
        field.textColor = color
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.placeholderString = "Type, then Return"
        field.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
            shadow.shadowBlurRadius = 2
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            return shadow
        }()
        let delegate = TextEntryDelegate { [weak self] committed in self?.finishText(commit: committed) }
        field.delegate = delegate
        contentView?.addSubview(field)
        textField = field
        textDelegate = delegate
        onTextCommit = commit
        makeFirstResponder(field)
    }

    func finishText(commit: Bool) {
        guard let field = textField else { return }
        let text = field.stringValue
        field.removeFromSuperview()
        textField = nil
        textDelegate = nil
        makeFirstResponder(contentView)
        let callback = onTextCommit
        onTextCommit = nil
        if commit { callback?(text) }
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            finishText(commit: true)
            onDown?(global(event))
        case .leftMouseDragged: onDrag?(global(event))
        case .leftMouseUp: onUp?(global(event))
        case .keyDown:
            if isEditingText { super.sendEvent(event) } else { onKey?(event) }
        default: super.sendEvent(event)
        }
    }
}

private final class TextEntryDelegate: NSObject, NSTextFieldDelegate {
    let finish: (Bool) -> Void
    init(finish: @escaping (Bool) -> Void) { self.finish = finish }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) { finish(true); return true }
        if selector == #selector(NSResponder.cancelOperation(_:)) { finish(false); return true }
        return false
    }
}

private final class InkInputView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
}
