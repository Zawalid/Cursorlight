import CoreGraphics
import Foundation

/// An sRGB color as plain numbers, so palette math is testable without Core Graphics objects.
public struct RGBA: Equatable, Hashable, Sendable {
    public var red: Double, green: Double, blue: Double, alpha: Double

    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// `hex` like "#FF5A36"; invalid input gives opaque black.
    public init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = digits.count == 6 ? UInt32(digits, radix: 16) ?? 0 : 0
        self.init(
            Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255
        )
    }

    public var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    public func with(alpha: Double) -> RGBA { RGBA(red, green, blue, alpha) }

    /// Linear interpolation toward another color (alpha included).
    public func mixed(with other: RGBA, _ amount: Double) -> RGBA {
        let t = min(max(amount, 0), 1)
        return RGBA(
            red + (other.red - red) * t, green + (other.green - green) * t,
            blue + (other.blue - blue) * t, alpha + (other.alpha - alpha) * t
        )
    }

    /// Rotates the hue in HSV space, keeping saturation, value and alpha.
    public func hueRotated(by degrees: Double) -> RGBA {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC
        guard delta > 1e-9 else { return self }
        var hue: Double
        if maxC == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == green {
            hue = (blue - red) / delta + 2
        } else {
            hue = (red - green) / delta + 4
        }
        hue = (hue * 60 + degrees).truncatingRemainder(dividingBy: 360)
        if hue < 0 { hue += 360 }
        let saturation = delta / maxC
        let c = maxC * saturation
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = maxC - c
        let (r, g, b): (Double, Double, Double)
        switch hue {
        case ..<60: (r, g, b) = (c, x, 0)
        case ..<120: (r, g, b) = (x, c, 0)
        case ..<180: (r, g, b) = (0, c, x)
        case ..<240: (r, g, b) = (0, x, c)
        case ..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return RGBA(r + m, g + m, b + m, alpha)
    }

    /// WCAG relative luminance (alpha ignored).
    public var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio between two opaque colors.
    public func contrast(with other: RGBA) -> Double {
        let a = luminance + 0.05
        let b = other.luminance + 0.05
        return max(a, b) / min(a, b)
    }
}

/// Every highlight color, in one place. Each style pairs a mid-luminance accent (reads on white and on black)
/// with a near-white light element and a black keyline, so contrast comes from luminance, not hue.
public enum Palette {
    /// Near-white used for light cores, light rings and comet cores.
    public static let light = RGBA(0.99, 0.98, 0.96)
    /// Base of every dark keyline; alpha is set by the recipe.
    public static let keyline = RGBA(0.04, 0.04, 0.07)
    /// Right-click ripples rotate the accent hue by this many degrees and draw a double ring.
    public static let rightClickHueShift: Double = 40

    /// Default accent per style. Our own palette, not borrowed from any app.
    public static func accent(for style: HighlightStyle) -> RGBA {
        switch style {
        case .aura: RGBA(hex: "#8B7CFF")  // soft iris
        case .lens: RGBA(hex: "#E8932A")  // warm amber
        case .comet: RGBA(hex: Branding.accentHex)  // ember coral, the brand accent
        case .keyline: RGBA(hex: "#4DA3FF")  // clear blue
        case .sonar: RGBA(hex: "#14B8A6")  // deep teal
        }
    }

    /// Accent for a click ripple of the given button.
    public static func rippleAccent(for style: HighlightStyle, button: MouseButton) -> RGBA {
        rippleAccent(base: accent(for: style), button: button)
    }

    /// Same, from an already chosen accent.
    public static func rippleAccent(base: RGBA, button: MouseButton) -> RGBA {
        button == .right ? base.hueRotated(by: rightClickHueShift) : base
    }
}

public enum MouseButton: Equatable, Sendable {
    case left, right
}
