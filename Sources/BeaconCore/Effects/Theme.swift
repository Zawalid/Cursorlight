import CoreGraphics

/// The look shared by effects. Names are placeholders, like the app name.
public struct Theme: Equatable, Sendable {
    public let id: String
    public let name: String
    /// Ring and glow color.
    public let primary: CGColor
    /// Thin inner rim that keeps the ring readable on any background.
    public let accent: CGColor
    /// Glow strength, 0 (none) to 1 (full neon).
    public let glow: CGFloat
    /// Color of the soft shadow around the ring; the primary color for luminous themes, black for flat ones.
    public let glowColor: CGColor
    public let ringWidth: CGFloat
    /// Opacity of the soft wash inside the ring, 0 to 1.
    public let fillOpacity: CGFloat

    public static let neon = Theme(
        id: "neon", name: "Neon",
        primary: CGColor(srgbRed: 0.24, green: 0.93, blue: 1.0, alpha: 1),
        accent: CGColor(srgbRed: 1.0, green: 0.36, blue: 0.86, alpha: 0.85),
        glow: 1.0,
        glowColor: CGColor(srgbRed: 0.24, green: 0.93, blue: 1.0, alpha: 1),
        ringWidth: 3, fillOpacity: 0.14
    )

    public static let ink = Theme(
        id: "ink", name: "Ink",
        primary: CGColor(srgbRed: 0.11, green: 0.13, blue: 0.27, alpha: 1),
        accent: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9),
        glow: 0.35,
        glowColor: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        ringWidth: 3.5, fillOpacity: 0.08
    )

    public static let spotlight = Theme(
        id: "spotlight", name: "Spotlight",
        primary: CGColor(srgbRed: 1.0, green: 0.92, blue: 0.74, alpha: 1),
        accent: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.7),
        glow: 0.75,
        glowColor: CGColor(srgbRed: 1.0, green: 0.84, blue: 0.55, alpha: 1),
        ringWidth: 2, fillOpacity: 0.22
    )

    public static let minimal = Theme(
        id: "minimal", name: "Minimal",
        primary: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95),
        accent: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.35),
        glow: 0.2,
        glowColor: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        ringWidth: 1.5, fillOpacity: 0
    )

    public static let all: [Theme] = [.neon, .ink, .spotlight, .minimal]

    public static func named(_ id: String) -> Theme? {
        all.first { $0.id == id }
    }
}
