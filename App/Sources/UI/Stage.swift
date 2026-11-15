import CursorlightCore
import SwiftUI

/// The top of the window: a miniature display that runs the effect you are editing. A presenter-like pointer glides
/// between things on a slide, a code file or a dashboard; move the real mouse over it and the effect follows, click and
/// it ripples.
struct Stage: View {
    @EnvironmentObject private var model: AppModel
    let style: HighlightStyle
    let look: HighlightLook
    @AppStorage(PreviewScene.storageKey) private var sceneRaw = PreviewScene.slides.rawValue
    @AppStorage(ViewerView.storageKey) private var viewerView = false
    @State private var hover: CGPoint?
    @State private var history = PreviewCanvas.PointerHistory()
    @State private var clicks: [PreviewClick] = []
    @State private var lastHoverMove: Double?

    private var scene: PreviewScene { PreviewScene(rawValue: sceneRaw) ?? .slides }

    var body: some View {
        ZStack {
            DesktopLayer(scene: scene)
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    PreviewCanvas.draw(
                        &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate, style: style, look: look,
                        pointer: hover, history: history, scene: scene, clicks: clicks, ripples: model.settings.clickRipples, lastHoverMove: lastHoverMove
                    )
                }
            }
            .opacity(viewerView && model.declaredShare == .singleWindow ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: viewerView && model.declaredShare == .singleWindow)
        }
        .background(Theme.stage)
        .overlay { if viewerView { ViewerFrame(declared: model.declaredShare) } }
        .onContinuousHover { phase in
            switch phase {
            case let .active(point):
                hover = point
                lastHoverMove = Date().timeIntervalSinceReferenceDate
            case .ended: hover = nil
            }
        }
        .gesture(
            SpatialTapGesture().onEnded { value in
                let now = Date().timeIntervalSinceReferenceDate
                clicks.removeAll { now - $0.time > Autopilot.rippleLength }
                clicks.append(PreviewClick(point: value.location, time: now))
            }
        )
        .accessibilityLabel("\(style.displayName) preview on \(scene.hint)")
    }
}

/// The "what viewers see" preview: the display inside a share frame, and the effects gone when the share is one window.
enum ViewerView {
    static let storageKey = "cursorlight.viewerView"
}

struct ViewerFrame: View {
    let declared: DeclaredShare?

    var body: some View {
        GeometryReader { proxy in
            let screen = PreviewCanvas.screenRect(in: proxy.size)
            let hidden = declared == .singleWindow
            let tint: Color = hidden ? Theme.warn : Theme.ok
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(0.9), lineWidth: 3)
                    .frame(width: screen.width, height: screen.height)
                    .position(x: screen.midX, y: screen.midY)
                HStack(spacing: 6) {
                    Image(systemName: hidden ? "eye.slash" : "eye").font(.system(size: 11, weight: .semibold))
                    Text(caption).font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(.horizontal, 10).frame(height: 24)
                .background(tint, in: Capsule())
                .position(x: screen.midX, y: screen.minY - 20)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var caption: String {
        switch declared {
        case .singleWindow: "Viewers see the shared window only. No effects."
        case .wholeScreen: "Viewers see your whole screen and your effects."
        case .notSharing: "Not sharing."
        case nil: "Viewers see effects if you share the whole screen."
        }
    }
}

/// A small switch on the canvas for the viewer preview.
struct ViewerToggle: View {
    @AppStorage(ViewerView.storageKey) private var on = false

    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { on.toggle() } } label: {
            CanvasChip {
                HStack(spacing: 6) {
                    Image(systemName: on ? "eye.fill" : "eye").font(.system(size: 11, weight: .medium))
                    Text("Viewers")
                }
                .foregroundStyle(on ? Theme.accent : Color.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .help("Preview what an audience sees: the share frame, and no effects on a window share")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
