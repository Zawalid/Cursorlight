import CoreGraphics
import Foundation

/// The five looks of the cursor highlight. Raw values are persisted.
public enum HighlightStyle: String, CaseIterable, Sendable {
    case aura, lens, comet, keyline, sonar

    public var displayName: String {
        switch self {
        case .aura: "Aura"
        case .lens: "Lens"
        case .comet: "Comet"
        case .keyline: "Keyline"
        case .sonar: "Sonar"
        }
    }

    public var recipe: StyleRecipe { StyleRecipe.recipe(for: self) }
}

/// Soft frosted glow: three stacked radial layers, stretched along velocity, breathing at rest.
public struct AuraRecipe: Equatable, Sendable {
    public init() {}

    public var radius: CGFloat = 42
    /// (radius as a fraction of `radius`, alpha, gaussian blur in points).
    public var core = GlowLayerRecipe(radiusFactor: 0.45, alpha: 0.35, blur: 14)
    public var mid = GlowLayerRecipe(radiusFactor: 1.0, alpha: 0.16, blur: 12)
    public var outer = GlowLayerRecipe(radiusFactor: 1.9, alpha: 0.06, blur: 32)
    /// How far the core color moves from the accent toward white (light core, judgment: reads as frosted light
    /// on dark apps instead of a muddy tint).
    public var coreLightness: CGFloat = 0.75
    public var keylineWidth: CGFloat = 1
    /// Brief: optional, 0.25. Lowered (judgment) so it defines the glow on white without reading as a drawn ring.
    public var keylineAlpha: CGFloat = 0.18
    public var stretch: CGFloat = 1.3
    public var squash: CGFloat = 0.9
    /// Speed (pt/s) at which the stretch reaches its maximum.
    public var stretchSpeed: CGFloat = 1800
    public var breathScale: CGFloat = 1.04
    public var breathAlpha: CGFloat = 0.03
    public var breathPeriod: TimeInterval = 2.4
    /// Breathing stops after this many cycles so the idle state comes to rest.
    public var breathCycles: Double = 3
    /// Scale the bloom starts from when the highlight appears.
    public var bloomFrom: CGFloat = 0.6
}

public struct GlowLayerRecipe: Equatable, Sendable {
    public var radiusFactor: CGFloat
    public var alpha: CGFloat
    public var blur: CGFloat

    public init(radiusFactor: CGFloat, alpha: CGFloat, blur: CGFloat) {
        self.radiusFactor = radiusFactor
        self.alpha = alpha
        self.blur = blur
    }
}

/// A lit circle in a dimmed room.
public struct LensRecipe: Equatable, Sendable {
    public init() {}

    public var radius: CGFloat = 120
    /// The edge goes from clear to full dim over the outer 23 % of the radius.
    public var feather: CGFloat = 0.23
    public var dim: CGFloat = 0.50
    /// Entrance: the hole closes in from 2.2 R to R while the dim fades in.
    public var entranceScale: CGFloat = 2.2
    public var pressScale: CGFloat = 0.8
    public var pressDuration: TimeInterval = 0.12
    /// Faint warm lift inside the hole so the lit circle reads on dark apps too.
    public var washAlpha: CGFloat = 0.06
}

/// A bright head with a tapering tail.
public struct CometRecipe: Equatable, Sendable {
    public init() {}

    public var lifetime: TimeInterval = 0.4
    public var headWidth: CGFloat = 10
    public var tailWidth: CGFloat = 1
    public var widthPower: Double = 1.6
    public var headAlpha: CGFloat = 0.95
    public var alphaPower: Double = 1.5
    public var coreWidth: CGFloat = 3
    public var glowWidth: CGFloat = 14
    public var glowAlpha: CGFloat = 0.45
    public var headDiameter: CGFloat = 14
    public var headHaloDiameter: CGFloat = 28
    /// Hue rotation from head to tail, in degrees.
    public var hueShift: Double = -25
    public var maxPoints: Int = 48
    public var spacing: CGFloat = 5
    /// Below this speed (pt/s) the tail retracts within `dwellShrink` seconds.
    public var dwellSpeed: CGFloat = 40
    public var dwellShrink: TimeInterval = 0.15
}

/// A thin two-tone ring that reads on any app.
public struct KeylineRecipe: Equatable, Sendable {
    public init() {}

    public var radius: CGFloat = 28
    public var lightWidth: CGFloat = 3
    public var darkWidth: CGFloat = 1
    public var darkAlpha: CGFloat = 0.35
    /// Hairline just inside the light band, so the ring also has an inner edge on white apps (judgment).
    public var innerDarkAlpha: CGFloat = 0.2
    public var dotDiameter: CGFloat = 4
    /// Velocity lead, applied to the drawn ring only and never past the pointer.
    public var predictionLead: TimeInterval = 0.012
    public var predictionClamp: CGFloat = 12
    public var pressScale: CGFloat = 0.85
    public var pressDuration: TimeInterval = 0.12
    /// Scale the ring settles from when it appears.
    public var appearFrom: CGFloat = 1.5
}

/// Hidden until summoned, then concentric pulses lock onto a compact dot that stays.
public struct SonarRecipe: Equatable, Sendable {
    public init() {}

    public var ringCount = 3
    public var startRadius: CGFloat = 140
    public var endRadius: CGFloat = 20
    public var ringDuration: TimeInterval = 0.6
    public var stagger: TimeInterval = 0.08
    public var ringAlpha: CGFloat = 0.5
    public var ringWidth: CGFloat = 3
    public var dotRadius: CGFloat = 18
    public var dotCoreRadius: CGFloat = 5
    public var dotDelay: TimeInterval = 0.3
    public var dotAppear: TimeInterval = 0.45
}

/// The expanding ring that marks the moment the highlight appears.
public struct PulseRecipe: Equatable, Sendable {
    public var startRadius: CGFloat
    public var endRadius: CGFloat
    public var duration: TimeInterval = 0.6
    public var alpha: CGFloat = 0.45
    public var startWidth: CGFloat = 3
    public var endWidth: CGFloat = 1.5

    public init(startRadius: CGFloat, endRadius: CGFloat) {
        self.startRadius = startRadius
        self.endRadius = endRadius
    }
}

/// Click ripple numbers; see `RippleCurve`.
public struct RippleRecipe: Equatable, Sendable {
    public var duration: TimeInterval = 0.52
    public var startRadius: CGFloat = 10
    public var endRadius: CGFloat = 40
    public var startWidth: CGFloat = 3
    public var endWidth: CGFloat = 1.5
    public var fillAlpha: CGFloat = 0.18
    public var alpha: CGFloat = 0.7
    public var alphaPower: Double = 1.5
    /// Ring drawn in the light color instead of the accent.
    public var lightRing = false
    /// Mouse-down press ring shrinks to this fraction of its size over `pressDuration`.
    public var pressScale: CGFloat = 0.85
    public var pressDuration: TimeInterval = 0.12
    public var maxConcurrent = 6

    public init(
        duration: TimeInterval = 0.52, startWidth: CGFloat = 3, endWidth: CGFloat = 1.5,
        fillAlpha: CGFloat = 0.18, lightRing: Bool = false
    ) {
        self.duration = duration
        self.startWidth = startWidth
        self.endWidth = endWidth
        self.fillAlpha = fillAlpha
        self.lightRing = lightRing
    }
}

/// Everything one style needs, in one value. Numbers come from the design brief
/// (docs/research/2026-11-11-design-primitives.md); fields marked judgment there are tuned here.
public struct StyleRecipe: Equatable, Sendable {
    public var spring: SpringParameters
    public var appearDuration: TimeInterval
    public var disappearDuration: TimeInterval = 0.25
    public var pulse: PulseRecipe?
    public var ripple: RippleRecipe
    public var aura = AuraRecipe()
    public var lens = LensRecipe()
    public var comet = CometRecipe()
    public var keyline = KeylineRecipe()
    public var sonar = SonarRecipe()

    public static func recipe(for style: HighlightStyle) -> StyleRecipe {
        switch style {
        case .aura:
            StyleRecipe(
                spring: .standard, appearDuration: 0.45,
                pulse: PulseRecipe(startRadius: 42, endRadius: 92),
                ripple: RippleRecipe()
            )
        case .lens:
            StyleRecipe(
                spring: .silk, appearDuration: 0.4, pulse: nil,
                ripple: RippleRecipe(startWidth: 2, endWidth: 2, fillAlpha: 0, lightRing: true)
            )
        case .comet:
            StyleRecipe(
                spring: .snappy, appearDuration: 0.4,
                pulse: PulseRecipe(startRadius: 8, endRadius: 44),
                ripple: RippleRecipe()
            )
        case .keyline:
            // No separate pulse: the ring settling in from 1.5x is the entrance (one effect per moment).
            StyleRecipe(
                spring: .standard, appearDuration: 0.4, pulse: nil,
                ripple: RippleRecipe(duration: 0.45, fillAlpha: 0, lightRing: true)
            )
        case .sonar:
            StyleRecipe(
                spring: .standard, appearDuration: 0.76, pulse: nil,
                ripple: RippleRecipe()
            )
        }
    }
}
