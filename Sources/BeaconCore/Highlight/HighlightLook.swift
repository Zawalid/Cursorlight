import CoreGraphics
import Foundation

/// The user-chosen accent. `styleDefault` keeps each style's own color.
public enum AccentChoice: String, CaseIterable, Codable, Sendable {
    case styleDefault, coral, iris, amber, blue, teal, white, highContrast

    public var displayName: String {
        switch self {
        case .styleDefault: "Style default"
        case .coral: "Coral"
        case .iris: "Iris"
        case .amber: "Amber"
        case .blue: "Blue"
        case .teal: "Teal"
        case .white: "White"
        case .highContrast: "High contrast"
        }
    }

    /// nil means "use the style's own accent".
    public var color: RGBA? {
        switch self {
        case .styleDefault: nil
        case .coral: RGBA(hex: Branding.accentHex)
        case .iris: RGBA(hex: "#8B7CFF")
        case .amber: RGBA(hex: "#E8932A")
        case .blue: RGBA(hex: "#4DA3FF")
        case .teal: RGBA(hex: "#14B8A6")
        case .white: RGBA(hex: "#F5F5F7")
        case .highContrast: RGBA(hex: "#FFD60A")
        }
    }
}

/// How the user's appearance settings change a style. Pure value; every field is clamped by `init`.
public struct HighlightLook: Equatable, Sendable {
    public static let sizeRange: ClosedRange<Double> = 0.6...1.8
    public static let intensityRange: ClosedRange<Double> = 0.3...1.0
    public static let dimRange: ClosedRange<Double> = 0.2...0.85

    public static let standard = HighlightLook()

    public let accent: AccentChoice
    /// Multiplies every radius.
    public let size: CGFloat
    /// Overall opacity of the highlight and ripples, 0.3...1.
    public let intensity: CGFloat
    /// Strength of the Lens dim.
    public let lensDim: CGFloat

    public init(accent: AccentChoice = .styleDefault, size: Double = 1, intensity: Double = 1, lensDim: Double = 0.5) {
        self.accent = accent
        self.size = CGFloat(Self.clamp(size, Self.sizeRange, fallback: 1))
        // High contrast always draws at full strength.
        self.intensity = accent == .highContrast ? 1 : CGFloat(Self.clamp(intensity, Self.intensityRange, fallback: 1))
        self.lensDim = CGFloat(Self.clamp(lensDim, Self.dimRange, fallback: 0.5))
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }

    /// The accent to draw a style with.
    public func accentColor(for style: HighlightStyle) -> RGBA {
        accent.color ?? Palette.accent(for: style)
    }
}

extension StyleRecipe {
    /// A copy with sizes and the Lens dim taken from `look`. Timing and alphas are untouched.
    public func applying(_ look: HighlightLook) -> StyleRecipe {
        var r = self
        let k = look.size
        r.aura.radius *= k
        r.aura.core.blur *= k
        r.aura.mid.blur *= k
        r.aura.outer.blur *= k
        r.lens.radius *= k
        r.lens.dim = look.lensDim
        r.comet.headWidth *= k
        r.comet.coreWidth *= k
        r.comet.glowWidth *= k
        r.comet.headDiameter *= k
        r.comet.headHaloDiameter *= k
        r.keyline.radius *= k
        r.keyline.dotDiameter *= k
        r.sonar.startRadius *= k
        r.sonar.endRadius *= k
        r.sonar.dotRadius *= k
        r.sonar.dotCoreRadius *= k
        r.pulse?.startRadius *= k
        r.pulse?.endRadius *= k
        r.ripple.startRadius *= k
        r.ripple.endRadius *= k
        return r
    }

    /// The laser pointer: a long, bright comet trail with no pulse and no ripples. Meant for a held key.
    public static var laser: StyleRecipe {
        var r = StyleRecipe.recipe(for: .comet)
        r.appearDuration = 0.15
        r.disappearDuration = 0.35
        r.pulse = nil
        r.ripple.maxConcurrent = 0
        r.comet.lifetime = 0.9
        r.comet.headWidth = 14
        r.comet.coreWidth = 4
        r.comet.glowWidth = 18
        r.comet.maxPoints = 64
        r.comet.hueShift = -10
        return r
    }
}

extension Palette {
    /// Laser color when the user keeps the style default.
    public static let laserDefault = RGBA(hex: "#FF3B30")
}

/// Everything a renderer needs to draw one layer stack. Equal specs draw identically, so the renderer rebuilds only
/// when the spec changes.
struct RenderSpec: Equatable {
    var style: HighlightStyle
    var recipe: StyleRecipe
    var accent: RGBA
    var intensity: CGFloat

    init(style: HighlightStyle, look: HighlightLook) {
        self.style = style
        recipe = style.recipe.applying(look)
        accent = look.accentColor(for: style)
        intensity = look.intensity
    }

    /// The laser: comet drawing with the laser recipe and a laser color.
    init(laserLook look: HighlightLook) {
        style = .comet
        recipe = StyleRecipe.laser.applying(look)
        accent = look.accent.color ?? Palette.laserDefault
        intensity = look.intensity
    }
}
