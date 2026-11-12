import CoreGraphics
import Foundation

/// One stroke ready to draw.
public struct InkStrokeFrame: Equatable, Sendable {
    public var id: Int
    public var points: [CGPoint]
    public var style: InkStyle
    public var color: InkColor
    public var alpha: CGFloat
}

public struct InkFrame: Equatable, Sendable {
    public var strokes: [InkStrokeFrame]
}

/// Strokes drawn with the pointer. A stroke is raw while it is drawn; when it ends it is recognized, and a
/// recognized shape morphs out of the raw stroke. Strokes fade on their own a moment after they end. Pure value:
/// time is passed in, nothing reads a clock.
public struct InkModel: Equatable, Sendable {
    struct Stroke: Equatable, Sendable {
        var id: Int
        var points: [CGPoint]
        var style: InkStyle
        var color: InkColor
        var endTime: TimeInterval?
        /// Raw stroke resampled to the morph point count, and the target shape resampled the same way.
        var morphFrom: [CGPoint]?
        var morphTo: [CGPoint]?
        var clearedAt: TimeInterval?
    }

    public static let morphPointCount = 64
    static let maxPointsPerStroke = 4000
    static let minPointSpacing: CGFloat = 1.5
    static let clearDuration: TimeInterval = 0.2

    public var fadeAfter: TimeInterval
    public var fadeDuration: TimeInterval
    public var morphDuration: TimeInterval
    public var cleanupEnabled: Bool
    private let recognizer = ShapeRecognizer()
    private(set) var strokes: [Stroke] = []
    private var nextID = 0

    public init(fadeAfter: TimeInterval = 2.0, fadeDuration: TimeInterval = 0.6, morphDuration: TimeInterval = 0.28, cleanupEnabled: Bool = true) {
        self.fadeAfter = fadeAfter
        self.fadeDuration = fadeDuration
        self.morphDuration = morphDuration
        self.cleanupEnabled = cleanupEnabled
    }

    public var isDrawing: Bool { strokes.last.map { $0.endTime == nil } ?? false }
    public var strokeCount: Int { strokes.count }
    /// True while anything is on screen, so the controller keeps its display link running.
    public var needsFrames: Bool { !strokes.isEmpty }

    // MARK: Input

    public mutating func begin(at point: CGPoint, style: InkStyle, color: InkColor) {
        if isDrawing { end(at: 0) }
        guard point.x.isFinite, point.y.isFinite else { return }
        strokes.append(Stroke(id: nextID, points: [point], style: style, color: color))
        nextID += 1
    }

    public mutating func append(_ point: CGPoint) {
        guard isDrawing, point.x.isFinite, point.y.isFinite, let index = strokes.indices.last else { return }
        guard let last = strokes[index].points.last,
              hypot(point.x - last.x, point.y - last.y) >= Self.minPointSpacing,
              strokes[index].points.count < Self.maxPointsPerStroke else { return }
        strokes[index].points.append(point)
    }

    public mutating func end(at time: TimeInterval) {
        guard isDrawing, let index = strokes.indices.last else { return }
        strokes[index].endTime = time
        guard cleanupEnabled else { return }
        let raw = strokes[index].points
        let shape = recognizer.recognize(raw)
        let count = Self.morphPointCount
        if let target = shape.polyline(count: count, matching: raw) {
            strokes[index].morphFrom = Polyline.resample(raw, count: count)
            strokes[index].morphTo = target
        }
    }

    /// Removes the newest stroke at once.
    public mutating func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
    }

    /// Fades everything out quickly.
    public mutating func clear(at time: TimeInterval) {
        if isDrawing { end(at: time) }
        for index in strokes.indices where strokes[index].clearedAt == nil { strokes[index].clearedAt = time }
    }

    // MARK: Frames

    public mutating func step(time: TimeInterval) -> InkFrame {
        let alive = strokes.filter { alpha(of: $0, at: time) > 0 }
        strokes = alive
        return InkFrame(strokes: strokes.map { stroke in
            InkStrokeFrame(
                id: stroke.id, points: points(of: stroke, at: time), style: stroke.style, color: stroke.color,
                alpha: alpha(of: stroke, at: time)
            )
        })
    }

    private func alpha(of stroke: Stroke, at time: TimeInterval) -> CGFloat {
        var result: CGFloat = 1
        if let end = stroke.endTime {
            let fadeStart = end + fadeAfter
            if time >= fadeStart { result = CGFloat(max(0, 1 - (time - fadeStart) / fadeDuration)) }
        }
        if let cleared = stroke.clearedAt {
            result = min(result, CGFloat(max(0, 1 - (time - cleared) / Self.clearDuration)))
        }
        return result
    }

    private func points(of stroke: Stroke, at time: TimeInterval) -> [CGPoint] {
        guard let end = stroke.endTime, let from = stroke.morphFrom, let to = stroke.morphTo else { return stroke.points }
        let p = min(max((time - end) / morphDuration, 0), 1)
        let eased = 1 - pow(1 - p, 3)
        guard eased < 1 else { return to }
        return zip(from, to).map { a, b in
            CGPoint(x: a.x + (b.x - a.x) * eased, y: a.y + (b.y - a.y) * eased)
        }
    }
}
