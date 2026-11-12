import CoreGraphics
import Foundation

/// The look of the spotlight region. Part of `HighlightOptions`, so it travels with scenes.
public enum SpotlightShape: String, CaseIterable, Codable, Sendable {
    case rectangle, rounded, ellipse

    public var displayName: String {
        switch self {
        case .rectangle: "Rectangle"
        case .rounded: "Rounded"
        case .ellipse: "Ellipse"
        }
    }
}

public struct SpotlightStyle: Equatable, Sendable {
    public var shape: SpotlightShape
    /// How dark everything outside the region goes, 0...1.
    public var dim: Double
    /// Width of the soft edge outside the region, in points. 0 is a sharp edge.
    public var softness: Double
    /// Corner radius for the rounded shape, in points.
    public var corner: Double

    public init(shape: SpotlightShape = .rounded, dim: Double = 0.6, softness: Double = 0, corner: Double = 14) {
        self.shape = shape
        self.dim = dim
        self.softness = softness
        self.corner = corner
    }
}

/// The region you spotlight, and how a drag edits it: draw a new one, move it, or pull a handle. Pure value in global
/// screen coordinates (y up); the controller feeds it the pointer.
public struct SpotlightModel: Equatable, Sendable {
    public enum Handle: CaseIterable, Sendable {
        case topLeft, topRight, bottomRight, bottomLeft, top, right, bottom, left

        /// Where this handle sits on `rect`.
        public func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: CGPoint(x: rect.minX, y: rect.maxY)
            case .topRight: CGPoint(x: rect.maxX, y: rect.maxY)
            case .bottomRight: CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeft: CGPoint(x: rect.minX, y: rect.minY)
            case .top: CGPoint(x: rect.midX, y: rect.maxY)
            case .right: CGPoint(x: rect.maxX, y: rect.midY)
            case .bottom: CGPoint(x: rect.midX, y: rect.minY)
            case .left: CGPoint(x: rect.minX, y: rect.midY)
            }
        }

        var movesLeft: Bool { self == .topLeft || self == .bottomLeft || self == .left }
        var movesRight: Bool { self == .topRight || self == .bottomRight || self == .right }
        var movesTop: Bool { self == .topLeft || self == .topRight || self == .top }
        var movesBottom: Bool { self == .bottomLeft || self == .bottomRight || self == .bottom }
    }

    private enum Grab: Equatable, Sendable {
        case none
        case drawing(anchor: CGPoint, previous: CGRect?)
        case moving(last: CGPoint)
        case resizing(Handle)
    }

    public static let minSize: CGFloat = 40
    public static let handleSlop: CGFloat = 14

    public private(set) var region: CGRect?
    private var grab: Grab = .none

    public init(region: CGRect? = nil) { self.region = region }

    public var isDragging: Bool { grab != .none }

    /// The handle under `point`, corners before edges.
    public func handle(at point: CGPoint) -> Handle? {
        guard let region else { return nil }
        return Handle.allCases.first { hypot($0.point(in: region).x - point.x, $0.point(in: region).y - point.y) <= Self.handleSlop }
    }

    public mutating func pointerDown(_ p: CGPoint) {
        if let region {
            if let handle = handle(at: p) { grab = .resizing(handle); return }
            if region.contains(p) { grab = .moving(last: p); return }
        }
        grab = .drawing(anchor: p, previous: region)
    }

    public mutating func pointerDragged(_ p: CGPoint) {
        switch grab {
        case .none:
            break
        case let .drawing(anchor, _):
            region = CGRect(x: min(anchor.x, p.x), y: min(anchor.y, p.y), width: abs(p.x - anchor.x), height: abs(p.y - anchor.y))
        case let .moving(last):
            region = region?.offsetBy(dx: p.x - last.x, dy: p.y - last.y)
            grab = .moving(last: p)
        case let .resizing(handle):
            guard let r = region else { return }
            var left = r.minX, right = r.maxX, bottom = r.minY, top = r.maxY
            if handle.movesLeft { left = min(p.x, right - Self.minSize) }
            if handle.movesRight { right = max(p.x, left + Self.minSize) }
            if handle.movesBottom { bottom = min(p.y, top - Self.minSize) }
            if handle.movesTop { top = max(p.y, bottom + Self.minSize) }
            region = CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
        }
    }

    /// Ends the drag. A new region that came out too small is dropped and the old one comes back.
    public mutating func pointerUp(_ p: CGPoint) {
        pointerDragged(p)
        if case let .drawing(_, previous) = grab, let r = region, r.width < Self.minSize || r.height < Self.minSize {
            region = previous
        }
        grab = .none
    }

    public mutating func setRegion(_ rect: CGRect?) {
        region = rect
        grab = .none
    }

    public mutating func clear() { setRegion(nil) }
}
