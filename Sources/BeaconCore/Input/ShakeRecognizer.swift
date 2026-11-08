import CoreGraphics
import Foundation

/// Detects a rapid back-and-forth cursor shake from timestamped positions. Pure value type: no AppKit, no clocks.
///
/// The recent samples are fitted with a principal axis. A shake is a path that is long along that axis, narrow
/// across it, winding back and forth with enough direction reversals. After a shake it stays quiet for a cooldown.
public struct ShakeRecognizer {
    static let historyWindow: TimeInterval = 0.45
    static let minimumSamples = 11
    static let cooldown: TimeInterval = 1
    /// Steps shorter than this (in points) do not count as a change of direction.
    static let stepThreshold = 4.0
    static let degeneracy = 1e-4

    /// Sensitivity on a 0...100 scale, normalized to 0...1.
    private let t: Double
    private var samples: [(time: TimeInterval, point: CGPoint)] = []
    private var lastTrigger: TimeInterval = -.infinity

    /// - Parameter sensitivity: 0 (hardest to trigger) to 100 (easiest). Non-finite values fall back to 50.
    public init(sensitivity: Double) {
        let s = sensitivity.isFinite ? min(max(sensitivity, 0), 100) : 50
        t = s / 100
    }

    /// Feeds one cursor sample. Returns true on the sample that completes a shake.
    public mutating func feed(position: CGPoint, time: TimeInterval) -> Bool {
        samples.append((time, position))
        samples.removeAll { time - $0.time > Self.historyWindow }
        guard time - lastTrigger > Self.cooldown, samples.count >= Self.minimumSamples else { return false }
        guard isShake() else { return false }
        lastTrigger = time
        samples = []
        return true
    }

    private func isShake() -> Bool {
        let n = Double(samples.count)
        let meanX = samples.reduce(0) { $0 + Double($1.point.x) } / n
        let meanY = samples.reduce(0) { $0 + Double($1.point.y) } / n
        var sxx = 0.0, syy = 0.0, sxy = 0.0
        for sample in samples {
            let dx = Double(sample.point.x) - meanX
            let dy = Double(sample.point.y) - meanY
            sxx += dx * dx
            syy += dy * dy
            sxy += dx * dy
        }
        sxx /= n
        syy /= n
        sxy /= n

        let axis = Self.principalAxis(sxx: sxx, syy: syy, sxy: sxy)
        var minU = Double.infinity, maxU = -Double.infinity
        var minV = Double.infinity, maxV = -Double.infinity
        var us: [Double] = []
        var path = 0.0
        var previous: CGPoint?
        for sample in samples {
            let dx = Double(sample.point.x) - meanX
            let dy = Double(sample.point.y) - meanY
            let u = dx * axis.x + dy * axis.y
            let v = -dx * axis.y + dy * axis.x
            us.append(u)
            minU = min(minU, u)
            maxU = max(maxU, u)
            minV = min(minV, v)
            maxV = max(maxV, v)
            if let previous {
                path += hypot(Double(sample.point.x - previous.x), Double(sample.point.y - previous.y))
            }
            previous = sample.point
        }
        let extent = maxU - minU
        let perpendicular = maxV - minV
        guard extent > 0 else { return false }

        var reversals = 0
        var lastSign = 0
        for index in 1..<us.count {
            let step = us[index] - us[index - 1]
            if abs(step) < Self.stepThreshold { continue }
            let sign = step > 0 ? 1 : -1
            if lastSign != 0, sign != lastSign { reversals += 1 }
            lastSign = sign
        }

        return extent >= 240 - 70 * t && perpendicular <= extent * (0.35 + 0.30 * t)
            && path / extent >= 3.2 - 0.9 * t && Double(reversals) >= 3 - t
    }

    /// The unit vector of the largest-variance direction, or the x axis when the spread has no direction.
    static func principalAxis(sxx: Double, syy: Double, sxy: Double) -> (x: Double, y: Double) {
        let half = (sxx + syy) / 2
        let discriminant = max(half * half - (sxx * syy - sxy * sxy), 0)
        let largest = half + discriminant.squareRoot()
        for (x, y) in [(sxy, largest - sxx), (largest - syy, sxy)] {
            let length = hypot(x, y)
            if length > degeneracy { return (x / length, y / length) }
        }
        return (1, 0)
    }
}
