import SwiftUI

/// What the miniature display is showing. Each scene is a believable app window, so the effects are seen on the kind of
/// content people really share: a slide deck, a code editor, a dashboard.
enum PreviewScene: String, CaseIterable, Identifiable {
    case slides, code, dashboard

    static let storageKey = "beacon.previewScene"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slides: "Slides"
        case .code: "Code"
        case .dashboard: "Dashboard"
        }
    }

    var symbol: String {
        switch self {
        case .slides: "play.rectangle"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .dashboard: "chart.line.uptrend.xyaxis"
        }
    }

    var hint: String {
        switch self {
        case .slides: "a slide deck"
        case .code: "a code editor"
        case .dashboard: "a dashboard"
        }
    }

    /// The name shown in the fake menu bar.
    var appName: String {
        switch self {
        case .slides: "Slides"
        case .code: "Code"
        case .dashboard: "Browser"
        }
    }

    /// The menu titles after the app name.
    var menus: [String] {
        switch self {
        case .slides: ["File", "Edit", "View", "Insert", "Format", "Window", "Help"]
        case .code: ["File", "Edit", "View", "Navigate", "Product", "Window", "Help"]
        case .dashboard: ["File", "Edit", "View", "History", "Bookmarks", "Help"]
        }
    }

    /// Which dock icon carries the running dot.
    var dockIndex: Int {
        switch self {
        case .slides: 1
        case .code: 2
        case .dashboard: 3
        }
    }

    /// Where a presenter would point, in the display's own 1280 by 800 space.
    var waypoints: [Waypoint] {
        switch self {
        case .slides:
            [
                Waypoint(x: 554, y: 236), Waypoint(x: 548, y: 404), Waypoint(x: 1072, y: 366, click: true),
                Waypoint(x: 176, y: 358, click: true), Waypoint(x: 504, y: 288),
            ]
        case .code:
            [
                Waypoint(x: 470, y: 258), Waypoint(x: 612, y: 372), Waypoint(x: 580, y: 454, click: true),
                Waypoint(x: 650, y: 510), Waypoint(x: 400, y: 126, click: true),
            ]
        case .dashboard:
            [
                Waypoint(x: 410, y: 248), Waypoint(x: 836, y: 436, click: true), Waypoint(x: 1040, y: 470),
                Waypoint(x: 170, y: 232, click: true), Waypoint(x: 430, y: 134),
            ]
        }
    }

    private static func target(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
    }

    /// The spot the Draw preview circles, in the display's space.
    var inkTarget: CGRect {
        switch self {
        case .slides: Self.target(x: 1072, y: 356, width: 150, height: 108)
        case .code: Self.target(x: 600, y: 446, width: 330, height: 84)
        case .dashboard: Self.target(x: 820, y: 424, width: 170, height: 112)
        }
    }
}

struct Waypoint {
    let x: CGFloat
    let y: CGFloat
    var click = false
}

/// A click on the preview, for the ripple.
struct PreviewClick: Equatable {
    let point: CGPoint
    let time: Double
    var right = false
}

/// A pointer that behaves like a presenter: it glides to a thing, rests on it, sometimes clicks, then moves on.
enum Autopilot {
    static let travel = 1.15
    static let dwell = 1.5
    private static let clickDelay = 1.4
    static let rippleLength = 0.8

    private static func segment(at time: Double, count: Int) -> (index: Int, local: Double) {
        let length = travel + dwell
        let cycle = length * Double(count)
        let u = time.truncatingRemainder(dividingBy: cycle)
        let wrapped = u < 0 ? u + cycle : u
        let index = min(Int(wrapped / length), count - 1)
        return (index, wrapped - Double(index) * length)
    }

    /// The pointer in `rect`, which is the display on the canvas.
    static func point(at time: Double, scene: PreviewScene, in rect: CGRect) -> CGPoint {
        let points = scene.waypoints
        let (index, local) = segment(at: time, count: points.count)
        let from = points[index], to = points[(index + 1) % points.count]
        var x = to.x, y = to.y
        if local < travel {
            let t = local / travel
            let e = t * t * t * (t * (t * 6 - 15) + 10)
            let arc = sin(e * .pi) * 26
            x = from.x + (to.x - from.x) * e
            y = from.y + (to.y - from.y) * e - arc
        }
        x += 2.2 * sin(time * 7.1)
        y += 1.8 * sin(time * 6.3 + 1)
        return CGPoint(x: rect.minX + rect.width * x / DesktopArt.size.width, y: rect.minY + rect.height * y / DesktopArt.size.height)
    }

    /// How long the autopilot pointer has rested, in seconds. 0 while it travels.
    static func stillTime(at time: Double, scene: PreviewScene) -> Double {
        let (_, local) = segment(at: time, count: scene.waypoints.count)
        return max(0, local - travel)
    }

    /// Seconds since the pointer last clicked, while the ripple is still visible. nil otherwise.
    static func clickAge(at time: Double, scene: PreviewScene) -> Double? {
        let points = scene.waypoints
        let (index, local) = segment(at: time, count: points.count)
        guard points[(index + 1) % points.count].click else { return nil }
        let age = local - clickDelay
        return age >= 0 && age < rippleLength ? age : nil
    }
}

/// A compact switcher for the preview scene. The chosen one shows its name; the others are icons.
struct SceneSwitcher: View {
    @AppStorage(PreviewScene.storageKey) private var raw = PreviewScene.slides.rawValue
    @Namespace private var plate

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PreviewScene.allCases) { scene in
                let on = raw == scene.rawValue
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { raw = scene.rawValue }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: scene.symbol).font(.system(size: 11, weight: .medium))
                        if on { Text(scene.title).font(.system(size: 11, weight: .semibold)) }
                    }
                    .foregroundStyle(on ? Color.white : Color.white.opacity(0.55))
                    .padding(.horizontal, 10).frame(height: 26)
                    .background {
                        if on { Capsule().fill(Color.white.opacity(0.14)).matchedGeometryEffect(id: "plate", in: plate) }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Preview on \(scene.hint)")
                .accessibilityLabel(scene.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.4), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12)))
    }
}

/// The still part of the preview: wallpaper, menu bar, windows, dock. It draws only when the scene or size changes, so the
/// moving effect on top costs little.
struct DesktopLayer: View {
    let scene: PreviewScene

    var body: some View {
        Canvas { context, size in
            DesktopArt.draw(context, rect: PreviewCanvas.screenRect(in: size), scene: scene)
        }
    }
}
