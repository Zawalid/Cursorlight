import AppKit
import CursorlightCore
import SwiftUI

/// A color picker drawn in the app's own style: a saturation and brightness square, a hue strip, a hex field, an
/// eyedropper and the colors you used lately. It reports every change as `#RRGGBB`.
struct ColorPad: View {
    let initialHex: String
    let onChange: (String) -> Void

    @State private var hue = 0.0
    @State private var saturation = 1.0
    @State private var brightness = 1.0
    @State private var hexText = ""
    @AppStorage("cursorlight.recentColors") private var recentRaw = ""

    private let squareSize = CGSize(width: 232, height: 148)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            square
            hueStrip
            HStack(spacing: 8) {
                Circle().fill(current).frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                TextField("#RRGGBB", text: $hexText)
                    .textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced)).frame(width: 96)
                    .onSubmit { applyHexText() }
                Button { sampleFromScreen() } label: { Image(systemName: "eyedropper") }
                    .help("Pick a color from anywhere on screen")
            }
            if !recents.isEmpty {
                HStack(spacing: 6) {
                    ForEach(recents, id: \.self) { hex in
                        Button { load(hex); commit(remember: false) } label: {
                            Circle().fill(Color(rgba: RGBA(hex: hex))).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain).help(hex)
                    }
                }
            }
        }
        .padding(14).frame(width: 260)
        .onAppear { load(initialHex) }
        .onDisappear { remember(hexString) }
    }

    // MARK: Parts

    private var current: Color { Color(hue: hue, saturation: saturation, brightness: brightness) }

    private var square: some View {
        ZStack {
            LinearGradient(colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
            Circle().stroke(Color.white, lineWidth: 2).background(Circle().fill(current)).frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .position(x: saturation * squareSize.width, y: (1 - brightness) * squareSize.height)
        }
        .frame(width: squareSize.width, height: squareSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            saturation = min(max(value.location.x / squareSize.width, 0), 1)
            brightness = 1 - min(max(value.location.y / squareSize.height, 0), 1)
            commit(remember: false)
        })
        .accessibilityLabel("Saturation and brightness")
    }

    private var hueStrip: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 1, brightness: 1) }, startPoint: .leading, endPoint: .trailing)
                .clipShape(Capsule())
            Circle().fill(Color(hue: hue, saturation: 1, brightness: 1)).overlay(Circle().stroke(Color.white, lineWidth: 2))
                .frame(width: 16, height: 16).shadow(color: .black.opacity(0.4), radius: 2)
                .offset(x: hue * (squareSize.width - 16))
        }
        .frame(width: squareSize.width, height: 14)
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            hue = min(max(value.location.x / squareSize.width, 0), 1)
            commit(remember: false)
        })
        .accessibilityLabel("Hue")
    }

    // MARK: Values

    private var hexString: String {
        let ns = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1).usingColorSpace(.sRGB) ?? .white
        return RGBA(Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent)).hexString
    }

    private func load(_ hex: String) {
        let valid = RGBA.isValidHex(hex) ? hex : "#FF6A3D"
        let c = RGBA(hex: valid)
        let ns = NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h); saturation = Double(s); brightness = Double(b)
        hexText = valid.uppercased()
    }

    private func commit(remember shouldRemember: Bool) {
        let hex = hexString
        hexText = hex
        onChange(hex)
        if shouldRemember { remember(hex) }
    }

    private func applyHexText() {
        let text = hexText.hasPrefix("#") ? hexText : "#" + hexText
        guard RGBA.isValidHex(text) else { hexText = hexString; return }
        load(text)
        commit(remember: true)
    }

    private func sampleFromScreen() {
        NSColorSampler().show { picked in
            guard let picked = picked?.usingColorSpace(.sRGB) else { return }
            let hex = RGBA(Double(picked.redComponent), Double(picked.greenComponent), Double(picked.blueComponent)).hexString
            load(hex)
            commit(remember: true)
        }
    }

    // MARK: Recent colors

    private var recents: [String] {
        recentRaw.split(separator: ",").map(String.init).filter(RGBA.isValidHex)
    }

    private func remember(_ hex: String) {
        guard RGBA.isValidHex(hex) else { return }
        var list = recents.filter { $0.caseInsensitiveCompare(hex) != .orderedSame }
        list.insert(hex.uppercased(), at: 0)
        recentRaw = list.prefix(8).joined(separator: ",")
    }
}

/// The swatch that opens the picker: a rainbow ring until a custom color is in use, then that color.
struct CustomSwatch: View {
    let hex: String
    let selected: Bool
    let onChange: (String) -> Void
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            Group {
                if selected {
                    Circle().fill(Color(rgba: RGBA(hex: hex)))
                } else {
                    Circle().fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
                        .overlay(Image(systemName: "plus").font(.system(size: 8, weight: .bold)).foregroundStyle(.white))
                }
            }
            .frame(width: 17, height: 17)
            .overlay(Circle().stroke(Theme.fillMid, lineWidth: 1))
            .padding(3)
            .overlay(Circle().stroke(selected ? Theme.text : .clear, lineWidth: 1.5))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Custom color")
        .accessibilityLabel("Custom color")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .popover(isPresented: $open, arrowEdge: .bottom) {
            ColorPad(initialHex: hex, onChange: onChange)
        }
    }
}
