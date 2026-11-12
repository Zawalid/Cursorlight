import BeaconCore
import SwiftUI

/// Colors, type and metrics for every screen. The accent comes from Branding; everything else is neutral.
enum Theme {
    // Solid warm dark. No glass, no gradients. Surfaces are told apart by tone and hairlines, not by boxes and shadows.
    // Ember is the only saturated color and appears only on what is selected or on.
    static let window = Color(red: 0.078, green: 0.075, blue: 0.082)       // #141315
    static let sidebar = Color(red: 0.059, green: 0.055, blue: 0.063)      // #0F0E10
    static let card = Color(red: 0.110, green: 0.106, blue: 0.118)         // #1C1B1E
    static let raised = Color(red: 0.141, green: 0.137, blue: 0.153)       // #242327
    static let cardHover = Color(red: 0.173, green: 0.169, blue: 0.188)
    static let stage = Color(red: 0.043, green: 0.043, blue: 0.051)        // #0B0B0D
    static let well = Color.white.opacity(0.05)
    static let line = Color.white.opacity(0.08)
    static let fillSoft = Color.white.opacity(0.06)
    static let fillMid = Color.white.opacity(0.14)
    static let text = Color(red: 0.925, green: 0.914, blue: 0.894)         // #ECE9E4
    static let dim = Color(red: 0.631, green: 0.616, blue: 0.588)          // #A19D96
    static let faint = Color(red: 0.435, green: 0.420, blue: 0.396)        // #6F6B65
    static let accent = Color(rgba: RGBA(hex: Branding.accentHex))
    static let ok = Color(red: 0.30, green: 0.77, blue: 0.43)
    static let warn = Color(red: 0.90, green: 0.65, blue: 0.23)
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
