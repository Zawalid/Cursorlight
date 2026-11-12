import Foundation

/// The extra choices for one look: one option per style, and fading when the pointer is still. Tolerant to decode, and
/// clamped in `sanitized()`.
public struct HighlightOptions: Codable, Equatable, Sendable {
    public static let tailRange: ClosedRange<Double> = 0.5...2.0
    public static let lineRange: ClosedRange<Double> = 0.6...2.0
    public static let softnessRange: ClosedRange<Double> = 0.08...0.6
    public static let ringsRange: ClosedRange<Int> = 1...5
    public static let fadeRange: ClosedRange<Double> = 1...10

    /// Aura: breathe when the pointer rests.
    public var auraBreathing = true
    /// Comet: how long the tail is, as a multiple of the default.
    public var cometTail = 1.0
    /// Keyline: ring thickness, as a multiple of the default.
    public var keylineWidth = 1.0
    /// Sonar: how many rings pulse in.
    public var sonarRings = 3
    /// Lens: how wide the soft edge of the lit circle is, as a share of its radius.
    public var lensSoftness = 0.23
    /// Seconds without pointer movement before the highlight fades away. 0 keeps it on.
    public var fadeAfterStill = 0.0
    /// The color used when the accent is "Custom", as `#RRGGBB`.
    public var customAccent = "#FF6A3D"
    /// Spotlight region: shape, darkness outside, soft edge width and corner radius.
    public var spotlightShape: SpotlightShape = .rounded
    public var spotlightDim = 0.6
    public var spotlightSoftness = 0.0
    public var spotlightCorner = 14.0
    public static let dimRange: ClosedRange<Double> = 0.2...0.9
    public static let edgeRange: ClosedRange<Double> = 0...40
    public static let cornerRange: ClosedRange<Double> = 0...60

    public var spotlight: SpotlightStyle {
        SpotlightStyle(shape: spotlightShape, dim: spotlightDim, softness: spotlightSoftness, corner: spotlightCorner)
    }

    public init() {}

    public var fadesWhenStill: Bool { fadeAfterStill > 0 }

    private enum CodingKeys: String, CodingKey {
        case auraBreathing, cometTail, keylineWidth, sonarRings, lensSoftness, fadeAfterStill, customAccent
        case spotlightShape, spotlightDim, spotlightSoftness, spotlightCorner
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = HighlightOptions()
        auraBreathing = (try? c.decode(Bool.self, forKey: .auraBreathing)) ?? d.auraBreathing
        cometTail = (try? c.decode(Double.self, forKey: .cometTail)) ?? d.cometTail
        keylineWidth = (try? c.decode(Double.self, forKey: .keylineWidth)) ?? d.keylineWidth
        sonarRings = (try? c.decode(Int.self, forKey: .sonarRings)) ?? d.sonarRings
        lensSoftness = (try? c.decode(Double.self, forKey: .lensSoftness)) ?? d.lensSoftness
        fadeAfterStill = (try? c.decode(Double.self, forKey: .fadeAfterStill)) ?? d.fadeAfterStill
        customAccent = (try? c.decode(String.self, forKey: .customAccent)) ?? d.customAccent
        spotlightShape = (try? c.decode(SpotlightShape.self, forKey: .spotlightShape)) ?? d.spotlightShape
        spotlightDim = (try? c.decode(Double.self, forKey: .spotlightDim)) ?? d.spotlightDim
        spotlightSoftness = (try? c.decode(Double.self, forKey: .spotlightSoftness)) ?? d.spotlightSoftness
        spotlightCorner = (try? c.decode(Double.self, forKey: .spotlightCorner)) ?? d.spotlightCorner
        self = sanitized()
    }

    /// A copy with every value forced into its valid range. A fade time below the range means "never".
    public func sanitized() -> HighlightOptions {
        var copy = self
        copy.cometTail = Self.clamp(cometTail, Self.tailRange, fallback: 1)
        copy.keylineWidth = Self.clamp(keylineWidth, Self.lineRange, fallback: 1)
        copy.lensSoftness = Self.clamp(lensSoftness, Self.softnessRange, fallback: 0.23)
        if !RGBA.isValidHex(copy.customAccent) { copy.customAccent = HighlightOptions().customAccent }
        copy.spotlightDim = Self.clamp(spotlightDim, Self.dimRange, fallback: 0.6)
        copy.spotlightSoftness = Self.clamp(spotlightSoftness, Self.edgeRange, fallback: 0)
        copy.spotlightCorner = Self.clamp(spotlightCorner, Self.cornerRange, fallback: 14)
        copy.sonarRings = min(max(sonarRings, Self.ringsRange.lowerBound), Self.ringsRange.upperBound)
        if !fadeAfterStill.isFinite || fadeAfterStill < Self.fadeRange.lowerBound {
            copy.fadeAfterStill = 0
        } else {
            copy.fadeAfterStill = min(fadeAfterStill, Self.fadeRange.upperBound)
        }
        return copy
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
}
