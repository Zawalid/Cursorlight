import CoreGraphics
import Foundation

/// One stroke ready to draw.
public struct InkStrokeFrame: Equatable, Sendable {
    public var id: Int
    public var points: [CGPoint]
    public var style: InkStyle
    public var color: InkColor
    public var alpha: CGFloat
    /// Multiplies the pen width of the style.
    public var widthScale: CGFloat = 1
    /// A custom color; nil uses `color`.
    public var customColor: RGBA? = nil
    public var kind: InkMarkKind = .freehand

    public var rgba: RGBA { customColor ?? color.rgba }
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
        var widthScale: CGFloat = 1
        var customColor: RGBA?
        var kind: InkMarkKind = .freehand
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
    /// Which shapes a stroke may snap to when cleanup is on.
    public var enabledShapes: InkShapeSet = .all
    /// Off keeps strokes on screen until they are cleared.
    public var fades = true
    private let recognizer = ShapeRecognizer()
    private(set) var strokes: [Stroke] = []
    private var nextID = 0
    private var stampCounter = 0

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

    public mutating func begin(at point: CGPoint, style: InkStyle, color: InkColor, widthScale: CGFloat = 1, customColor: RGBA? = nil, kind: InkMarkKind = .freehand) {
        if isDrawing { end(at: 0) }
        guard point.x.isFinite, point.y.isFinite else { return }
        strokes.append(Stroke(id: nextID, points: kind.isDragShape ? [point, point] : [point], style: style, color: color, widthScale: widthScale, customColor: customColor, kind: kind))
        nextID += 1
    }

    public mutating func append(_ point: CGPoint) {
        guard isDrawing, point.x.isFinite, point.y.isFinite, let index = strokes.indices.last else { return }
        if strokes[index].kind.isDragShape {
            strokes[index].points = [strokes[index].points[0], point]
            return
        }
        guard let last = strokes[index].points.last,
              hypot(point.x - last.x, point.y - last.y) >= Self.minPointSpacing,
              strokes[index].points.count < Self.maxPointsPerStroke else { return }
        strokes[index].points.append(point)
    }

    public mutating func end(at time: TimeInterval) {
        guard isDrawing, let index = strokes.indices.last else { return }
        strokes[index].endTime = time
        if strokes[index].kind.isDragShape {
            // A click with no drag is not a shape.
            let p = strokes[index].points
            if hypot(p[1].x - p[0].x, p[1].y - p[0].y) < 8 { strokes.remove(at: index) }
            return
        }
        guard cleanupEnabled, strokes[index].kind == .freehand else { return }
        let raw = strokes[index].points
        let shape = recognizer.recognize(raw)
        guard let kind = shape.kind, enabledShapes.contains(kind) else { return }
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
        stampCounter = strokes.compactMap { stroke -> Int? in
            if case let .stamp(.number, n) = stroke.kind { return n }
            return nil
        }.max() ?? 0
    }

    /// Makes the pen stroke being drawn a straight line from where it started.
    public mutating func straighten(to point: CGPoint) {
        guard isDrawing, point.x.isFinite, point.y.isFinite, let index = strokes.indices.last,
              strokes[index].kind == .freehand, let first = strokes[index].points.first else { return }
        strokes[index].points = [first, point]
    }

    /// Places a stamp. The number stamp takes the next number.
    public mutating func placeStamp(
        _ stamp: StampKind, at point: CGPoint, color: InkColor, customColor: RGBA?, time: TimeInterval
    ) {
        guard point.x.isFinite, point.y.isFinite else { return }
        var number = 0
        if stamp == .number {
            stampCounter += 1
            number = stampCounter
        }
        strokes.append(Stroke(id: nextID, points: [point], style: .marker, color: color, customColor: customColor, kind: .stamp(stamp, number), endTime: time))
        nextID += 1
    }

    public mutating func placeText(_ text: String, at point: CGPoint, color: InkColor, customColor: RGBA?, time: TimeInterval) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, point.x.isFinite, point.y.isFinite else { return }
        strokes.append(Stroke(id: nextID, points: [point], style: .marker, color: color, customColor: customColor, kind: .text(String(trimmed.prefix(80))), endTime: time))
        nextID += 1
    }

    /// Removes every mark touched by a circle at `point`. The mark being drawn is left alone. Returns whether any went.
    @discardableResult
    public mutating func erase(at point: CGPoint, radius: CGFloat) -> Bool {
        let drawingID = isDrawing ? strokes.last?.id : nil
        let before = strokes.count
        strokes.removeAll { $0.id != drawingID && $0.isHit(by: point, radius: radius) }
        return strokes.count != before
    }

    /// Fades everything out quickly.
    public mutating func clear(at time: TimeInterval) {
        if isDrawing { end(at: time) }
        stampCounter = 0
        for index in strokes.indices where strokes[index].clearedAt == nil { strokes[index].clearedAt = time }
    }

    // MARK: Frames

    public mutating func step(time: TimeInterval) -> InkFrame {
        let alive = strokes.filter { alpha(of: $0, at: time) > 0 }
        strokes = alive
        return InkFrame(strokes: strokes.map { stroke in
            InkStrokeFrame(
                id: stroke.id, points: points(of: stroke, at: time), style: stroke.style, color: stroke.color,
                alpha: alpha(of: stroke, at: time), widthScale: stroke.widthScale, customColor: stroke.customColor, kind: stroke.kind
            )
        })
    }

    private func alpha(of stroke: Stroke, at time: TimeInterval) -> CGFloat {
        var result: CGFloat = 1
        if fades, stroke.kind != .redact, let end = stroke.endTime {
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

extension InkModel.Stroke {
    /// Whether an eraser circle at `point` touches this mark.
    func isHit(by point: CGPoint, radius: CGFloat) -> Bool {
        switch kind {
        case .freehand, .arrow, .doubleArrow, .bracket:
            guard points.count > 1 else { return points.first.map { hypot($0.x - point.x, $0.y - point.y) <= radius } ?? false }
            for i in 1..<points.count where Self.distance(from: point, toSegment: points[i - 1], points[i]) <= radius { return true }
            return false
        case .filledBox, .redact:
            guard points.count == 2 else { return false }
            let rect = CGRect(x: min(points[0].x, points[1].x), y: min(points[0].y, points[1].y), width: abs(points[1].x - points[0].x), height: abs(points[1].y - points[0].y))
            return rect.insetBy(dx: -radius, dy: -radius).contains(point)
        case .stamp:
            return points.first.map { hypot($0.x - point.x, $0.y - point.y) <= radius + 20 } ?? false
        case let .text(text):
            guard let origin = points.first else { return false }
            let box = CGRect(x: origin.x, y: origin.y - 6, width: CGFloat(text.count) * 13 + 8, height: 34)
            return box.insetBy(dx: -radius, dy: -radius).contains(point)
        }
    }

    private static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared, 0), 1)
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}
