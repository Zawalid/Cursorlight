import BeaconCore
import SwiftUI

/// The top of the window: a miniature screen that runs the effect you are editing. Move the real mouse over it and the
/// effect follows it; leave it and a looping pointer takes over.
struct Stage: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.25), lineWidth: 0.5))
        .overlay(alignment: .topLeading) {
            Text("Move your mouse here")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.white.opacity(0.7))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) {
                Keycap(text: "⌃"); Keycap(text: "⌥"); Keycap(text: "H")
            }
            .padding(12)
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
