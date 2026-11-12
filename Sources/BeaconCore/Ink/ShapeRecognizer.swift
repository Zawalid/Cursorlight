import CoreGraphics
import Foundation

/// What a hand-drawn stroke was meant to be.
public enum RecognizedShape: Equatable, Sendable {
    case ellipse(CGRect)
    case rectangle(CGRect)
    case arrow(from: CGPoint, to: CGPoint)
    /// A horizontal line; both ends share one y.
    case underline(from: CGPoint, to: CGPoint)
    case line(from: CGPoint, to: CGPoint)
    case triangle([CGPoint])
    case diamond(CGRect)
    case none

    /// Which switch in `InkShapeSet` governs this shape.
    public var kind: InkShapeSet? {
        switch self {
        case .ellipse: .ellipse
        case .rectangle: .rectangle
        case .arrow: .arrow
        case .underline: .underline
        case .line: .line
        case .triangle: .triangle
        case .diamond: .diamond
        case .none: nil
        }
    }

    /// The shape as a polyline with exactly `count` points, ordered to start where the raw stroke started and wind
    /// the same way, so a raw stroke can morph into it point by point. nil for `.none`.
    public func polyline(count: Int, matching raw: [CGPoint]) -> [CGPoint]? {
        let n = max(count, 2)
        switch self {
        case .none:
            return nil
        case let .triangle(vertices):
            return Self.closedRing(vertices, matching: raw, count: n)
        case let .diamond(rect):
            return Self.closedRing([
                CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY),
            ], matching: raw, count: n)
        case let .line(a, b), let .underline(a, b):
            return Polyline.resample([a, b], count: n)
        case let .arrow(from, to):
            let heading = atan2(to.y - from.y, to.x - from.x)
            let length = hypot(to.x - from.x, to.y - from.y)
            let wing = min(max(length * 0.22, 18), 48)
            let spread = 28 * Double.pi / 180
            func wingPoint(_ side: Double) -> CGPoint {
                let a = heading + .pi + side * spread
                return CGPoint(x: to.x + wing * CGFloat(cos(a)), y: to.y + wing * CGFloat(sin(a)))
            }
            return Polyline.resample([from, to, wingPoint(1), to, wingPoint(-1)], count: n)
        case let .ellipse(rect):
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let rx = rect.width / 2, ry = rect.height / 2
            let start = raw.first.map { atan2(($0.y - c.y) / max(ry, 1), ($0.x - c.x) / max(rx, 1)) } ?? 0
            let direction: Double = Polyline.signedArea(raw) < 0 ? -1 : 1
            return (0..<n).map { i in
                let a = start + direction * 2 * .pi * Double(i) / Double(n - 1)
                return CGPoint(x: c.x + rx * CGFloat(cos(a)), y: c.y + ry * CGFloat(sin(a)))
            }
        case let .rectangle(rect):
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.minY),
            ]
            var ring = Polyline.resample(corners, count: n)
            ring.removeLast()
            if let first = raw.first, let nearest = ring.indices.min(by: {
                hypot(ring[$0].x - first.x, ring[$0].y - first.y) < hypot(ring[$1].x - first.x, ring[$1].y - first.y)
            }) {
                ring = Array(ring[nearest...] + ring[..<nearest])
            }
            if Polyline.signedArea(raw) < 0 { ring = [ring[0]] + ring.dropFirst().reversed() }
            ring.append(ring[0])
            return ring
        }
    }
}

extension RecognizedShape {
    /// A closed polygon as `count` points that start near the raw stroke's start and wind the same way.
    static func closedRing(_ vertices: [CGPoint], matching raw: [CGPoint], count n: Int) -> [CGPoint] {
        var v = vertices
        if Polyline.signedArea(raw) * Polyline.signedArea(v) < 0 { v.reverse() }
        if let first = raw.first, let k = v.indices.min(by: {
            hypot(v[$0].x - first.x, v[$0].y - first.y) < hypot(v[$1].x - first.x, v[$1].y - first.y)
        }) { v = Array(v[k...] + v[..<k]) }
        v.append(v[0])
        return Polyline.resample(v, count: n)
    }
}

enum Polyline {
    /// Douglas-Peucker: the fewest points that keep the line within `tolerance` of the original.
    static func simplify(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2, let a = points.first, let b = points.last else { return points }
        var worst = 0, worstDistance: CGFloat = 0
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 0.0001)
        for i in 1..<(points.count - 1) {
            let d = abs(dy * (points[i].x - a.x) - dx * (points[i].y - a.y)) / length
            if d > worstDistance { worstDistance = d; worst = i }
        }
        guard worstDistance > tolerance else { return [a, b] }
        let left = simplify(Array(points[...worst]), tolerance: tolerance)
        let right = simplify(Array(points[worst...]), tolerance: tolerance)
        return left + right.dropFirst()
    }

    static func length(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

    /// Shoelace area; positive when the loop runs counter-clockwise (y up).
    static func signedArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 2 else { return 1 }
        var sum: CGFloat = 0
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    /// `count` points evenly spaced by arc length, first and last included.
    static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard let first = points.first, count >= 2 else { return points }
        let total = length(points)
        guard total > 0 else { return Array(repeating: first, count: count) }
        var result: [CGPoint] = [first]
        var segment = 0
        var travelled: CGFloat = 0
        for i in 1..<(count - 1) {
            let target = total * CGFloat(i) / CGFloat(count - 1)
            while segment < points.count - 2,
                  travelled + hypot(points[segment + 1].x - points[segment].x, points[segment + 1].y - points[segment].y) < target {
                travelled += hypot(points[segment + 1].x - points[segment].x, points[segment + 1].y - points[segment].y)
                segment += 1
            }
            let a = points[segment], b = points[segment + 1]
            let len = hypot(b.x - a.x, b.y - a.y)
            let t = len > 0 ? min(max((target - travelled) / len, 0), 1) : 0
            result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        result.append(points[points.count - 1])
        return result
    }
}

/// Turns a hand-drawn stroke into a clean shape. A heuristic, not a classifier: closed loops become an ellipse or a
/// rectangle, a straight stroke becomes a line (an underline when near horizontal), a straight stroke ending in a
/// short back-stroke becomes an arrow. Anything else stays as drawn.
public struct ShapeRecognizer: Equatable, Sendable {
    public init() {}

    private let minimumLength: CGFloat = 50
    private let closedRatio: CGFloat = 0.2
    private let straightRatio: CGFloat = 0.92
    private let horizontalTolerance = 8.0 * Double.pi / 180

    public func recognize(_ raw: [CGPoint]) -> RecognizedShape {
        guard raw.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return .none }
        var points: [CGPoint] = []
        for p in raw where points.last.map({ hypot($0.x - p.x, $0.y - p.y) > 0.01 }) ?? true { points.append(p) }
        guard points.count >= 8 else { return .none }
        let length = Polyline.length(points)
        guard length >= minimumLength, let first = points.first, let last = points.last else { return .none }
        let chord = hypot(last.x - first.x, last.y - first.y)

        if chord <= closedRatio * length { return closedShape(points) }

        if chord / length >= straightRatio, chord >= 60 { return straightShape(from: first, to: last, points: points) }
        return arrow(points, first: first) ?? .none
    }

    private func closedShape(_ points: [CGPoint]) -> RecognizedShape {
        var minX = CGFloat.infinity, minY = CGFloat.infinity, maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let box = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard box.width >= 30, box.height >= 20 else { return .none }
        let cx = box.midX, cy = box.midY, a = box.width / 2, b = box.height / 2

        var bins = Set<Int>()
        var ellipseError: CGFloat = 0
        var rectError: CGFloat = 0
        for p in points {
            let nx = (p.x - cx) / a, ny = (p.y - cy) / b
            ellipseError += abs(sqrt(nx * nx + ny * ny) - 1)
            let edge = min(p.x - box.minX, box.maxX - p.x, p.y - box.minY, box.maxY - p.y)
            rectError += max(edge, 0) / min(box.width, box.height)
            let angle = atan2(ny, nx)
            bins.insert(Int(((angle + .pi) / (2 * .pi) * 12).rounded(.down)) % 12)
        }
        ellipseError /= CGFloat(points.count)
        rectError /= CGFloat(points.count)
        guard bins.count >= 10 else { return .none }
        if rectError <= 0.05, rectError < ellipseError * 0.5 { return .rectangle(box) }
        if let corners = polygonCorners(points, box: box) {
            if corners.count == 3 { return .triangle(corners) }
            if isDiamond(corners, in: box) { return .diamond(box) }
        }
        if ellipseError <= 0.16 { return .ellipse(box) }
        return .none
    }

    /// The corners of a closed stroke when it is a plain polygon with three or four corners, otherwise nil.
    private func polygonCorners(_ points: [CGPoint], box: CGRect) -> [CGPoint]? {
        let tolerance = 0.07 * max(box.width, box.height)
        guard let far = points.indices.max(by: { hypot(points[$0].x - points[0].x, points[$0].y - points[0].y) < hypot(points[$1].x - points[0].x, points[$1].y - points[0].y) }), far > 2, far < points.count - 2 else { return nil }
        let firstHalf = Polyline.simplify(Array(points[0...far]), tolerance: tolerance)
        let secondHalf = Polyline.simplify(Array(points[far...]) + [points[0]], tolerance: tolerance)
        var corners = firstHalf + secondHalf.dropFirst().dropLast()
        // A corner right on the join is the stroke's own start, not a second corner.
        corners = corners.enumerated().filter { index, p in
            let next = corners[(index + 1) % corners.count]
            return hypot(p.x - next.x, p.y - next.y) > tolerance
        }.map(\.element)
        return (3...4).contains(corners.count) ? corners : nil
    }

    private func isDiamond(_ corners: [CGPoint], in box: CGRect) -> Bool {
        guard corners.count == 4 else { return false }
        let mids = [CGPoint(x: box.midX, y: box.minY), CGPoint(x: box.maxX, y: box.midY), CGPoint(x: box.midX, y: box.maxY), CGPoint(x: box.minX, y: box.midY)]
        let slack = 0.22 * max(box.width, box.height)
        return mids.allSatisfy { m in corners.contains { hypot($0.x - m.x, $0.y - m.y) <= slack } }
    }

    private func straightShape(from a: CGPoint, to b: CGPoint, points: [CGPoint]) -> RecognizedShape {
        let angle = atan2(b.y - a.y, b.x - a.x)
        let nearHorizontal = abs(angle) <= horizontalTolerance || abs(abs(angle) - .pi) <= horizontalTolerance
        if nearHorizontal {
            let y = points.reduce(0) { $0 + $1.y } / CGFloat(points.count)
            return .underline(from: CGPoint(x: a.x, y: y), to: CGPoint(x: b.x, y: y))
        }
        return .line(from: a, to: b)
    }

    private func arrow(_ points: [CGPoint], first: CGPoint) -> RecognizedShape? {
        guard let tipIndex = points.indices.max(by: {
            hypot(points[$0].x - first.x, points[$0].y - first.y) < hypot(points[$1].x - first.x, points[$1].y - first.y)
        }), tipIndex < points.count - 1, tipIndex > 2 else { return nil }
        let tip = points[tipIndex]
        let shaft = Array(points[...tipIndex])
        let tail = Array(points[tipIndex...])
        let shaftLength = Polyline.length(shaft)
        let tailLength = Polyline.length(tail)
        let shaftChord = hypot(tip.x - first.x, tip.y - first.y)
        guard shaftChord >= 60, shaftChord / shaftLength >= 0.9,
              tailLength >= 0.08 * shaftLength, tailLength <= 0.6 * shaftLength,
              let end = tail.last else { return nil }
        let back = atan2(first.y - tip.y, first.x - tip.x)
        let wing = atan2(end.y - tip.y, end.x - tip.x)
        var diff = abs(back - wing).truncatingRemainder(dividingBy: 2 * .pi)
        if diff > .pi { diff = 2 * .pi - diff }
        guard diff >= 10 * .pi / 180, diff <= 75 * .pi / 180 else { return nil }
        return .arrow(from: first, to: tip)
    }
}
