import CoreGraphics
import Foundation

public enum CursorKind: String, CaseIterable, Sendable {
    case arrow, hand, ibeam
}

/// One cursor drawing: a canvas in points (art plus room for its shadow and glow), the hotspot measured from
/// the canvas's top-left corner, and a vector drawing routine in that same top-left, y-down point space.
public struct SkinArtwork: Sendable {
    public let canvasSize: CGSize
    public let hotspot: CGPoint
    let draw: @Sendable (CGContext) -> Void

    init(canvasSize: CGSize, hotspot: CGPoint, draw: @escaping @Sendable (CGContext) -> Void) {
        self.canvasSize = canvasSize
        self.hotspot = hotspot
        self.draw = draw
    }
}

/// A cursor skin: an arrow, a hand and an I-beam drawn as vectors, rendered at any scale on demand.
public struct Skin: Identifiable, Sendable {
    public let id: String
    public let name: String
    /// Hotspot per kind, in points from the canvas's top-left corner, at size multiplier 1.
    public let hotspot: [CursorKind: CGPoint]
    private let artworks: [CursorKind: SkinArtwork]

    public init(id: String, name: String, artworks: [CursorKind: SkinArtwork]) {
        self.id = id
        self.name = name
        self.artworks = artworks
        hotspot = artworks.mapValues(\.hotspot)
    }

    public func canvasSize(for kind: CursorKind) -> CGSize {
        artworks[kind]?.canvasSize ?? .zero
    }

    /// Renders the cursor at `scale` pixels per point. The hotspot lands at exactly `hotspot * scale` pixels from
    /// the top-left; extra pixels from rounding up are added on the right and bottom only.
    public func image(for kind: CursorKind, scale: CGFloat) -> CGImage? {
        guard let artwork = artworks[kind], scale > 0 else { return nil }
        let width = Int((artwork.canvasSize.width * scale - 0.001).rounded(.up))
        let height = Int((artwork.canvasSize.height * scale - 0.001).rounded(.up))
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        // Top-left origin, y down, in points.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        artwork.draw(context)
        return context.makeImage()
    }
}
