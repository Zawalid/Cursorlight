import AppKit
import BeaconCore
import SwiftUI

/// Draws a believable Mac display in a fixed 1280 by 800 space, scaled into any rectangle: a wallpaper, a menu bar with a
/// notch, one app window and a dock. Pure drawing, so it can be cached by the canvas that holds it.
enum DesktopArt {
    static let size = CGSize(width: 1280, height: 800)

    static func draw(_ context: GraphicsContext, rect: CGRect, scene: PreviewScene) {
        var c = context
        let bezel = Path(roundedRect: rect.insetBy(dx: -7, dy: -7), cornerRadius: 20)
        c.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 12))
            layer.fill(bezel, with: .color(.black))
        }
        c.stroke(bezel, with: .color(.white.opacity(0.10)), lineWidth: 1)
        c.clip(to: Path(roundedRect: rect, cornerRadius: 12))
        c.translateBy(x: rect.minX, y: rect.minY)
        let k = rect.width / size.width
        c.scaleBy(x: k, y: k)

        wallpaper(c)
        switch scene {
        case .slides: slides(c)
        case .code: code(c)
        case .dashboard: dashboard(c)
        }
        menuBar(c, app: scene.appName, menus: scene.menus)
        dock(c, active: scene.dockIndex)
    }

    // MARK: Helpers

    private static func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    private static func hx(_ hex: String) -> Color { Color(rgba: RGBA(hex: hex)) }

    private static func box(_ c: GraphicsContext, _ r: CGRect, _ radius: CGFloat, _ color: Color) {
        c.fill(Path(roundedRect: r, cornerRadius: radius, style: .continuous), with: .color(color))
    }

    private static func line(_ c: GraphicsContext, _ r: CGRect, _ radius: CGFloat, _ color: Color, _ width: CGFloat = 1) {
        c.stroke(Path(roundedRect: r, cornerRadius: radius, style: .continuous), with: .color(color), lineWidth: width)
    }

    private static func label(
        _ c: GraphicsContext, _ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, weight: Font.Weight = .regular,
        color: Color, mono: Bool = false, anchor: UnitPoint = .topLeading
    ) {
        let t = Text(s).font(.system(size: size, weight: weight, design: mono ? .monospaced : .default)).foregroundColor(color)
        c.draw(c.resolve(t), at: CGPoint(x: x, y: y), anchor: anchor)
    }

    private static func glyph(
        _ c: GraphicsContext, _ name: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, weight: Font.Weight = .regular,
        color: Color, anchor: UnitPoint = .center
    ) {
        let t = Text("\(Image(systemName: name))").font(.system(size: size, weight: weight)).foregroundColor(color)
        c.draw(c.resolve(t), at: CGPoint(x: x, y: y), anchor: anchor)
    }

    private static func width(_ c: GraphicsContext, _ s: String, size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false) -> CGFloat {
        let t = Text(s).font(.system(size: size, weight: weight, design: mono ? .monospaced : .default))
        return c.resolve(t).measure(in: CGSize(width: 3000, height: 200)).width
    }

    // MARK: Chrome

    private static func wallpaper(_ c: GraphicsContext) {
        let full = Path(CGRect(origin: .zero, size: size))
        c.fill(full, with: .linearGradient(
            Gradient(colors: [hx("#0E1330"), hx("#1B1039")]), startPoint: .zero, endPoint: CGPoint(x: 1280, y: 800)
        ))
        let blobs: [(CGPoint, CGFloat, String, Double)] = [
            (CGPoint(x: 1040, y: 720), 720, "#E8643E", 0.55),
            (CGPoint(x: 160, y: 80), 620, "#4B5BD6", 0.50),
            (CGPoint(x: 640, y: 900), 720, "#8B3FA8", 0.45),
        ]
        for (center, radius, color, alpha) in blobs {
            c.fill(full, with: .radialGradient(
                Gradient(colors: [hx(color).opacity(alpha), hx(color).opacity(0)]), center: center, startRadius: 0, endRadius: radius
            ))
        }
    }

    private static func menuBar(_ c: GraphicsContext, app: String, menus: [String]) {
        c.fill(Path(R(0, 0, 1280, 32)), with: .color(.black.opacity(0.34)))
        let notch = UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14).path(in: R(546, 0, 188, 32))
        c.fill(notch, with: .color(.black))
        glyph(c, "apple.logo", 24, 16, size: 16, weight: .medium, color: .white)
        var x: CGFloat = 52
        for (i, item) in ([app] + menus).enumerated() {
            let weight: Font.Weight = i == 0 ? .bold : .medium
            label(c, item, x, 16, size: 14, weight: weight, color: .white.opacity(0.92), anchor: .leading)
            x += width(c, item, size: 14, weight: weight) + 22
        }
        let clock = "Tue 9:41"
        label(c, clock, 1262, 16, size: 14, weight: .medium, color: .white.opacity(0.92), anchor: .trailing)
        var rx = 1262 - width(c, clock, size: 14, weight: .medium) - 26
        for name in ["battery.100", "wifi", "magnifyingglass", "slider.horizontal.3"] {
            glyph(c, name, rx, 16, size: 14, weight: .medium, color: .white.opacity(0.9))
            rx -= 32
        }
    }

    private static func dock(_ c: GraphicsContext, active: Int) {
        // Real app icons, read from this Mac at run time. Where an app is not installed, a drawn tile stands in.
        let items: [(ids: [String], symbol: String, top: String, bottom: String)] = [
            (["com.apple.finder"], "face.smiling", "#6CC7FF", "#1566E6"),
            (["com.apple.iWork.Keynote", "com.apple.freeform"], "play.rectangle.fill", "#7DB6FF", "#3A6FE0"),
            (["com.apple.dt.Xcode", "com.apple.Terminal"], "chevron.left.forwardslash.chevron.right", "#FFB15A", "#F0603A"),
            (["com.apple.Safari"], "safari", "#6CD0FF", "#1E7BEA"),
            (["com.apple.mail"], "envelope.fill", "#5DB8FF", "#2A6FE8"),
            (["com.apple.Notes"], "note.text", "#FFE27A", "#F5B82E"),
            (["com.apple.Music"], "music.note", "#FF7A8A", "#E5334F"),
        ]
        let icon: CGFloat = 58, gap: CGFloat = 12
        let total = CGFloat(items.count) * icon + CGFloat(items.count - 1) * gap + 28
        let pill = R((1280 - total) / 2, 716, total, 76)
        box(c, pill, 24, .white.opacity(0.14))
        line(c, pill, 24, .white.opacity(0.18))
        for (i, item) in items.enumerated() {
            let x = pill.minX + 14 + CGFloat(i) * (icon + gap)
            let r = R(x, 725, icon, icon)
            if let image = AppIconCache.shared.icon(for: item.ids) {
                c.draw(c.resolve(Image(nsImage: image)), in: r)
            } else {
                c.fill(
                    Path(roundedRect: r, cornerRadius: 13, style: .continuous),
                    with: .linearGradient(Gradient(colors: [hx(item.top), hx(item.bottom)]), startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.maxY))
                )
                glyph(c, item.symbol, r.midX, r.midY, size: 27, weight: .semibold, color: .white)
            }
            if i == active {
                c.fill(Path(ellipseIn: R(r.midX - 2.5, 786, 5, 5)), with: .color(.white.opacity(0.85)))
            }
        }
    }

    /// An app window with its title bar and traffic lights. Returns a context clipped to the window for its content.
    private static func window(_ c: GraphicsContext, _ r: CGRect, fill: Color, bar: Color, title: String, titleColor: Color) -> GraphicsContext {
        let shape = Path(roundedRect: r, cornerRadius: 14, style: .continuous)
        c.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 18))
            layer.fill(shape, with: .color(fill))
        }
        var inner = c
        inner.clip(to: shape)
        inner.fill(Path(r), with: .color(fill))
        inner.fill(Path(R(r.minX, r.minY, r.width, 46)), with: .color(bar))
        inner.fill(Path(R(r.minX, r.minY + 45, r.width, 1)), with: .color(.black.opacity(0.14)))
        for (i, color) in ["#FF5F57", "#FEBC2E", "#28C840"].enumerated() {
            inner.fill(Path(ellipseIn: R(r.minX + 16 + CGFloat(i) * 20, r.minY + 17, 13, 13)), with: .color(hx(color)))
        }
        label(inner, title, r.midX, r.minY + 23, size: 13, weight: .medium, color: titleColor, anchor: .center)
        c.stroke(shape, with: .color(.white.opacity(0.10)), lineWidth: 1)
        return inner
    }

    // MARK: Slides

    private static func slides(_ c: GraphicsContext) {
        let win = R(88, 60, 1104, 636)
        let w = window(c, win, fill: hx("#D9DBE0"), bar: hx("#ECEDF0"), title: "Q3 Roadmap", titleColor: hx("#3A3D47"))
        glyph(w, "play.fill", win.maxX - 118, win.minY + 23, size: 13, color: hx("#555967"))
        glyph(w, "square.and.arrow.up", win.maxX - 82, win.minY + 23, size: 14, color: hx("#555967"))
        glyph(w, "textformat", win.maxX - 46, win.minY + 23, size: 14, color: hx("#555967"))

        // Slide navigator
        w.fill(Path(R(win.minX, win.minY + 46, 168, win.height - 46)), with: .color(hx("#ECEDF1")))
        w.fill(Path(R(win.minX + 167, win.minY + 46, 1, win.height - 46)), with: .color(.black.opacity(0.1)))
        let barHeights: [CGFloat] = [8, 14, 11, 18]
        for i in 0..<5 {
            let t = R(112, 130 + 96 * CGFloat(i), 128, 72)
            box(w, t, 6, .white)
            box(w, R(t.minX + 10, t.minY + 10, 58, 7), 3, hx("#2B2D36"))
            box(w, R(t.minX + 10, t.minY + 24, 66, 4), 2, hx("#C9CCD6"))
            box(w, R(t.minX + 10, t.minY + 32, 50, 4), 2, hx("#C9CCD6"))
            for (b, h) in barHeights.enumerated() {
                box(w, R(t.minX + 84 + CGFloat(b) * 10, t.maxY - 10 - h, 7, h), 1.5, i == 1 && b == 3 ? hx("#4F46E5") : hx("#D3D6F4"))
            }
            label(w, "\(i + 1)", t.minX - 10, t.midY, size: 11, weight: .medium, color: hx("#7A7E8C"), anchor: .trailing)
            if i == 1 {
                w.stroke(Path(roundedRect: t.insetBy(dx: -3, dy: -3), cornerRadius: 8, style: .continuous), with: .color(hx("#2F7BF6")), lineWidth: 3)
            }
        }

        // The slide
        let s = R(304, 165, 840, 472)
        w.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6))
            layer.fill(Path(s), with: .color(.white))
        }
        box(w, s, 3, .white)
        label(w, "Q3 Roadmap", s.minX + 56, s.minY + 44, size: 52, weight: .bold, color: hx("#14151A"))
        label(w, "Shipping the new onboarding", s.minX + 56, s.minY + 112, size: 22, color: hx("#6B7080"))
        let bullets = ["Faster setup, under two minutes", "One workspace for every team", "Reports your whole company reads"]
        for (i, text) in bullets.enumerated() {
            let y = s.minY + 188 + CGFloat(i) * 50
            w.fill(Path(ellipseIn: R(s.minX + 58, y + 8, 10, 10)), with: .color(hx("#4F46E5")))
            label(w, text, s.minX + 84, y, size: 22, weight: .medium, color: hx("#23252E"))
        }
        // Bar chart
        let heights: [CGFloat] = [70, 96, 88, 130, 196]
        let months = ["Apr", "May", "Jun", "Jul", "Aug"]
        let baseline = s.minY + 388
        for (i, h) in heights.enumerated() {
            let x = s.minX + 488 + CGFloat(i) * 66
            box(w, R(x, baseline - h, 40, h), 6, i == 4 ? hx("#4F46E5") : hx("#D3D6F4"))
            label(w, months[i], x + 20, baseline + 12, size: 12, weight: .medium, color: hx("#8A8EA0"), anchor: .top)
        }
        w.fill(Path(R(s.minX + 470, baseline, 320, 1)), with: .color(hx("#D8DAE2")))
        label(w, "+38%", s.minX + 772, baseline - 196 - 12, size: 24, weight: .bold, color: hx("#4F46E5"), anchor: .bottom)
        label(w, "Beacon Labs  -  Q3 review", s.minX + 56, s.maxY - 34, size: 12, color: hx("#9A9EAE"))
        label(w, "2", s.maxX - 56, s.maxY - 34, size: 12, color: hx("#9A9EAE"), anchor: .topTrailing)
    }

    // MARK: Code

    private static func code(_ c: GraphicsContext) {
        let win = R(88, 60, 1104, 636)
        let w = window(c, win, fill: hx("#1F2024"), bar: hx("#2B2C32"), title: "ContentView.swift", titleColor: .white.opacity(0.75))

        // Sidebar
        w.fill(Path(R(win.minX, win.minY + 46, 212, win.height - 46)), with: .color(hx("#1A1B1F")))
        w.fill(Path(R(win.minX + 211, win.minY + 46, 1, win.height - 46)), with: .color(.white.opacity(0.06)))
        let files: [(String, String, CGFloat, Bool)] = [
            ("folder.fill", "Demo", 0, false), ("folder", "App", 14, false), ("swift", "DemoApp.swift", 28, false),
            ("swift", "ContentView.swift", 28, true), ("swift", "Store.swift", 28, false), ("photo.on.rectangle", "Assets", 14, false),
            ("gearshape", "Info.plist", 14, false),
        ]
        for (i, f) in files.enumerated() {
            let y = win.minY + 74 + CGFloat(i) * 32
            if f.3 { box(w, R(win.minX + 8, y - 14, 196, 28), 6, hx("#2F5BD0").opacity(0.55)) }
            glyph(w, f.0, win.minX + 22 + f.2, y, size: 13, color: f.0 == "swift" ? hx("#FF8A4C") : hx("#7FB2FF"))
            label(w, f.1, win.minX + 42 + f.2, y, size: 14, weight: f.3 ? .semibold : .regular, color: .white.opacity(f.3 ? 0.95 : 0.7), anchor: .leading)
        }

        // Tabs
        let tabY = win.minY + 46
        w.fill(Path(R(win.minX + 212, tabY, win.width - 212, 40)), with: .color(hx("#25262B")))
        w.fill(Path(R(win.minX + 212, tabY, 180, 40)), with: .color(hx("#1F2024")))
        glyph(w, "swift", win.minX + 232, tabY + 20, size: 12, color: hx("#FF8A4C"))
        label(w, "ContentView.swift", win.minX + 250, tabY + 20, size: 13, weight: .medium, color: .white.opacity(0.9), anchor: .leading)
        label(w, "Store.swift", win.minX + 420, tabY + 20, size: 13, color: .white.opacity(0.45), anchor: .leading)

        // Editor
        let top: CGFloat = 164, lineHeight: CGFloat = 28
        w.fill(Path(R(300, top + 7 * lineHeight - 4, 822, lineHeight)), with: .color(.white.opacity(0.055)))
        let kw = hx("#FF7AB2"), ty = hx("#5DD8FF"), st = hx("#FC6A5D"), nu = hx("#D9C97C"), pl = hx("#DFE1E6")
        let rows: [[(String, Color)]] = [
            [("import", kw), (" SwiftUI", ty)],
            [],
            [("struct", kw), (" ContentView", ty), (": ", pl), ("View", ty), (" {", pl)],
            [("    ", pl), ("@State", kw), (" ", pl), ("private", kw), (" ", pl), ("var", kw), (" count = ", pl), ("0", nu)],
            [],
            [("    ", pl), ("var", kw), (" body: ", pl), ("some", kw), (" ", pl), ("View", ty), (" {", pl)],
            [("        VStack(spacing: ", pl), ("16", nu), (") {", pl)],
            [("            Text(", pl), ("\"Hello, world\"", st), (")", pl)],
            [("                .font(.largeTitle)", pl)],
            [("            Button(", pl), ("\"Add one\"", st), (") {", pl)],
            [("                count += ", pl), ("1", nu)],
            [("            }", pl)],
            [("            .buttonStyle(.borderedProminent)", pl)],
            [("        }", pl)],
            [("        .padding()", pl)],
            [("    }", pl)],
            [("}", pl)],
        ]
        for (i, row) in rows.enumerated() {
            let y = top + CGFloat(i) * lineHeight + lineHeight / 2 - 4
            label(w, "\(i + 1)", 342, y, size: 14, color: .white.opacity(i == 7 ? 0.7 : 0.28), mono: true, anchor: .trailing)
            var x: CGFloat = 366
            for (text, color) in row {
                label(w, text, x, y, size: 16, color: color, mono: true, anchor: .leading)
                x += width(w, text, size: 16, mono: true)
            }
        }
        // Minimap
        for i in 0..<rows.count {
            let n = rows[i].reduce(0) { $0 + $1.0.count }
            if n > 0 { box(w, R(1128, top + CGFloat(i) * 9, CGFloat(n) * 1.6, 3), 1.5, .white.opacity(0.18)) }
        }
        // Status bar
        w.fill(Path(R(win.minX, win.maxY - 26, win.width, 26)), with: .color(hx("#2B2C32")))
        label(w, "Ln 8, Col 24", win.maxX - 150, win.maxY - 13, size: 12, color: .white.opacity(0.6), anchor: .leading)
        label(w, "Swift", win.maxX - 50, win.maxY - 13, size: 12, color: .white.opacity(0.6), anchor: .leading)
        glyph(w, "checkmark.circle.fill", win.minX + 226, win.maxY - 13, size: 12, color: hx("#4CD964"))
        label(w, "Build succeeded", win.minX + 244, win.maxY - 13, size: 12, color: .white.opacity(0.6), anchor: .leading)
    }

    // MARK: Dashboard

    private static func dashboard(_ c: GraphicsContext) {
        let win = R(88, 60, 1104, 636)
        let w = window(c, win, fill: hx("#F4F5F8"), bar: hx("#ECEDF1"), title: "", titleColor: .clear)
        let url = R(win.midX - 160, win.minY + 11, 320, 24)
        box(w, url, 12, hx("#DDDFE6"))
        glyph(w, "lock.fill", url.minX + 18, url.midY, size: 10, color: hx("#6B6F7E"))
        label(w, "app.northwind.io/overview", url.midX + 6, url.midY, size: 12, weight: .medium, color: hx("#4A4D5A"), anchor: .center)

        // Sidebar
        w.fill(Path(R(win.minX, win.minY + 46, 200, win.height - 46)), with: .color(hx("#14172B")))
        label(w, "Northwind", win.minX + 24, win.minY + 84, size: 18, weight: .bold, color: .white, anchor: .leading)
        let nav: [(String, String)] = [
            ("square.grid.2x2", "Overview"), ("chart.bar", "Reports"), ("person.2", "Customers"),
            ("creditcard", "Billing"), ("gearshape", "Settings"),
        ]
        for (i, item) in nav.enumerated() {
            let y = win.minY + 140 + CGFloat(i) * 44
            if i == 0 { box(w, R(win.minX + 12, y - 18, 176, 36), 9, .white.opacity(0.10)) }
            glyph(w, item.0, win.minX + 34, y, size: 15, color: .white.opacity(i == 0 ? 0.95 : 0.55))
            label(w, item.1, win.minX + 58, y, size: 15, weight: i == 0 ? .semibold : .regular, color: .white.opacity(i == 0 ? 0.95 : 0.6), anchor: .leading)
        }

        // Header
        let cx: CGFloat = 320
        label(w, "Overview", cx, 132, size: 30, weight: .bold, color: hx("#15171F"))
        let range = R(1192 - 28 - 138, 132, 138, 30)
        box(w, range, 9, .white)
        line(w, range, 9, hx("#DDE0E8"))
        label(w, "Last 30 days", range.minX + 14, range.midY, size: 13, weight: .medium, color: hx("#4A4D5A"), anchor: .leading)
        glyph(w, "chevron.down", range.maxX - 16, range.midY, size: 10, weight: .semibold, color: hx("#7A7E8C"))

        // KPI cards
        let kpis: [(String, String, String)] = [("Revenue", "$48,230", "+12.4%"), ("Customers", "1,284", "+4.1%"), ("Churn", "2.1%", "-0.3%")]
        for (i, k) in kpis.enumerated() {
            let r = R(cx + CGFloat(i) * 288, 188, 272, 112)
            box(w, r, 14, .white)
            line(w, r, 14, hx("#E6E8EE"))
            label(w, k.0, r.minX + 20, r.minY + 20, size: 14, weight: .medium, color: hx("#7A7E8C"))
            label(w, k.1, r.minX + 20, r.minY + 48, size: 34, weight: .bold, color: hx("#15171F"))
            let tag = R(r.maxX - 84, r.minY + 18, 64, 24)
            box(w, tag, 12, hx("#DDF5E6"))
            label(w, k.2, tag.midX, tag.midY, size: 12, weight: .semibold, color: hx("#1E8E4E"), anchor: .center)
        }

        // Chart card
        let card = R(cx, 322, 560, 340)
        box(w, card, 14, .white)
        line(w, card, 14, hx("#E6E8EE"))
        label(w, "Revenue", card.minX + 24, card.minY + 22, size: 16, weight: .bold, color: hx("#15171F"))
        label(w, "Daily, last 12 weeks", card.minX + 24, card.minY + 44, size: 12, color: hx("#8A8EA0"))
        let plot = R(card.minX + 64, card.minY + 84, 468, 210)
        for i in 0..<4 {
            let y = plot.minY + plot.height * CGFloat(i) / 3
            w.fill(Path(R(plot.minX, y, plot.width, 1)), with: .color(hx("#ECEEF3")))
            label(w, "$\(60 - i * 20)k", plot.minX - 12, y, size: 11, color: hx("#9A9EAE"), anchor: .trailing)
        }
        let values: [CGFloat] = [0.32, 0.40, 0.36, 0.48, 0.44, 0.55, 0.50, 0.62, 0.58, 0.70, 0.66, 0.80]
        let pts = values.enumerated().map { i, v in
            CGPoint(x: plot.minX + plot.width * CGFloat(i) / CGFloat(values.count - 1), y: plot.minY + plot.height * (1 - v))
        }
        var curve = Path()
        curve.move(to: pts[0])
        for i in 1..<pts.count {
            let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
            curve.addQuadCurve(to: mid, control: pts[i - 1])
        }
        curve.addLine(to: pts[pts.count - 1])
        var area = curve
        area.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        area.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        area.closeSubpath()
        w.fill(area, with: .linearGradient(
            Gradient(colors: [hx("#4F46E5").opacity(0.22), hx("#4F46E5").opacity(0)]),
            startPoint: CGPoint(x: 0, y: plot.minY), endPoint: CGPoint(x: 0, y: plot.maxY)
        ))
        w.stroke(curve, with: .color(hx("#4F46E5")), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        let last = pts[pts.count - 1]
        w.fill(Path(ellipseIn: R(last.x - 7, last.y - 7, 14, 14)), with: .color(.white))
        w.stroke(Path(ellipseIn: R(last.x - 7, last.y - 7, 14, 14)), with: .color(hx("#4F46E5")), lineWidth: 3)
        let tip = R(last.x - 74, last.y - 52, 82, 32)
        box(w, tip, 8, hx("#15171F"))
        label(w, "$48.2k", tip.midX, tip.midY, size: 14, weight: .semibold, color: .white, anchor: .center)
        for (i, m) in ["Jul", "Aug", "Sep"].enumerated() {
            label(w, m, plot.minX + plot.width * CGFloat(i) * 0.5, plot.maxY + 16, size: 11, color: hx("#9A9EAE"), anchor: .top)
        }

        // Recent orders
        let table = R(896, 322, 296 - 28, 340)
        box(w, table, 14, .white)
        line(w, table, 14, hx("#E6E8EE"))
        label(w, "Recent orders", table.minX + 22, table.minY + 22, size: 16, weight: .bold, color: hx("#15171F"))
        let orders: [(String, String, String, String)] = [
            ("Ava Moreau", "Pro plan", "$240", "#4F46E5"), ("Liam Chen", "Team plan", "$480", "#E8643E"),
            ("Noor Haddad", "Pro plan", "$240", "#14B8A6"), ("Sam Okafor", "Starter", "$60", "#E8932A"),
            ("Mia Rossi", "Team plan", "$480", "#8B7CFF"),
        ]
        for (i, o) in orders.enumerated() {
            let y = table.minY + 84 + CGFloat(i) * 46
            w.fill(Path(ellipseIn: R(table.minX + 22, y - 16, 32, 32)), with: .color(hx(o.3)))
            label(w, String(o.0.prefix(1)), table.minX + 38, y, size: 13, weight: .bold, color: .white, anchor: .center)
            label(w, o.0, table.minX + 66, y - 8, size: 14, weight: .semibold, color: hx("#23252E"), anchor: .leading)
            label(w, o.1, table.minX + 66, y + 10, size: 12, color: hx("#8A8EA0"), anchor: .leading)
            label(w, o.2, table.maxX - 22, y, size: 14, weight: .semibold, color: hx("#23252E"), anchor: .trailing)
        }
    }
}

/// App icons read from this Mac, so the preview shows the real ones without Beacon shipping a copy of any artwork.
/// Looked up once per app; an app that is not installed is remembered as missing.
final class AppIconCache: @unchecked Sendable {
    static let shared = AppIconCache()

    private let lock = NSLock()
    private var found: [String: NSImage] = [:]
    private var missing: Set<String> = []

    /// The icon of the first installed app among `bundleIDs`.
    func icon(for bundleIDs: [String]) -> NSImage? {
        for id in bundleIDs {
            if let image = icon(id) { return image }
        }
        return nil
    }

    private func icon(_ bundleID: String) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        if let image = found[bundleID] { return image }
        if missing.contains(bundleID) { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            missing.insert(bundleID)
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        found[bundleID] = image
        return image
    }
}
