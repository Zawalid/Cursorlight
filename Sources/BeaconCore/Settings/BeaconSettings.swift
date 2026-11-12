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
    public var accent: AccentChoice
    /// Multiplier for highlight radii.
    public var highlightSize: Double
    public var highlightIntensity: Double
    public var lensDim: Double
    public var inkStyle: InkStyle
    public var inkColor: InkColor
    /// Turn circles, rectangles, lines and arrows into clean shapes when a stroke ends.
    public var inkCleanup: Bool

    public var look: HighlightLook {
        HighlightLook(accent: accent, size: highlightSize, intensity: highlightIntensity, lensDim: lensDim)
    }

    public static let defaults = BeaconSettings(
        version: currentVersion,
        highlightStyle: .aura,
        clickRipples: true,
        shakeSensitivity: 50,
        accent: .styleDefault,
        highlightSize: 1,
        highlightIntensity: 1,
        lensDim: 0.5,
        inkStyle: .marker,
        inkColor: .red,
        inkCleanup: true
    )

    public init(
        version: Int, highlightStyle: HighlightStyle, clickRipples: Bool, shakeSensitivity: Double,
        accent: AccentChoice, highlightSize: Double, highlightIntensity: Double, lensDim: Double,
        inkStyle: InkStyle = .marker, inkColor: InkColor = .red, inkCleanup: Bool = true
    ) {
        self.version = version
        self.highlightStyle = highlightStyle
        self.clickRipples = clickRipples
        self.shakeSensitivity = shakeSensitivity
        self.accent = accent
        self.highlightSize = highlightSize
        self.highlightIntensity = highlightIntensity
        self.lensDim = lensDim
        self.inkStyle = inkStyle
        self.inkColor = inkColor
        self.inkCleanup = inkCleanup
    }

    private enum CodingKeys: String, CodingKey {
        case version, highlightStyle, clickRipples, shakeSensitivity, accent, highlightSize, highlightIntensity, lensDim
        case inkStyle, inkColor, inkCleanup
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BeaconSettings.defaults
        version = (try? c.decode(Int.self, forKey: .version)) ?? d.version
        highlightStyle = (try? c.decode(HighlightStyle.self, forKey: .highlightStyle)) ?? d.highlightStyle
        clickRipples = (try? c.decode(Bool.self, forKey: .clickRipples)) ?? d.clickRipples
        shakeSensitivity = (try? c.decode(Double.self, forKey: .shakeSensitivity)) ?? d.shakeSensitivity
        accent = (try? c.decode(AccentChoice.self, forKey: .accent)) ?? d.accent
        highlightSize = (try? c.decode(Double.self, forKey: .highlightSize)) ?? d.highlightSize
        highlightIntensity = (try? c.decode(Double.self, forKey: .highlightIntensity)) ?? d.highlightIntensity
        lensDim = (try? c.decode(Double.self, forKey: .lensDim)) ?? d.lensDim
        inkStyle = (try? c.decode(InkStyle.self, forKey: .inkStyle)) ?? d.inkStyle
        inkColor = (try? c.decode(InkColor.self, forKey: .inkColor)) ?? d.inkColor
        inkCleanup = (try? c.decode(Bool.self, forKey: .inkCleanup)) ?? d.inkCleanup
    }

    /// Returns a copy with every value forced into its valid range.
    func sanitized() -> BeaconSettings {
        var copy = self
        copy.shakeSensitivity = shakeSensitivity.isFinite ? min(max(shakeSensitivity, 0), 100) : 50
        copy.highlightSize = Self.clamp(highlightSize, HighlightLook.sizeRange, fallback: 1)
        copy.highlightIntensity = Self.clamp(highlightIntensity, HighlightLook.intensityRange, fallback: 1)
        copy.lensDim = Self.clamp(lensDim, HighlightLook.dimRange, fallback: 0.5)
        return copy
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
}
