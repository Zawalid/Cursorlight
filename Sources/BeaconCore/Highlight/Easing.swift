import Foundation

/// A CSS-style cubic Bezier timing curve from (0, 0) to (1, 1).
public struct CubicBezier: Equatable, Sendable {
    public let x1: Double, y1: Double, x2: Double, y2: Double

    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// Eased value for progress `t`, clamped to 0...1.
    public func callAsFunction(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        if t == 0 || t == 1 { return t }
        return sample(y1, y2, solve(t))
    }

    /// Progress whose eased value is `value` (the curves used here are monotonic). Clamped to 0...1.
    public func inverse(_ value: Double) -> Double {
        let target = min(max(value, 0), 1)
        var low = 0.0, high = 1.0
        for _ in 0..<50 {
            let mid = (low + high) / 2
            if self(mid) < target { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }

    private func sample(_ a: Double, _ b: Double, _ s: Double) -> Double {
        let u = 1 - s
        return 3 * u * u * s * a + 3 * u * s * s * b + s * s * s
    }

    private func slope(_ a: Double, _ b: Double, _ s: Double) -> Double {
        let u = 1 - s
        return 3 * u * u * a + 6 * u * s * (b - a) + 3 * s * s * (1 - b)
    }

    /// Finds the curve parameter whose x equals `x`: Newton first, bisection as the fallback.
    private func solve(_ x: Double) -> Double {
        var s = x
        for _ in 0..<8 {
            let error = sample(x1, x2, s) - x
            if abs(error) < 1e-7 { return s }
            let d = slope(x1, x2, s)
            if abs(d) < 1e-6 { break }
            s -= error / d
        }
        var low = 0.0, high = 1.0
        s = x
        for _ in 0..<40 {
            let value = sample(x1, x2, s)
            if abs(value - x) < 1e-7 { return s }
            if value < x { low = s } else { high = s }
            s = (low + high) / 2
        }
        return s
    }
}

/// The curves the brief allows. Nothing here is linear or the default ease-in-out.
public enum Easing {
    /// Entrances: fast in, long soft landing (.16, 1, .3, 1).
    public static let outExpo = CubicBezier(0.16, 1, 0.3, 1)
    /// Exits: gentle start, quick finish (.4, 0, 1, 1).
    public static let easeIn = CubicBezier(0.4, 0, 1, 1)

    public static func outCubic(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        let u = 1 - t
        return 1 - u * u * u
    }

    /// Hermite smoothstep of `x` between two edges.
    public static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 != edge0 else { return x < edge0 ? 0 : 1 }
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Power decay used for every fade: (1 - t)^power, clamped.
    public static func decay(_ t: Double, power: Double) -> Double {
        let t = min(max(t, 0), 1)
        return pow(1 - t, power)
    }

    /// A scale pop on an underdamped spring (zeta below 1 is allowed for scale, never for position). Starts at
    /// `from` and settles on 1 with a few percent of overshoot.
    public static func pop(_ elapsed: Double, from: Double, omega: Double = 18, zeta: Double = 0.75) -> Double {
        guard elapsed > 0 else { return from }
        let state = SpringMath.step(displacement: from - 1, velocity: 0, dt: elapsed, omega: omega, zeta: zeta)
        return 1 + state.displacement
    }
}
