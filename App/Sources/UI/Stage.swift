import BeaconCore
import SwiftUI

/// The top of the window: a miniature desktop that runs the effect you are editing. Move the real mouse over it and the
/// effect follows it; leave it and a looping pointer takes over.
struct Stage: View {
    @EnvironmentObject private var model: AppModel
    let style: HighlightStyle
    let look: HighlightLook
    @State private var hover: CGPoint?
    @State private var history = PreviewCanvas.PointerHistory()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                PreviewCanvas.draw(
                    &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate, style: style, look: look,
                    pointer: hover, history: history
                )
            }
        }
        .background(Theme.stage)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) { Keycap(text: "⌃", dark: true); Keycap(text: "⌥", dark: true); Keycap(text: "H", dark: true) }
                .padding(16)
        }
        .onContinuousHover { phase in
            switch phase {
            case let .active(point): hover = point
            case .ended: hover = nil
            }
        }
        .accessibilityLabel("\(style.displayName) preview")
    }
}

