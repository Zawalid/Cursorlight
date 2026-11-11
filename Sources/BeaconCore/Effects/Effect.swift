import CoreGraphics
import Foundation

public enum EffectID: String, CaseIterable, Hashable, Sendable {
    case beacon, laser, ink, pulse
}

/// One effect drawn on one overlay window. The engine creates one instance per display and routes the pointer to
/// them: the instance on the display that has the pointer gets its position in layer coordinates, every other
/// instance gets nil and must hide.
@MainActor
public protocol Effect: AnyObject {
    var id: EffectID { get }
    /// Set by the engine. An effect that ends on its own (a laser stroke that faded) calls it once it is done.
    var onFinish: (() -> Void)? { get set }
    func activate(on window: OverlayWindow, tracker: CursorTracker)
    func deactivate()
    /// The selected highlight style; effects take their accent from `Palette.accent(for:)`.
    func apply(style: HighlightStyle)
    /// - Parameter layerPoint: pointer position in the window's root layer coordinates, or nil when the pointer is
    ///   on another display.
    func pointerMoved(to layerPoint: CGPoint?, at time: TimeInterval)
}

/// Pure coordinate helpers shared by the engine and effects.
public enum PointerGeometry {
    /// The display that owns a point in global screen coordinates (`NSEvent.mouseLocation`).
    ///
    /// Half-open containment first, so a point on an edge shared by two displays belongs to exactly one of them.
    /// Then closed containment, because the top row of the topmost display reports y == maxY. Then the nearest
    /// display, so a point that slipped outside every frame still has a home. Ties go to the lowest display ID.
    public static func owner(of point: CGPoint, in frames: [CGDirectDisplayID: CGRect]) -> CGDirectDisplayID? {
        let sorted = frames.sorted { $0.key < $1.key }
        if let hit = sorted.first(where: { halfOpenContains($0.value, point) }) { return hit.key }
        if let hit = sorted.first(where: { closedContains($0.value, point) }) { return hit.key }
        return sorted.min { distance(from: point, to: $0.value) < distance(from: point, to: $1.value) }?.key
    }

    /// Converts a global screen point to the coordinates of an overlay window's root layer. The host view is not
    /// flipped and the window covers its display exactly, so this is a plain translation in points; Core Animation
    /// applies the backing scale (1x or 2x) itself.
    public static func layerPoint(for screenPoint: CGPoint, windowFrame: CGRect) -> CGPoint {
        CGPoint(x: screenPoint.x - windowFrame.minX, y: screenPoint.y - windowFrame.minY)
    }

    /// Rounds a point to the nearest device pixel for a backing scale.
    public static func pixelAligned(_ point: CGPoint, scale: CGFloat) -> CGPoint {
        let s = max(scale, 1)
        return CGPoint(x: (point.x * s).rounded() / s, y: (point.y * s).rounded() / s)
    }

    private static func halfOpenContains(_ rect: CGRect, _ p: CGPoint) -> Bool {
        p.x >= rect.minX && p.x < rect.maxX && p.y >= rect.minY && p.y < rect.maxY
    }

    private static func closedContains(_ rect: CGRect, _ p: CGPoint) -> Bool {
        p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
    }

    private static func distance(from p: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - p.x, 0, p.x - rect.maxX)
        let dy = max(rect.minY - p.y, 0, p.y - rect.maxY)
        return hypot(dx, dy)
    }
}
