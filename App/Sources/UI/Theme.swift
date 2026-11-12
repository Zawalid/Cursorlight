import BeaconCore
import SwiftUI

/// Colors, type and metrics for every screen. The accent comes from Branding; everything else is neutral.
enum Theme {
    // Light glass: the window is a translucent material, surfaces are white at partial strength, text is warm ink, and
    // the one accent is Ember. The Stage stays dark because it is a screen.
    static let window = Color.clear
    static let sidebar = Color.clear
    static let card = Color.white.opacity(0.52)
    static let raised = Color.white.opacity(0.72)
    static let cardHover = Color.white.opacity(0.88)
    static let stage = Color(red: 0.078, green: 0.078, blue: 0.090)
    static let well = Color.black.opacity(0.05)
    static let line = Color.black.opacity(0.08)
    static let fillSoft = Color.black.opacity(0.06)
    static let fillMid = Color.black.opacity(0.12)
    static let text = Color(red: 0.110, green: 0.102, blue: 0.094)
    static let dim = Color(red: 0.388, green: 0.373, blue: 0.349)
    static let faint = Color(red: 0.569, green: 0.553, blue: 0.529)
    static let accent = Color(rgba: RGBA(hex: Branding.accentHex))
    static let ok = Color(red: 0.11, green: 0.56, blue: 0.27)
    static let warn = Color(red: 0.78, green: 0.46, blue: 0.04)
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
