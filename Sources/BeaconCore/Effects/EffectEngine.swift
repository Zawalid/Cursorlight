import AppKit

/// Turns effects on and off across every overlay window and feeds them the pointer. The cursor highlight and click
/// ripples run in `HighlightController`; this engine hosts the per-window effects added later (laser, ink).
@MainActor
public final class EffectEngine {
    public typealias Factory = @MainActor (EffectID) -> (any Effect)?

    public private(set) var active: Set<EffectID> = []

    public var style: HighlightStyle = .aura {
        didSet {
            guard style != oldValue else { return }
            for attachment in attachments.values.joined() { attachment.effect.apply(style: style) }
        }
    }

    private struct Attachment {
        let window: OverlayWindow
        let effect: any Effect
    }

    private let tracker: CursorTracker
    private let windows: @MainActor () -> [OverlayWindow]
    private let factory: Factory?
    private var attachments: [EffectID: [Attachment]] = [:]

    /// - Parameters:
    ///   - windows: the current overlay windows, one per display.
    ///   - makeEffect: builds an effect instance; nil uses the built-in effects.
    public init(
        tracker: CursorTracker,
        windows: @escaping @MainActor () -> [OverlayWindow],
        makeEffect: Factory? = nil
    ) {
        self.tracker = tracker
        self.windows = windows
        self.factory = makeEffect
    }

    public convenience init(overlays: OverlayManager, tracker: CursorTracker) {
        self.init(tracker: tracker, windows: { [weak overlays] in
            overlays.map { Array($0.windows.values) } ?? []
        })
    }

    /// Activating an effect that is already active does nothing.
    public func activate(_ id: EffectID) {
        guard !active.contains(id) else { return }
        let built = windows().compactMap { attach(id, to: $0) }
        guard !built.isEmpty else { return }
        attachments[id] = built
        active.insert(id)
        route(tracker.position, at: ProcessInfo.processInfo.systemUptime, to: built)
    }

    public func deactivate(_ id: EffectID) {
        guard active.remove(id) != nil else { return }
        for attachment in attachments.removeValue(forKey: id) ?? [] {
            attachment.effect.onFinish = nil
            attachment.effect.deactivate()
        }
    }

    public func deactivateAll() {
        for id in active { deactivate(id) }
    }

    /// Feeds a pointer position in global screen coordinates (`NSEvent.mouseLocation`).
    public func pointerMoved(to screenPoint: CGPoint, at time: TimeInterval) {
        reconcileWindows()
        for id in active {
            route(screenPoint, at: time, to: attachments[id] ?? [])
        }
    }

    private func attach(_ id: EffectID, to window: OverlayWindow) -> Attachment? {
        guard let effect = factory.map({ $0(id) }) ?? builtIn(id) else { return nil }
        effect.apply(style: style)
        effect.onFinish = { [weak self] in self?.deactivate(id) }
        effect.activate(on: window, tracker: tracker)
        return Attachment(window: window, effect: effect)
    }

    private func builtIn(_ id: EffectID) -> (any Effect)? {
        switch id {
        case .beacon, .pulse: nil  // drawn by HighlightController
        case .laser, .ink: nil  // not built yet
        }
    }

    private func route(_ screenPoint: CGPoint, at time: TimeInterval, to list: [Attachment]) {
        var frames: [CGDirectDisplayID: CGRect] = [:]
        for attachment in list { frames[attachment.window.displayID] = attachment.window.frame }
        let owner = PointerGeometry.owner(of: screenPoint, in: frames)
        for attachment in list {
            let point = attachment.window.displayID == owner
                ? PointerGeometry.layerPoint(for: screenPoint, windowFrame: attachment.window.frame)
                : nil
            attachment.effect.pointerMoved(to: point, at: time)
        }
    }

    /// Overlay windows are rebuilt on wake and display changes; move active effects onto the current windows.
    private func reconcileWindows() {
        guard !active.isEmpty else { return }
        let current = windows()
        let currentIDs = Set(current.map(ObjectIdentifier.init))
        for id in active {
            let list = attachments[id] ?? []
            let attachedIDs = Set(list.map { ObjectIdentifier($0.window) })
            guard attachedIDs != currentIDs else { continue }
            var kept: [Attachment] = []
            for attachment in list {
                if currentIDs.contains(ObjectIdentifier(attachment.window)) {
                    kept.append(attachment)
                } else {
                    attachment.effect.onFinish = nil
                    attachment.effect.deactivate()
                }
            }
            for window in current where !attachedIDs.contains(ObjectIdentifier(window)) {
                if let attachment = attach(id, to: window) { kept.append(attachment) }
            }
            attachments[id] = kept
        }
    }
}
