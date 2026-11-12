import CoreGraphics
import Foundation

/// How a stroke is drawn. Raw values are persisted.
public enum InkStyle: String, CaseIterable, Codable, Sendable {
    case marker, highlighter, neon

    public var displayName: String {
        switch self {
        case .marker: "Marker"
        case .highlighter: "Highlighter"
        case .neon: "Neon"
        }
    }

    /// Core line width in points.
    public var width: CGFloat {
        switch self {
        case .marker: 5
        case .highlighter: 22
        case .neon: 4
        }
    }

    /// Opacity of the core line.
    public var alpha: CGFloat {
        switch self {
        case .marker: 1
        case .highlighter: 0.38
        case .neon: 1
        }
    }

    /// Width and opacity of the soft glow drawn under the core; nil for no glow.
    public var glow: (width: CGFloat, alpha: CGFloat)? {
        switch self {
        case .neon: (16, 0.45)
        case .marker, .highlighter: nil
        }
    }

    /// Neon draws a near-white core inside its colored glow.
    public var lightCore: Bool { self == .neon }
}

/// The pen colors. Raw values are persisted.
public enum InkColor: String, CaseIterable, Codable, Sendable {
    case red, yellow, blue, green, white

    public var displayName: String { rawValue.capitalized }

    public var rgba: RGBA {
        switch self {
        case .red: RGBA(hex: "#FF3B30")
        case .yellow: RGBA(hex: "#FFD60A")
        case .blue: RGBA(hex: "#4DA3FF")
        case .green: RGBA(hex: "#34C759")
        case .white: RGBA(hex: "#F5F5F7")
        }
    }
}
