import CoreGraphics
import Foundation

/// When the floating bar is on screen.
public enum ToolbarVisibility: String, CaseIterable, Codable, Sendable {
    /// Whenever the bar is switched on.
    case always
    /// Only while the highlight, laser or ink is running.
    case whileEffectOn

    public var displayName: String {
        switch self {
        case .always: "Always"
        case .whileEffectOn: "While an effect is on"
        }
    }
}

/// The floating control bar. Global, not part of a scene. Tolerant to decode.
public struct ToolbarSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var visibility: ToolbarVisibility = .always
    /// Keep the bar out of screen shares and recordings, so viewers see the effects but not the controls.
    public var hiddenFromViewers = true
    /// Shrunk to a handle and one button.
    public var collapsed = false
    /// Where the bar was left, as its bottom-left corner in screen coordinates. nil: bottom center of the main display.
    public var originX: Double?
    public var originY: Double?

    public init() {}

    public var origin: CGPoint? {
        guard let originX, let originY, originX.isFinite, originY.isFinite else { return nil }
        return CGPoint(x: originX, y: originY)
    }

    /// Whether the bar is on screen, given whether any effect is running.
    public func isShown(effectRunning: Bool) -> Bool {
        guard enabled else { return false }
        switch visibility {
        case .always: return true
        case .whileEffectOn: return effectRunning
        }
    }

    private enum CodingKeys: String, CodingKey { case enabled, visibility, hiddenFromViewers, collapsed, originX, originY }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ToolbarSettings()
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? d.enabled
        visibility = (try? c.decode(ToolbarVisibility.self, forKey: .visibility)) ?? d.visibility
        hiddenFromViewers = (try? c.decode(Bool.self, forKey: .hiddenFromViewers)) ?? d.hiddenFromViewers
        collapsed = (try? c.decode(Bool.self, forKey: .collapsed)) ?? d.collapsed
        originX = try? c.decode(Double.self, forKey: .originX)
        originY = try? c.decode(Double.self, forKey: .originY)
    }
}
