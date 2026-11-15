import CoreGraphics
import Foundation

/// One drawn point of a trail.
public struct TrailPoint: Equatable, Sendable {
    public var point: CGPoint
    /// 0 at the head, 1 at the end of the lifetime.
    public var age: Double
    public var width: CGFloat
    public var alpha: CGFloat
}

/// Time-stamped trail samples. Points live for a fixed lifetime measured in event time, never by count, so the
/// tail is the same length at 60 Hz, 120 Hz or with dropped frames. While the head dwells, the clock that ages the
/// samples runs faster, so the tail retracts within `dwellShrink` seconds instead of smearing.
public struct TrailBuffer: Equatable, Sendable {
    public struct Sample: Equatable, Sendable {
        public var point: CGPoint
        /// Time on the trail's aging clock.
        public var time: TimeInterval
    }

    public let recipe: CometRecipe
    /// Committed samples, oldest first. The newest point is `head` and is not committed until it has moved
    /// `spacing` away from the last committed one.
    public private(set) var samples: [Sample] = []
    public private(set) var head: Sample?
    /// Aging clock: advances with real time, faster while dwelling.
    public private(set) var clock: TimeInterval = 0
    private var lastTime: TimeInterval?

    public init(recipe: CometRecipe = CometRecipe()) {
        self.recipe = recipe
    }

    public var isEmpty: Bool { samples.isEmpty }

    public mutating func reset() {
        samples = []
        head = nil
        lastTime = nil
    }

    /// Adds the head position at event time `time`; `speed` is the head speed in pt/s (drives the dwell).
    public mutating func append(_ point: CGPoint, at time: TimeInterval, speed: CGFloat) {
        // Real elapsed time (a dropped frame ages the tail exactly as much as it should); only a long pause is cut.
        let dt = lastTime.map { min(max(time - $0, 0), 1) } ?? 0
        lastTime = time
        let dwelling = speed < recipe.dwellSpeed
        let rate = dwelling ? max(recipe.lifetime / recipe.dwellShrink, 1) : 1
        clock += dt * rate

        let sample = Sample(point: point, time: clock)
        // Spacing widens with speed so a full lifetime of tail fits in `maxPoints` without dropping its end.
        let spacing = max(recipe.spacing, speed * CGFloat(recipe.lifetime) / CGFloat(max(recipe.maxPoints - 2, 1)))
        if let anchor = samples.last {
            if hypot(point.x - anchor.point.x, point.y - anchor.point.y) >= spacing {
                samples.append(sample)
                head = nil
            } else {
                // Not far enough from the last committed point: only the live head moves.
                head = sample
            }
        } else if let head, head.point != point {
            // Leaving rest: the resting point becomes the first committed sample.
            samples.append(head)
            self.head = sample
        } else {
            // At rest the head only refreshes, so a resting comet never refills its buffer.
            head = sample
        }
        prune()
        decimate()
    }

    /// Drops samples whose age reached the lifetime.
    private mutating func prune() {
        samples.removeAll { clock - $0.time >= recipe.lifetime }
    }

    /// Safety cap (speed-adaptive spacing normally keeps the count below it): keeps at most `maxPoints` by removing
    /// every other sample in the older half. The oldest sample stays, so the time span is unchanged.
    private mutating func decimate() {
        guard samples.count > recipe.maxPoints else { return }
        let half = samples.count / 2
        var kept: [Sample] = []
        kept.reserveCapacity(recipe.maxPoints)
        for (index, sample) in samples.enumerated() where index >= half || index % 2 == 0 {
            kept.append(sample)
        }
        samples = kept
    }

    /// Width for an age fraction: head width to tail width with a power taper.
    public static func width(age: Double, recipe: CometRecipe) -> CGFloat {
        recipe.tailWidth + (recipe.headWidth - recipe.tailWidth) * CGFloat(Easing.decay(age, power: recipe.widthPower))
    }

    public static func alpha(age: Double, recipe: CometRecipe) -> CGFloat {
        recipe.headAlpha * CGFloat(Easing.decay(age, power: recipe.alphaPower))
    }

    /// Points from tail to head with width and alpha. The head point is always last.
    public func tapered() -> [TrailPoint] {
        var all = samples
        if let head { all.append(head) }
        return all.map { sample in
            let age = min(max((clock - sample.time) / recipe.lifetime, 0), 1)
            return TrailPoint(
                point: sample.point, age: age,
                width: Self.width(age: age, recipe: recipe), alpha: Self.alpha(age: age, recipe: recipe)
            )
        }
    }

    /// Age of the oldest live sample, in seconds of the aging clock.
    public var span: TimeInterval {
        guard let first = samples.first ?? head else { return 0 }
        return clock - first.time
    }
}

/// Centripetal-free uniform Catmull-Rom subdivision of a trail, interpolating width and alpha too.
public enum CatmullRom {
    public static func smooth(_ points: [TrailPoint], subdivisions: Int = 3) -> [TrailPoint] {
        guard points.count > 2, subdivisions > 1 else { return points }
        var result: [TrailPoint] = []
        result.reserveCapacity(points.count * subdivisions)
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            for step in 0..<subdivisions {
                let t = CGFloat(step) / CGFloat(subdivisions)
                let point = CGPoint(
                    x: spline(p0.point.x, p1.point.x, p2.point.x, p3.point.x, t),
                    y: spline(p0.point.y, p1.point.y, p2.point.y, p3.point.y, t)
                )
                result.append(TrailPoint(
                    point: point,
                    age: p1.age + (p2.age - p1.age) * Double(t),
                    width: p1.width + (p2.width - p1.width) * t,
                    alpha: p1.alpha + (p2.alpha - p1.alpha) * t
                ))
            }
        }
        if let last = points.last { result.append(last) }
        return result
    }

    private static func spline(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat, _ t: CGFloat) -> CGFloat {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
    }
}
