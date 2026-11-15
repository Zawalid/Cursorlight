import CoreGraphics

extension PointerGeometry {
    /// Rounds a length in points to the device pixel grid of a backing scale (half points on Retina).
    public static func snapped(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        let s = max(scale, 1)
        return (value * s).rounded() / s
    }

    /// Concentric bands of a static ring stack, from the inside out, with every band edge on a device pixel so each
    /// stroke is crisp. `edges` are radii in points, increasing; the result has one (radius, width) per band, where
    /// radius is the band's middle (what a centered stroke needs). Assumes the ring's center is pixel aligned.
    public static func ringBands(edges: [CGFloat], scale: CGFloat) -> [(radius: CGFloat, width: CGFloat)] {
        let snappedEdges = edges.map { snapped($0, scale: scale) }
        guard snappedEdges.count > 1 else { return [] }
        let pixel = 1 / max(scale, 1)
        var result: [(radius: CGFloat, width: CGFloat)] = []
        var inner = snappedEdges[0]
        for outerRaw in snappedEdges.dropFirst() {
            // A band never collapses below one device pixel.
            let outer = max(outerRaw, inner + pixel)
            result.append(((inner + outer) / 2, outer - inner))
            inner = outer
        }
        return result
    }
}
