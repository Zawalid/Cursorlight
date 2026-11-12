import BeaconCore
import SwiftUI

/// Colors, type and metrics for every screen. The accent comes from Branding; everything else is neutral.
enum Theme {
    // Light, quiet and warm. The window is the system material with a faint wash; surfaces are near-white cards with a
    // hairline edge and no shadow; text is warm ink; Ember appears only on what is selected or on. The Stage is dark
    // because it is a screen.
    static let window = Color.clear
    static let sidebar = Color.clear
    static let card = Color.white.opacity(0.80)
    static let raised = Color.white.opacity(0.92)
    static let cardHover = Color.white.opacity(0.96)
    static let stage = Color(red: 0.059, green: 0.063, blue: 0.078)
    static let well = Color.black.opacity(0.05)
    static let line = Color.black.opacity(0.07)
    static let fillSoft = Color.black.opacity(0.05)
    static let fillMid = Color.black.opacity(0.12)
    static let text = Color(red: 0.110, green: 0.106, blue: 0.098)
    static let dim = Color(red: 0.373, green: 0.357, blue: 0.333)
    static let faint = Color(red: 0.557, green: 0.541, blue: 0.514)
    static let accent = Color(rgba: RGBA(hex: Branding.accentHex))
    static let ok = Color(red: 0.11, green: 0.56, blue: 0.27)
    static let warn = Color(red: 0.74, green: 0.42, blue: 0.03)
    static let radius: CGFloat = 16

    static func title(_ text: String) -> some View {
        Text(text).font(.system(size: 20, weight: .semibold)).foregroundStyle(text == "" ? dim : Theme.text)
    }
}

extension Color {
    init(rgba: RGBA) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
