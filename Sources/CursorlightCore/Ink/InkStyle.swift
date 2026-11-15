import CoreGraphics
import Foundation

/// How a stroke is drawn. Raw values are persisted.
public enum InkStyle: String, CaseIterable, Codable, Sendable {
    case marker, highlighter, neon, pencil, dashed

    public var displayName: String {
        switch self {
        case .marker: "Marker"
        case .highlighter: "Highlighter"
        case .neon: "Neon"
        case .pencil: "Pencil"
        case .dashed: "Dashed"
        }
    }

    /// Core line width in points.
    public var width: CGFloat {
        switch self {
        case .marker: 5
        case .highlighter: 22
        case .neon: 4
        case .pencil: 2.5
        case .dashed: 5
        }
    }

    /// Opacity of the core line.
    public var alpha: CGFloat {
        switch self {
        case .marker: 1
        case .highlighter: 0.38
        case .neon, .dashed: 1
        case .pencil: 0.92
        }
    }

    /// Width and opacity of the soft glow drawn under the core; nil for no glow.
    public var glow: (width: CGFloat, alpha: CGFloat)? {
        switch self {
        case .neon: (16, 0.45)
        case .marker, .highlighter, .pencil, .dashed: nil
        }
    }

    /// Dash and gap lengths for the core line, in units of the line width; nil for a solid line.
    public var dash: [CGFloat]? { self == .dashed ? [1.2, 2.6] : nil }

    /// Styles drawn without the thin dark outline that keeps a stroke readable on light backgrounds.
    public var hasKeyline: Bool { self != .highlighter && self != .dashed }

    /// Neon draws a near-white core inside its colored glow.
    public var lightCore: Bool { self == .neon }
}

/// The pen colors. Raw values are persisted.
public enum InkColor: String, CaseIterable, Codable, Sendable {
    case red, orange, yellow, green, blue, purple, pink, white

    public var displayName: String { rawValue.capitalized }

    public var rgba: RGBA {
        switch self {
        case .red: RGBA(hex: "#FF3B30")
        case .orange: RGBA(hex: "#FF9F0A")
        case .yellow: RGBA(hex: "#FFD60A")
        case .green: RGBA(hex: "#34C759")
        case .blue: RGBA(hex: "#4DA3FF")
        case .purple: RGBA(hex: "#AF7CFF")
        case .pink: RGBA(hex: "#FF6EB4")
        case .white: RGBA(hex: "#F5F5F7")
        }
    }
}
