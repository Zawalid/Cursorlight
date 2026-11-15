import CursorlightCore
import SwiftUI

/// Step 1: the icon, floating, with light rings leaving it. It leans toward the pointer.
struct IntroStage: View {
    @State private var tilt = CGSize.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t * 0.22 + Double(i) / 3.0).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .strokeBorder(WelcomeStyle.ember.opacity((1 - phase) * 0.42), lineWidth: 1.5 + (1 - phase) * 1.5)
                        .frame(width: 150 + phase * 280, height: 150 + phase * 280)
                }
                Image(nsImage: WelcomeStyle.icon)
                    .resizable().interpolation(.high)
                    .frame(width: 168, height: 168)
                    .scaleEffect(1.24)
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 14)
                    .rotation3DEffect(.degrees(Double(tilt.height) * -9), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(Double(tilt.width) * 11), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .offset(y: reduceMotion ? 0 : CGFloat(sin(t * 1.1)) * 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                withAnimation(.easeOut(duration: 0.25)) {
                    tilt = CGSize(width: (location.x - 200) / 200, height: (location.y - 200) / 200)
                }
            case .ended:
                withAnimation(WelcomeStyle.ease) { tilt = .zero }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Step 4: two small displays that show what the audience sees when you share the screen or one window.
struct ShareStage: View {
    var body: some View {
        VStack(spacing: 14) {
            row(.screen, title: "Entire screen", note: "Viewers see every effect.", good: true)
            Rectangle().fill(WelcomeStyle.hairline).frame(height: 1)
            row(.window, title: "One window", note: "Viewers see the window, without your effects.", good: false)
        }
        .padding(22)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sharing the entire screen shows your effects to viewers. Sharing a single window does not.")
    }

    private func row(_ kind: MiniScreen.Kind, title: String, note: String, good: Bool) -> some View {
        HStack(spacing: 16) {
            MiniScreen(kind: kind).frame(width: 156, height: 104)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(WelcomeStyle.text)
                Text(note).font(.system(size: 12.5)).foregroundStyle(WelcomeStyle.dim).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Image(systemName: good ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(good ? "Works" : "Not visible")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(good ? WelcomeStyle.ok : WelcomeStyle.warn)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }
}

struct MiniScreen: View {
    enum Kind { case screen, window }
    let kind: Kind

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { c, size in
                let frame = CGRect(origin: .zero, size: size)
                let shape = Path(roundedRect: frame, cornerRadius: 11, style: .continuous)
                c.clip(to: shape)
                c.fill(shape, with: .color(Color(red: 0.2, green: 0.23, blue: 0.31)))
                let window = CGRect(x: size.width * 0.16, y: size.height * 0.2, width: size.width * 0.68, height: size.height * 0.62)
                c.fill(Path(roundedRect: window, cornerRadius: 7, style: .continuous), with: .color(Color(red: 0.95, green: 0.94, blue: 0.97)))
                c.fill(Path(roundedRect: CGRect(x: window.minX, y: window.minY, width: window.width, height: 12), cornerRadius: 7, style: .continuous),
                       with: .color(Color(red: 0.84, green: 0.83, blue: 0.89)))
                for i in 0..<3 {
                    c.fill(Path(ellipseIn: CGRect(x: window.minX + 6 + CGFloat(i) * 8, y: window.minY + 4, width: 4, height: 4)), with: .color(.black.opacity(0.22)))
                }
                for (i, w) in [0.7, 0.55, 0.62].enumerated() {
                    c.fill(Path(roundedRect: CGRect(x: window.minX + 10, y: window.minY + 22 + CGFloat(i) * 11, width: window.width * w, height: 4), cornerRadius: 2),
                           with: .color(.black.opacity(0.14)))
                }
                switch kind {
                case .screen:
                    let p = CGPoint(x: window.midX + CGFloat(sin(t * 1.3)) * window.width * 0.32, y: window.midY + CGFloat(cos(t * 1.7)) * window.height * 0.22)
                    c.fill(Path(ellipseIn: CGRect(x: p.x - 26, y: p.y - 26, width: 52, height: 52)),
                           with: .radialGradient(Gradient(colors: [WelcomeStyle.ember.opacity(0.75), WelcomeStyle.ember.opacity(0)]), center: p, startRadius: 0, endRadius: 26))
                    c.stroke(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                case .window:
                    var outside = Path(frame)
                    outside.addPath(Path(roundedRect: window, cornerRadius: 7, style: .continuous))
                    c.fill(outside, with: .color(.black.opacity(0.68)), style: FillStyle(eoFill: true))
                    c.stroke(Path(roundedRect: window, cornerRadius: 7, style: .continuous), with: .color(.white.opacity(0.85)),
                             style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
    }
}

/// Step 5: the menu bar and the popover that opens from the icon.
struct MenuBarStage: View {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.19, green: 0.21, blue: 0.29)
            VStack(spacing: 0) {
                bar
                Spacer()
            }
            popover
                .padding(.top, 44).padding(.trailing, 16)
                .scaleEffect(shown || reduceMotion ? 1 : 0.94, anchor: .topTrailing)
                .opacity(shown || reduceMotion ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : -6)
        }
        .overlay(alignment: .bottom) {
            floatingBar
                .padding(.bottom, 26)
                .opacity(shown || reduceMotion ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 10)
                .animation(WelcomeStyle.ease.delay(0.55), value: shown)
        }
        .onAppear { withAnimation(WelcomeStyle.ease.delay(0.35)) { shown = true } }
        .accessibilityHidden(true)
    }

    private var floatingBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(["circle.dashed", "scope", "scribble.variable", "flashlight.on.fill", "timer"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(symbol == "scope" ? WelcomeStyle.emberLight : WelcomeStyle.dim)
                        .frame(width: 34, height: 30)
                        .background(symbol == "scope" ? Color.white.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .padding(6)
            .background(Capsule().fill(Color(red: 0.09, green: 0.07, blue: 0.15).opacity(0.94)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            Text("Or keep a floating bar on screen")
                .font(.system(size: 11.5)).foregroundStyle(WelcomeStyle.dim)
        }
    }

    private var bar: some View {
        HStack(spacing: 14) {
            Circle().fill(Color.white.opacity(0.85)).frame(width: 9, height: 9)
            Capsule().fill(Color.white.opacity(0.7)).frame(width: 34, height: 6)
            Capsule().fill(Color.white.opacity(0.35)).frame(width: 24, height: 6)
            Spacer()
            ringedIcon
            RoundedRectangle(cornerRadius: 2.5).fill(Color.white.opacity(0.55)).frame(width: 18, height: 9)
            Text("9:41").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Color.black.opacity(0.28))
    }

    private var ringedIcon: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let phase = (timeline.date.timeIntervalSinceReferenceDate * 0.7).truncatingRemainder(dividingBy: 1)
            ZStack {
                Circle().strokeBorder(WelcomeStyle.ember.opacity((1 - phase) * 0.8), lineWidth: 1.5)
                    .frame(width: 20 + phase * 22, height: 20 + phase * 22)
                Image(nsImage: WelcomeStyle.icon).resizable().interpolation(.high).frame(width: 20, height: 20).scaleEffect(1.24)
            }
            .frame(width: 22, height: 22)
        }
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(nsImage: WelcomeStyle.icon).resizable().interpolation(.high).frame(width: 22, height: 22).scaleEffect(1.24)
                Text("Cursorlight").font(.system(size: 12, weight: .semibold)).foregroundStyle(WelcomeStyle.text)
                Spacer()
                Text("On").font(.system(size: 10, weight: .semibold)).foregroundStyle(WelcomeStyle.ok)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(WelcomeStyle.ok.opacity(0.16), in: Capsule())
            }
            label("SCENE")
            HStack(spacing: 6) {
                chip("Stream", selected: true)
                chip("Meeting", selected: false)
                chip("Record", selected: false)
            }
            label("NOW")
            HStack(spacing: 6) {
                chip("Highlight", selected: true, filled: true)
                chip("Laser", selected: false, filled: false)
                chip("Ink", selected: false, filled: false)
            }
            Rectangle().fill(WelcomeStyle.hairline).frame(height: 1).padding(.top, 2)
            HStack {
                Text("Settings").font(.system(size: 10)).foregroundStyle(WelcomeStyle.dim)
                Spacer()
                Text("Pause").font(.system(size: 10)).foregroundStyle(WelcomeStyle.dim)
                Spacer()
                Text("Quit").font(.system(size: 10)).foregroundStyle(WelcomeStyle.dim)
            }
        }
        .padding(14)
        .frame(width: 236)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(red: 0.09, green: 0.07, blue: 0.15).opacity(0.94))
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold)).foregroundStyle(WelcomeStyle.faint).tracking(0.6)
    }

    private func chip(_ text: String, selected: Bool, filled: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(selected ? WelcomeStyle.text : WelcomeStyle.dim)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background((filled ? WelcomeStyle.ember.opacity(0.2) : Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(selected ? WelcomeStyle.ember.opacity(0.8) : Color.white.opacity(0.09), lineWidth: selected ? 1.3 : 1))
    }
}
