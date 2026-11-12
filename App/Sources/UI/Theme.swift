import BeaconCore
import SwiftUI

/// Colors, type and metrics for every screen. The accent comes from Branding; everything else is neutral.
enum Theme {
    // System semantic colors, so the app follows light and dark like any Mac app. The only brand color is Ember, which is
    // also the app's accent color, so native controls pick it up on their own. The Stage is a screen and stays dark.
    static let window = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color.clear
    static let card = Color(nsColor: .controlBackgroundColor)
    static let raised = Color(nsColor: .quaternarySystemFill)
    static let cardHover = Color(nsColor: .tertiarySystemFill)
    static let stage = Color(red: 0.055, green: 0.055, blue: 0.063)
    static let well = Color(nsColor: .quaternarySystemFill)
    static let line = Color(nsColor: .separatorColor)
    static let fillSoft = Color(nsColor: .quaternarySystemFill)
    static let fillMid = Color(nsColor: .tertiarySystemFill)
    static let text = Color(nsColor: .labelColor)
    static let dim = Color(nsColor: .secondaryLabelColor)
    static let faint = Color(nsColor: .tertiaryLabelColor)
    static let accent = Color(rgba: RGBA(hex: Branding.accentHex))
    static let ok = Color(nsColor: .systemGreen)
    static let warn = Color(nsColor: .systemOrange)
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
