import CoreGraphics
import Foundation

/// The user-chosen accent. `styleDefault` keeps each style's own color.
public enum AccentChoice: String, CaseIterable, Codable, Sendable {
    case styleDefault, coral, iris, amber, blue, teal, white, highContrast, custom

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
        case .custom: "Custom"
        }
    }

    /// nil means "use the style's own accent"; `custom` also reads nil here, its color is in `HighlightOptions`.
    public var color: RGBA? {
        switch self {
        case .styleDefault, .custom: nil
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
    /// One option per style, and fading when still.
    public let options: HighlightOptions

    public init(
        accent: AccentChoice = .styleDefault, size: Double = 1, intensity: Double = 1, lensDim: Double = 0.5,
        options: HighlightOptions = HighlightOptions()
    ) {
        self.options = options.sanitized()
        self.accent = accent
        self.size = CGFloat(Self.clamp(size, Self.sizeRange, fallback: 1))
        // High contrast always draws at full strength.
        self.intensity = accent == .highContrast ? 1 : CGFloat(Self.clamp(intensity, Self.intensityRange, fallback: 1))
        self.lensDim = CGFloat(Self.clamp(lensDim, Self.dimRange, fallback: 0.5))
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }

    /// The chosen color, including a custom one; nil when the style keeps its own.
    public var resolvedAccent: RGBA? {
        accent == .custom ? RGBA(hex: options.customAccent) : accent.color
    }

    /// The same look with the movement toned down, for people who asked their Mac for less motion.
    public func reducingMotion() -> HighlightLook {
        var o = options
        o.auraBreathing = false
        o.cometTail = min(o.cometTail, 0.5)
        o.sonarRings = 1
        return HighlightLook(accent: accent, size: Double(size), intensity: Double(intensity), lensDim: Double(lensDim), options: o)
    }

    /// The accent to draw a style with.
    public func accentColor(for style: HighlightStyle) -> RGBA {
        resolvedAccent ?? Palette.accent(for: style)
    }
}

extension StyleRecipe {
    /// A copy with sizes and the Lens dim taken from `look`. Timing and alphas are untouched.
    public func applying(_ look: HighlightLook, includesStyleOptions: Bool = true) -> StyleRecipe {
        var r = self
        let k = look.size
        if includesStyleOptions {
            let o = look.options
            if !o.auraBreathing { r.aura.breathCycles = 0 }
            r.comet.lifetime *= o.cometTail
            r.comet.maxPoints = min(Int((Double(r.comet.maxPoints) * o.cometTail).rounded()), 120)
            r.keyline.lightWidth *= CGFloat(o.keylineWidth)
            r.keyline.darkWidth *= CGFloat(o.keylineWidth)
            r.sonar.ringCount = o.sonarRings
            r.lens.feather = CGFloat(o.lensSoftness)
            switch o.clickEffect {
            case .ripple: break
            case .doubleRing: r.ripple.duration = 0.62
            case .pulse:
                r.ripple.fillAlpha = 0.5
                r.ripple.startWidth = 1.5
                r.ripple.endWidth = 0.5
                r.ripple.endRadius *= 1.35
            case .burst:
                r.ripple.fillAlpha = 0
                r.ripple.startWidth = 4.5
                r.ripple.endWidth = 2
                r.ripple.endRadius *= 1.45
            }
        }
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
        r.crosshair.gap *= k
        r.crosshair.ringRadius *= k
        r.crosshair.lineWidth *= max(k, 0.8)
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
        recipe = StyleRecipe.laser.applying(look, includesStyleOptions: false)
        accent = look.resolvedAccent ?? Palette.laserDefault
        intensity = look.intensity
    }
}
