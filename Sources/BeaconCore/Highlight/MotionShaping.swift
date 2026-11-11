import CoreGraphics
import Foundation

/// Stretch along the direction of motion, so the follower's lag reads as motion instead of error.
public struct VelocityStretch: Equatable, Sendable {
    /// Scale along the velocity.
    public var along: CGFloat
    /// Scale across the velocity.
    public var across: CGFloat
    /// Direction of the velocity in radians.
    public var angle: CGFloat

    public static let identity = VelocityStretch(along: 1, across: 1, angle: 0)

    /// Stretch grows with speed on a smoothstep and reaches its maximum at `fullSpeed`.
    public static func of(velocity: CGVector, stretch: CGFloat, squash: CGFloat, fullSpeed: CGFloat) -> VelocityStretch {
        let speed = hypot(velocity.dx, velocity.dy)
        guard speed > 0, fullSpeed > 0 else { return .identity }
        let k = CGFloat(Easing.smoothstep(0, Double(fullSpeed), Double(speed)))
        return VelocityStretch(
            along: 1 + (stretch - 1) * k, across: 1 - (1 - squash) * k, angle: atan2(velocity.dy, velocity.dx)
        )
    }

    public var transform: CGAffineTransform {
        CGAffineTransform(rotationAngle: angle).scaledBy(x: along, y: across).rotated(by: -angle)
    }
}

/// Short velocity prediction for the drawn ring. It only shaves the follower's average delay: the drawn point moves
/// from the follower toward the pointer by the velocity's component in that direction times `lead`, at most `clamp`
/// points and never past the pointer. At rest (no velocity, no gap) it is exactly the follower.
public enum PredictiveLead {
    public static func drawn(
        follower: CGPoint, velocity: CGVector, pointer: CGPoint, lead: TimeInterval, clamp: CGFloat
    ) -> CGPoint {
        let gx = pointer.x - follower.x
        let gy = pointer.y - follower.y
        let gap = hypot(gx, gy)
        guard gap > 0 else { return follower }
        let ux = gx / gap
        let uy = gy / gap
        let toward = (velocity.dx * ux + velocity.dy * uy) * CGFloat(lead)
        let distance = min(max(toward, 0), clamp, gap)
        return CGPoint(x: follower.x + ux * distance, y: follower.y + uy * distance)
    }
}
