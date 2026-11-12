import BeaconCore
import SwiftUI

/// Colors, type and metrics for every screen. The accent comes from Branding; everything else is neutral.
enum Theme {
    static let window = Color(red: 0.090, green: 0.090, blue: 0.106)
    static let sidebar = Color(red: 0.071, green: 0.071, blue: 0.082)
    static let card = Color(red: 0.118, green: 0.118, blue: 0.137)
    static let cardHover = Color(red: 0.145, green: 0.145, blue: 0.169)
    static let well = Color(red: 0.063, green: 0.063, blue: 0.075)
    static let line = Color.white.opacity(0.08)
    static let text = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let dim = Color(red: 0.60, green: 0.60, blue: 0.65)
    static let faint = Color(red: 0.38, green: 0.38, blue: 0.42)
    static let accent = Color(rgba: RGBA(hex: Branding.accentHex))
    static let ok = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let warn = Color(red: 0.95, green: 0.70, blue: 0.30)
    static let radius: CGFloat = 14

    static func title(_ text: String) -> some View {
        Text(text).font(.system(size: 20, weight: .semibold)).foregroundStyle(text == "" ? dim : Theme.text)
    }
}

extension Color {
    init(rgba: RGBA) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
