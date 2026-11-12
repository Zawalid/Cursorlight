import AppKit
import BeaconCore
import SwiftUI

private final class TimerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The timer chip: a small floating panel that never takes focus, hidden from screen sharing like the bar by default.
@MainActor
final class TimerController: ObservableObject {
    @Published private(set) var timer = PresenterTimer()
    @Published private(set) var isShown = false
    private let model: AppModel
    private var panel: TimerPanel?
    private var host: NSHostingView<AnyView>?
    private var moveObserver: NSObjectProtocol?

    init(model: AppModel) { self.model = model }

    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func toggle() { isShown ? hide() : show() }

    func show() {
        let panel = self.panel ?? makePanel()
        panel.sharingType = model.settings.toolbar.hiddenFromViewers ? .none : .readOnly
        resize(panel)
        if !panel.isVisible { place(panel) }
        panel.orderFrontRegardless()
        isShown = true
    }

    func hide() {
        panel?.orderOut(nil)
        isShown = false
    }

    // MARK: Timer controls

    func start(_ mode: PresenterTimer.Mode) { timer.start(mode, at: now) }

    /// The timer parts of a `beacon://` link.
    func run(_ command: BeaconLinkCommand) {
        switch command {
        case .timerToggle: toggle()
        case let .timerStart(minutes):
            show()
            start(.countdown(TimeInterval((minutes ?? 10) * 60)))
        case .timerStop: reset()
        default: break
        }
    }
    func pause() { timer.pause(at: now) }
    func resume() { timer.resume(at: now) }
    func reset() { timer.reset() }

    // MARK: Panel

    private func makePanel() -> TimerPanel {
        let panel = TimerPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 70), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.title = "Beacon timer"
        let host = NSHostingView(rootView: AnyView(TimerView(controller: self).tint(Theme.accent)))
        panel.contentView = host
        self.host = host
        self.panel = panel
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveOrigin() }
        }
        return panel
    }

    private func resize(_ panel: TimerPanel) {
        guard let host else { return }
        let size = host.fittingSize
        guard size.width > 0, size.height > 0, panel.frame.size != size else { return }
        panel.setContentSize(size)
    }

    /// Called by the view when its content changes size (idle presets versus running controls).
    func contentChanged() {
        if let panel { DispatchQueue.main.async { MainActor.assumeIsolated { self.resize(panel) } } }
    }

    private func place(_ panel: TimerPanel) {
        let screens = NSScreen.screens
        if let saved = model.settings.toolbar.timerOrigin, screens.contains(where: { $0.frame.insetBy(dx: -40, dy: -40).contains(saved) }) {
            panel.setFrameOrigin(saved)
            return
        }
        let area = (NSScreen.main ?? screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 16, y: area.maxY - panel.frame.height - 8))
    }

    private func saveOrigin() {
        guard let panel, panel.isVisible else { return }
        let origin = panel.frame.origin
        model.setToolbar { $0.timerOriginX = origin.x; $0.timerOriginY = origin.y }
    }
}

struct TimerView: View {
    @ObservedObject var controller: TimerController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let now = controller.now
            let t = controller.timer
            let urgency = t.urgency(at: now)
            let tint: Color = urgency == .over ? Color(red: 1, green: 0.32, blue: 0.3) : (urgency == .warning ? Color(red: 1, green: 0.76, blue: 0.3) : .white)
            HStack(spacing: 8) {
                DragGrip().frame(width: 14, height: 30).overlay(grip)
                if t.phase == .idle {
                    Menu {
                        ForEach([1, 5, 10, 15, 20, 30, 45, 60], id: \.self) { minutes in
                            Button("\(minutes) min") { controller.start(.countdown(TimeInterval(minutes * 60))) }
                        }
                        Divider()
                        Button("Stopwatch") { controller.start(.stopwatch) }
                    } label: {
                        Label("Start a timer", systemImage: "timer").font(.system(size: 13, weight: .medium))
                    }
                    .menuStyle(.borderlessButton).fixedSize().tint(.white)
                } else {
                    Text(t.display(at: now))
                        .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(tint)
                        .opacity(t.phase == .paused ? 0.55 : 1)
                    small(t.phase == .running ? "pause.fill" : "play.fill") { t.phase == .running ? controller.pause() : controller.resume() }
                    small("arrow.counterclockwise") { controller.reset() }
                }
                small("xmark") { controller.hide() }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color(red: 0.085, green: 0.085, blue: 0.095), in: Capsule())
            .overlay(Capsule().stroke(urgency == .normal ? Color.white.opacity(0.13) : tint.opacity(0.7), lineWidth: urgency == .normal ? 1 : 1.5))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
            .padding(14)
            .fixedSize()
            .environment(\.colorScheme, .dark)
            .onChange(of: t.phase) { _, _ in controller.contentChanged() }
        }
    }

    private var grip: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) { Circle().frame(width: 2.5, height: 2.5); Circle().frame(width: 2.5, height: 2.5) }
            }
        }
        .foregroundStyle(Color.white.opacity(0.3)).allowsHitTesting(false)
    }

    private func small(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.75))
                .frame(width: 26, height: 26).contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
