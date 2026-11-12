import Foundation

/// Everything the user can choose. One Codable value, stored as JSON under one key.
/// Decoding is tolerant: any missing field takes its default, so adding a field never loses the others.
public struct BeaconSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var highlightStyle: HighlightStyle
    public var clickRipples: Bool
    /// 0 (hardest to trigger) to 100 (easiest).
    public var shakeSensitivity: Double

    public static let defaults = BeaconSettings(
        version: currentVersion,
        highlightStyle: .aura,
        clickRipples: true,
        shakeSensitivity: 50
    )

    public init(version: Int, highlightStyle: HighlightStyle, clickRipples: Bool, shakeSensitivity: Double) {
        self.version = version
        self.highlightStyle = highlightStyle
        self.clickRipples = clickRipples
        self.shakeSensitivity = shakeSensitivity
    }

    private enum CodingKeys: String, CodingKey {
        case version, highlightStyle, clickRipples, shakeSensitivity
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BeaconSettings.defaults
        version = (try? c.decode(Int.self, forKey: .version)) ?? d.version
        highlightStyle = (try? c.decode(HighlightStyle.self, forKey: .highlightStyle)) ?? d.highlightStyle
        clickRipples = (try? c.decode(Bool.self, forKey: .clickRipples)) ?? d.clickRipples
        shakeSensitivity = (try? c.decode(Double.self, forKey: .shakeSensitivity)) ?? d.shakeSensitivity
    }

    /// Returns a copy with every value forced into its valid range.
    func sanitized() -> BeaconSettings {
        var copy = self
        copy.shakeSensitivity = shakeSensitivity.isFinite ? min(max(shakeSensitivity, 0), 100) : 50
        return copy
    }
}
