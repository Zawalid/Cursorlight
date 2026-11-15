import CoreGraphics
import Foundation

/// A ring at one moment: what the renderer draws for ripples, press rings, summon pulses and sonar rings.
public struct RingState: Equatable, Sendable {
    public var center: CGPoint
    public var radius: CGFloat
    public var lineWidth: CGFloat
    public var alpha: CGFloat
    public var fillAlpha: CGFloat = 0
    public var button: MouseButton = .left
    /// Drawn as a ring of short dashes, for the burst.
    public var dashed = false
}

/// Click ripple shape over normalized time t in 0...1: radius eases out (cubic), the stroke thins linearly, the
/// fill and the alpha decay by a power curve: alpha = 0.7 * (1 - t)^1.5.
public struct RippleCurve: Equatable, Sendable {
    public let recipe: RippleRecipe

    public init(recipe: RippleRecipe = RippleRecipe()) {
        self.recipe = recipe
    }

    public func radius(_ t: Double, from start: CGFloat? = nil) -> CGFloat {
        let r0 = start ?? recipe.startRadius
        return r0 + (recipe.endRadius - r0) * CGFloat(Easing.outCubic(t))
    }

    public func lineWidth(_ t: Double) -> CGFloat {
        let t = CGFloat(min(max(t, 0), 1))
        return recipe.startWidth + (recipe.endWidth - recipe.startWidth) * t
    }

    public func alpha(_ t: Double) -> CGFloat {
        recipe.alpha * CGFloat(Easing.decay(t, power: recipe.alphaPower))
    }

    public func fillAlpha(_ t: Double) -> CGFloat {
        recipe.fillAlpha * CGFloat(Easing.decay(t, power: recipe.alphaPower))
    }

    public func ring(at t: Double, center: CGPoint, from start: CGFloat? = nil, button: MouseButton) -> RingState {
        RingState(
            center: center, radius: radius(t, from: start), lineWidth: lineWidth(t),
            alpha: alpha(t), fillAlpha: fillAlpha(t), button: button
        )
    }

    /// Radius of the mouse-down press ring, sized so that after shrinking it hands over to the ripple's start
    /// radius without a jump.
    public var pressRadius: CGFloat { recipe.startRadius / recipe.pressScale }

    /// The press ring `elapsed` seconds after mouse down: shrinks to `pressScale` and fades in over 120 ms.
    public func press(elapsed: TimeInterval, center: CGPoint, button: MouseButton) -> RingState {
        let k = CGFloat(Easing.outCubic(elapsed / recipe.pressDuration))
        return RingState(
            center: center, radius: pressRadius * (1 - (1 - recipe.pressScale) * k),
            lineWidth: recipe.startWidth, alpha: recipe.alpha * k, fillAlpha: recipe.fillAlpha * k, button: button
        )
    }
}

/// The ring that marks the moment the highlight appears.
public enum SummonPulse {
    public static func ring(_ recipe: PulseRecipe, elapsed: TimeInterval, center: CGPoint) -> RingState? {
        let t = elapsed / recipe.duration
        guard t >= 0, t < 1 else { return nil }
        let eased = CGFloat(Easing.outCubic(t))
        return RingState(
            center: center,
            radius: recipe.startRadius + (recipe.endRadius - recipe.startRadius) * eased,
            lineWidth: recipe.startWidth + (recipe.endWidth - recipe.startWidth) * CGFloat(t),
            alpha: recipe.alpha * CGFloat(Easing.decay(t, power: 1.5))
        )
    }

    /// Sonar rings closing in on the dot, staggered. A ring fades in over its first 12 % so it never pops in.
    public static func sonarRings(_ recipe: SonarRecipe, elapsed: TimeInterval, center: CGPoint) -> [RingState] {
        (0..<recipe.ringCount).compactMap { index in
            let t = (elapsed - Double(index) * recipe.stagger) / recipe.ringDuration
            guard t >= 0, t < 1 else { return nil }
            let eased = CGFloat(Easing.outCubic(t))
            let fadeIn = CGFloat(min(t / 0.12, 1))
            return RingState(
                center: center,
                radius: recipe.startRadius + (recipe.endRadius - recipe.startRadius) * eased,
                lineWidth: recipe.ringWidth,
                alpha: recipe.ringAlpha * fadeIn * CGFloat(Easing.decay(t, power: 1.5))
            )
        }
    }
}
