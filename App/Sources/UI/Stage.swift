import BeaconCore
import SwiftUI

/// The top of the window: a miniature display that runs the effect you are editing. A presenter-like pointer glides
/// between things on a slide, a code file or a dashboard; move the real mouse over it and the effect follows, click and
/// it ripples.
struct Stage: View {
    @EnvironmentObject private var model: AppModel
    let style: HighlightStyle
    let look: HighlightLook
    @AppStorage(PreviewScene.storageKey) private var sceneRaw = PreviewScene.slides.rawValue
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
        }
        .background(Theme.stage)
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
