import SwiftUI

enum DemoMode: Hashable {
    case aura, laser, ink, spotlight
}

/// The state behind the guide's playable stage: where the pointer is, how it moves, and what has been drawn.
/// It is plain mutable state read by a Canvas every frame, all on the main thread, so it is not observed.
final class DemoPointer: @unchecked Sendable {
    struct Sample { var point: CGPoint; var time: Double }
    struct Stroke { var points: [CGPoint]; var endedAt: Double? }

    private(set) var hasPointer = false
    private(set) var target = CGPoint.zero
    private(set) var display = CGPoint.zero
    private(set) var found = false
    private(set) var foundAt: Double = -10
    private(set) var hintOpacity: Double = 1
    private var trail: [Sample] = []
    private var strokes: [Stroke] = []
    private var shake: [Sample] = []
    private var lastToggle: Double = -10
    private var lastFrame: Double = 0

    static func now() -> Double { Date().timeIntervalSinceReferenceDate }

    // MARK: Input

    func move(_ point: CGPoint, at time: Double) {
        if !hasPointer { display = point }
        hasPointer = true
        target = point
        trail.append(Sample(point: point, time: time))
        if trail.count > 90 { trail.removeFirst(trail.count - 90) }
        recognizeShake(point, time)
        if var last = strokes.last, last.endedAt == nil {
            last.points.append(point)
            strokes[strokes.count - 1] = last
        }
    }

    func leave() {
        hasPointer = false
        shake.removeAll()
        endStroke(at: Self.now())
    }

    func beginStroke(_ point: CGPoint) {
        strokes.append(Stroke(points: [point], endedAt: nil))
    }

    func endStroke(at time: Double) {
        guard var last = strokes.last, last.endedAt == nil else { return }
        last.endedAt = time
        strokes[strokes.count - 1] = last
    }

    func reset() {
        trail.removeAll()
        strokes.removeAll()
        shake.removeAll()
    }

    // MARK: Shake: four quick direction changes within under a second.

    private func recognizeShake(_ point: CGPoint, _ time: Double) {
        shake.append(Sample(point: point, time: time))
        shake.removeAll { time - $0.time > 0.8 }
        guard shake.count > 6, time - lastToggle > 1.1 else { return }
        var reversals = 0
        var direction = 0
        var extreme = shake[0].point.x
        let amplitude: CGFloat = 34
        for sample in shake.dropFirst() {
            let x = sample.point.x
            if direction == 0 {
                if abs(x - extreme) > amplitude { direction = x > extreme ? 1 : -1; extreme = x }
            } else if direction == 1 {
                if x > extreme { extreme = x } else if extreme - x > amplitude { reversals += 1; direction = -1; extreme = x }
            } else {
                if x < extreme { extreme = x } else if x - extreme > amplitude { reversals += 1; direction = 1; extreme = x }
            }
        }
        if reversals >= 4 {
            found.toggle()
            foundAt = time
            lastToggle = time
            shake.removeAll()
        }
    }

    // MARK: Frame

    func advance(now: Double, mode: DemoMode) {
        let dt = lastFrame == 0 ? 1.0 / 60.0 : min(now - lastFrame, 0.1)
        lastFrame = now
        let follow = 1 - exp(-dt * 20)
        display.x += (target.x - display.x) * follow
        display.y += (target.y - display.y) * follow
        let wantHint: Double = !hasPointer ? 1 : (mode == .aura && !found ? 0.7 : 0)
        hintOpacity += (wantHint - hintOpacity) * (1 - exp(-dt * 8))
        trail.removeAll { now - $0.time > 0.8 }
        strokes.removeAll { stroke in stroke.endedAt.map { now - $0 > 3.2 } ?? false }
    }

    // MARK: Drawing

    func draw(_ context: inout GraphicsContext, size: CGSize, mode: DemoMode, now: Double) {
        drawDesk(&context, size)
        switch mode {
        case .aura: drawAura(&context, now)
        case .laser: drawLaser(&context, now)
        case .ink: drawInk(&context, now)
        case .spotlight: drawSpotlight(&context, size)
        }
    }

    private func drawDesk(_ c: inout GraphicsContext, _ size: CGSize) {
        let window = CGRect(x: 26, y: 34, width: size.width - 52, height: size.height - 68)
        c.fill(Path(roundedRect: window, cornerRadius: 14, style: .continuous), with: .color(.white.opacity(0.05)))
        c.stroke(Path(roundedRect: window, cornerRadius: 14, style: .continuous), with: .color(.white.opacity(0.09)), lineWidth: 1)
        for i in 0..<3 {
            c.fill(Path(ellipseIn: CGRect(x: window.minX + 14 + CGFloat(i) * 15, y: window.minY + 14, width: 8, height: 8)), with: .color(.white.opacity(0.16)))
        }
        let side = CGRect(x: window.minX + 14, y: window.minY + 40, width: 74, height: window.height - 54)
        c.fill(Path(roundedRect: side, cornerRadius: 9, style: .continuous), with: .color(.white.opacity(0.045)))
        for i in 0..<6 {
            let w: CGFloat = [46, 38, 52, 34, 44, 40][i]
            c.fill(Path(roundedRect: CGRect(x: side.minX + 10, y: side.minY + 14 + CGFloat(i) * 22, width: w, height: 7), cornerRadius: 3.5), with: .color(.white.opacity(0.10)))
        }
        let main = CGRect(x: side.maxX + 16, y: side.minY, width: window.maxX - side.maxX - 30, height: side.height)
        c.fill(Path(roundedRect: CGRect(x: main.minX, y: main.minY + 4, width: main.width * 0.55, height: 12), cornerRadius: 6), with: .color(.white.opacity(0.17)))
        let widths: [CGFloat] = [0.95, 0.88, 0.72, 0.92, 0.6]
        for (i, w) in widths.enumerated() {
            c.fill(Path(roundedRect: CGRect(x: main.minX, y: main.minY + 32 + CGFloat(i) * 17, width: main.width * w, height: 6), cornerRadius: 3), with: .color(.white.opacity(0.09)))
        }
        let cardTop = main.minY + 130
        let cardW = (main.width - 20) / 3
        for i in 0..<3 {
            let rect = CGRect(x: main.minX + CGFloat(i) * (cardW + 10), y: cardTop, width: cardW, height: min(110, main.maxY - cardTop - 4))
            c.fill(Path(roundedRect: rect, cornerRadius: 10, style: .continuous), with: .color(.white.opacity(0.055)))
            c.fill(Path(roundedRect: CGRect(x: rect.minX + 10, y: rect.minY + 12, width: rect.width * 0.5, height: 6), cornerRadius: 3), with: .color(.white.opacity(0.14)))
            c.fill(Path(roundedRect: CGRect(x: rect.minX + 10, y: rect.minY + 28, width: rect.width * 0.7, height: 5), cornerRadius: 2.5), with: .color(.white.opacity(0.08)))
        }
    }

    private func drawAura(_ c: inout GraphicsContext, _ now: Double) {
        guard hasPointer else { return }
        let p = display
        let ember = WelcomeStyle.ember
        if found {
            let age = now - foundAt
            let grow = min(1, age / 0.55)
            let eased = 1 - pow(1 - grow, 3)
            let r = 30 + 84 * eased
            c.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.7, y: p.y - r * 1.7, width: r * 3.4, height: r * 3.4)),
                   with: .radialGradient(Gradient(colors: [ember.opacity(0.62), ember.opacity(0.18), ember.opacity(0)]), center: p, startRadius: 0, endRadius: r * 1.7))
            c.stroke(Path(ellipseIn: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.55, width: r * 1.1, height: r * 1.1)),
                     with: .color(.white.opacity(0.5)), lineWidth: 1.5)
            for i in 0..<2 {
                let phase = (age * 0.8 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let rr = 22 + phase * 120
                c.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                         with: .color(ember.opacity((1 - phase) * 0.55)), lineWidth: 2)
            }
        } else {
            let r: CGFloat = 26
            c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                   with: .radialGradient(Gradient(colors: [ember.opacity(0.26), ember.opacity(0)]), center: p, startRadius: 0, endRadius: r))
        }
    }

    private func drawLaser(_ c: inout GraphicsContext, _ now: Double) {
        guard hasPointer else { return }
        let ember = WelcomeStyle.ember
        var previous: CGPoint?
        for sample in trail {
            let alpha = max(0, 1 - (now - sample.time) / 0.8)
            if let previous {
                var path = Path()
                path.move(to: previous)
                path.addLine(to: sample.point)
                c.stroke(path, with: .color(ember.opacity(alpha * 0.9)), style: StrokeStyle(lineWidth: 1.5 + 5 * alpha, lineCap: .round))
            }
            previous = sample.point
        }
        let p = target
        c.fill(Path(ellipseIn: CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)),
               with: .radialGradient(Gradient(colors: [ember.opacity(0.55), ember.opacity(0)]), center: p, startRadius: 0, endRadius: 22))
        c.fill(Path(ellipseIn: CGRect(x: p.x - 5.5, y: p.y - 5.5, width: 11, height: 11)), with: .color(Color(red: 1, green: 0.86, blue: 0.8)))
    }

    private func drawInk(_ c: inout GraphicsContext, _ now: Double) {
        for stroke in strokes {
            var alpha = 1.0
            if let end = stroke.endedAt, now - end > 2.0 { alpha = max(0, 1 - (now - end - 2.0) / 1.2) }
            guard stroke.points.count > 1 else { continue }
            var path = Path()
            path.move(to: stroke.points[0])
            for i in 1..<stroke.points.count {
                let mid = CGPoint(x: (stroke.points[i - 1].x + stroke.points[i].x) / 2, y: (stroke.points[i - 1].y + stroke.points[i].y) / 2)
                path.addQuadCurve(to: mid, control: stroke.points[i - 1])
            }
            if let last = stroke.points.last { path.addLine(to: last) }
            c.stroke(path, with: .color(WelcomeStyle.ember.opacity(alpha * 0.35)), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            c.stroke(path, with: .color(WelcomeStyle.emberLight.opacity(alpha)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
        }
        if hasPointer {
            let p = target
            c.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(WelcomeStyle.emberLight))
        }
    }

    private func drawSpotlight(_ c: inout GraphicsContext, _ size: CGSize) {
        let p = hasPointer ? display : CGPoint(x: size.width / 2, y: size.height / 2)
        let r: CGFloat = 78
        let alpha = hasPointer ? 1.0 : 0.0
        c.drawLayer { layer in
            layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.72 * alpha)))
            layer.blendMode = .destinationOut
            layer.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.35, y: p.y - r * 1.35, width: r * 2.7, height: r * 2.7)),
                       with: .radialGradient(
                        Gradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.66), .init(color: .black.opacity(0), location: 1)]),
                        center: p, startRadius: 0, endRadius: r * 1.35))
        }
    }
}

/// The playable stage: a faint desktop that reacts to the real pointer.
struct DemoStage: View {
    let demo: DemoPointer
    let mode: DemoMode

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { context, size in
                    demo.advance(now: now, mode: mode)
                    demo.draw(&context, size: size, mode: mode, now: now)
                }
                hint(now: now)
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location): demo.move(location, at: DemoPointer.now())
            case .ended: demo.leave()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard mode == .ink else { return }
                    if value.translation == .zero { demo.beginStroke(value.location) }
                }
                .onEnded { _ in if mode == .ink { demo.endStroke(at: DemoPointer.now()) } }
        )
        .onChange(of: mode) { _, _ in demo.reset() }
    }

    private func hint(now: Double) -> some View {
        VStack {
            Spacer()
            ZStack {
                Text(hintText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(WelcomeStyle.text)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    .opacity(demo.hintOpacity)
                if demo.found {
                    let visible = now - demo.foundAt > 0.35
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(WelcomeStyle.ok)
                        Text("Found it. Shake again to hide it.")
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(WelcomeStyle.text)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    .opacity(visible && mode == .aura ? 1 : 0)
                }
            }
            .padding(.bottom, 20)
        }
        .allowsHitTesting(false)
    }

    private var hintText: String {
        switch mode {
        case .aura: "Move here, then shake the mouse"
        case .laser: "Move the pointer"
        case .ink: "Click and drag to draw"
        case .spotlight: "Move the pointer"
        }
    }
}
