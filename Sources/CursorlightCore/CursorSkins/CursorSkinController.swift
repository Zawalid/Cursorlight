import Foundation

/// Applies the chosen pointer through a `CursorReplacing` and keeps it in step with the settings.
@MainActor
public final class CursorSkinController {
    private let replacer: CursorReplacing
    public private(set) var current = CursorSkinSettings()
    public private(set) var failed = false

    public init(replacer: CursorReplacing) {
        self.replacer = replacer
    }

    public var isAvailable: Bool { replacer.isAvailable }

    /// Shows the skin, or gives the pointer back when the design is `.system` or the skin is paused.
    public func apply(_ settings: CursorSkinSettings, paused: Bool = false) {
        current = settings
        guard !paused, let skin = CursorSkinRenderer.render(settings) else {
            replacer.clear()
            failed = false
            return
        }
        failed = !replacer.show(skin)
    }

    public func stop() {
        replacer.clear()
    }
}
