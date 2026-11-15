import CoreGraphics
import Foundation

/// Spring constants in the mass / tension / friction form used by the design brief.
/// omega = sqrt(tension / mass), zeta = friction / (2 * sqrt(tension * mass)).
public struct SpringParameters: Equatable, Sendable {
    public let tension: Double
    public let mass: Double
    public let friction: Double

    public init(tension: Double, mass: Double = 1, friction: Double) {
        self.tension = max(tension, 0.0001)
        self.mass = max(mass, 0.0001)
        self.friction = max(friction, 0)
    }

    public var omega: Double { (tension / mass).squareRoot() }
    public var zeta: Double { friction / (2 * (tension * mass).squareRoot()) }

    /// omega 20, zeta 1, settles in about 200 ms. The live default.
    public static let standard = SpringParameters(tension: 400, friction: 40)
    /// omega 14, zeta 1, settles in about 285 ms. For big soft bodies.
    public static let silk = SpringParameters(tension: 196, friction: 28)
    /// omega 25, zeta 1, settles in about 160 ms. For small bright heads.
    public static let snappy = SpringParameters(tension: 625, friction: 50)
}

/// Exact solutions of the damped spring x'' = -omega^2 x - 2 zeta omega x'. Being closed form, a step is exact
/// for any time delta, so dropped frames never destabilize or speed up the motion.
public enum SpringMath {
    /// Advances a displacement from the target and its velocity by `dt` seconds.
    public static func step(
        displacement x0: Double, velocity v0: Double, dt: Double, omega: Double, zeta: Double
    ) -> (displacement: Double, velocity: Double) {
        guard dt > 0, omega > 0 else { return (x0, v0) }
        let t = dt
        if abs(zeta - 1) < 1e-6 {
            let e = exp(-omega * t)
            let b = v0 + omega * x0
            return ((x0 + b * t) * e, (v0 - omega * b * t) * e)
        }
        if zeta < 1 {
            let wd = omega * (1 - zeta * zeta).squareRoot()
            let e = exp(-zeta * omega * t)
            let c = cos(wd * t)
            let s = sin(wd * t)
            let x = e * (x0 * c + (v0 + zeta * omega * x0) / wd * s)
            let v = e * (v0 * c - (zeta * omega * v0 + omega * omega * x0) / wd * s)
            return (x, v)
        }
        let root = (zeta * zeta - 1).squareRoot()
        let r1 = -omega * (zeta - root)
        let r2 = -omega * (zeta + root)
        let c2 = (v0 - r1 * x0) / (r2 - r1)
        let c1 = x0 - c2
        let e1 = exp(r1 * t)
        let e2 = exp(r2 * t)
        return (c1 * e1 + c2 * e2, r1 * c1 * e1 + r2 * c2 * e2)
    }
}

/// A 2D point that follows a moving target on a spring. Retargeting only changes the target: position and velocity
/// carry over, so the motion never restarts or jumps. Once within `restDistance` and slower than `restSpeed`, it
/// snaps onto the target exactly, so a resting highlight sits at zero offset from the pointer.
public struct SpringFollower: Equatable, Sendable {
    /// Largest residual offset that is snapped away, in points (half a pixel on Retina).
    public static let restDistance: CGFloat = 0.25
    /// Largest speed, in points per second, at which the residual is snapped away.
    public static let restSpeed: CGFloat = 15
    /// Longest time step taken at once; a longer gap (a hitch, a wake from pause) is clamped.
    public static let maximumStep: TimeInterval = 0.1

    public var parameters: SpringParameters
    public var target: CGPoint
    public private(set) var position: CGPoint
    public private(set) var velocity: CGVector

    public init(parameters: SpringParameters = .standard, position: CGPoint = .zero) {
        self.parameters = parameters
        self.position = position
        self.target = position
        self.velocity = .zero
    }

    /// True when the follower sits exactly on its target with no velocity.
    public var isSettled: Bool { position == target && velocity == .zero }

    public var speed: CGFloat { hypot(velocity.dx, velocity.dy) }

    /// Jumps to a point with no motion (used when the highlight appears, so it never flies in from far away).
    public mutating func reset(to point: CGPoint) {
        position = point
        target = point
        velocity = .zero
    }

    public mutating func step(dt: TimeInterval) {
        let dt = min(max(dt, 0), Self.maximumStep)
        guard dt > 0, !isSettled else { return }
        let omega = parameters.omega
        let zeta = parameters.zeta
        let x = SpringMath.step(
            displacement: Double(position.x - target.x), velocity: Double(velocity.dx), dt: dt, omega: omega, zeta: zeta
        )
        let y = SpringMath.step(
            displacement: Double(position.y - target.y), velocity: Double(velocity.dy), dt: dt, omega: omega, zeta: zeta
        )
        position = CGPoint(x: target.x + CGFloat(x.displacement), y: target.y + CGFloat(y.displacement))
        velocity = CGVector(dx: CGFloat(x.velocity), dy: CGFloat(y.velocity))
        let offset = hypot(position.x - target.x, position.y - target.y)
        if offset < Self.restDistance && speed < Self.restSpeed {
            position = target
            velocity = .zero
        }
    }
}

/// A scalar on a spring (press shrink and similar). Same exact stepping and snap as `SpringFollower`.
public struct ScalarSpring: Equatable, Sendable {
    public var omega: Double
    public var zeta: Double
    public var target: Double
    public private(set) var value: Double
    public private(set) var velocity: Double = 0

    public init(value: Double, omega: Double, zeta: Double = 1) {
        self.value = value
        self.target = value
        self.omega = omega
        self.zeta = zeta
    }

    public var isSettled: Bool { value == target && velocity == 0 }

    public mutating func step(dt: TimeInterval) {
        let dt = min(max(dt, 0), SpringFollower.maximumStep)
        guard dt > 0, !isSettled else { return }
        let next = SpringMath.step(displacement: value - target, velocity: velocity, dt: dt, omega: omega, zeta: zeta)
        value = target + next.displacement
        velocity = next.velocity
        if abs(value - target) < 0.0005 && abs(velocity) < 0.01 {
            value = target
            velocity = 0
        }
    }
}
