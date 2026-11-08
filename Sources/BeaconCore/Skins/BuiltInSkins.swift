import CoreGraphics

/// Display names of the built-in skins. Placeholders, kept in this one place.
public enum SkinNames {
    public static let glass = "Glass"
    public static let neon = "Neon"
    public static let ink = "Ink"
    public static let pixel = "Pixel"
    public static let soft = "Soft"
    public static let signal = "Signal"
}

public enum BuiltInSkins {
    public static let all: [Skin] = [glass, neon, ink, pixel, soft, signal]

    public static func skin(id: String) -> Skin? {
        all.first { $0.id == id }
    }

    /// Frosted white with a cool tint, a crisp graphite edge and a light inner rim.
    static let glass = vectorSkin(id: "glass", name: SkinNames.glass, style: VectorStyle(
        fill: .vertical(top: RGBA(1, 1, 1), bottom: RGBA(0.85, 0.89, 0.97)),
        stroke: RGBA(0.07, 0.08, 0.11, 0.92),
        strokeWidth: 1.15,
        detail: RGBA(0.07, 0.08, 0.11, 0.35),
        rim: RGBA(1, 1, 1, 0.9)
    ))

    /// Near-black body, electric cyan edge with a glow, magenta details.
    static let neon = vectorSkin(id: "neon", name: SkinNames.neon, style: VectorStyle(
        fill: .vertical(top: RGBA(0.07, 0.08, 0.16), bottom: RGBA(0.02, 0.02, 0.06)),
        stroke: RGBA(0.30, 0.96, 1.0),
        strokeWidth: 1.4,
        detail: RGBA(1.0, 0.32, 0.82, 0.95),
        glow: SkinGlow(color: RGBA(0.15, 0.85, 1.0, 0.9), radius: 5),
        shadow: SkinShadow(ambientAlpha: 0.42)
    ))

    /// Solid ink with a bold white edge: the classic look, heavier, for small video thumbnails.
    static let ink = vectorSkin(id: "ink", name: SkinNames.ink, style: VectorStyle(
        fill: .solid(RGBA(0.06, 0.06, 0.07)),
        stroke: .white,
        strokeWidth: 1.6,
        detail: RGBA(1, 1, 1, 0.55)
    ))

    /// Hand-placed pixel art on a 1.5 pt grid, shaded bottom-right.
    static let pixel = Skin(
        id: "pixel",
        name: SkinNames.pixel,
        artworks: artworks { kind in
            SkinPainter.pixel(kind, style: PixelStyle(
                fill: RGBA(0.99, 0.97, 0.92),
                shade: RGBA(0.80, 0.78, 0.87),
                outline: RGBA(0.08, 0.08, 0.11)
            ))
        }
    )

    /// Coral to rose gradient, thick white edge, a warm tinted shadow.
    static let soft = vectorSkin(id: "soft", name: SkinNames.soft, style: VectorStyle(
        fill: .vertical(top: RGBA(1.0, 0.62, 0.52), bottom: RGBA(0.98, 0.38, 0.55)),
        stroke: .white,
        strokeWidth: 1.9,
        detail: RGBA(1, 1, 1, 0.75),
        shadow: SkinShadow(tint: RGBA(0.45, 0.05, 0.18), ambientAlpha: 0.36)
    ))

    /// High-visibility yellow with a near-black edge, for presenting.
    static let signal = vectorSkin(id: "signal", name: SkinNames.signal, style: VectorStyle(
        fill: .vertical(top: RGBA(1.0, 0.90, 0.18), bottom: RGBA(1.0, 0.72, 0.0)),
        stroke: RGBA(0.08, 0.06, 0.02),
        strokeWidth: 1.35,
        detail: RGBA(0.08, 0.06, 0.02, 0.5)
    ))

    private static func vectorSkin(id: String, name: String, style: VectorStyle) -> Skin {
        Skin(id: id, name: name, artworks: artworks { SkinPainter.vector($0, style: style) })
    }

    private static func artworks(_ make: (CursorKind) -> SkinArtwork) -> [CursorKind: SkinArtwork] {
        Dictionary(uniqueKeysWithValues: CursorKind.allCases.map { ($0, make($0)) })
    }
}
