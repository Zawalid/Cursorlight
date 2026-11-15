import AppKit
import CursorlightCore
import SwiftUI

/// Proves real mouse events reach the SwiftUI buttons, without touching the screen: with CURSORLIGHT_CLICKTEST=1 it builds the
/// welcome guide far off screen, sends synthetic clicks at its Not now button and checks that the guide finished.
@MainActor
enum ClickSelfTest {
    static var isRequested: Bool { ProcessInfo.processInfo.environment["CURSORLIGHT_CLICKTEST"] == "1" }

    static func run() {
        let suite = "cursorlight.clicktest.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        let coordinator = AppCoordinator(
            cursorSize: CursorSizeController(scaling: SystemCursorScale(), markers: UserDefaultsScaleMarker(defaults: defaults)),
            settings: SettingsStore(defaults: defaults)
        )
        let model = AppModel(coordinator: coordinator, updater: AppUpdater(startingUpdater: false))
        var finished = false
        let size = GuideStep.intro.panelSize
        let window = WindowControllers.makeWindow(size: size, resizable: false)
        let host = FirstClickHostingView(rootView: AnyView(GuideView(autonomous: false, finish: { finished = true }).environmentObject(model)))
        host.sizingOptions = []
        window.contentView = host
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: -9000, y: 100))
        window.orderFront(nil)
        spin(0.9)
        // "Not now" sits left of "Show me": 28 points of shadow margin, then about 50 up to the middle of the button row.
        let point = NSPoint(x: size.width / 2 - 58, y: 78)
        for _ in 0..<3 where !finished {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                if let event = NSEvent.mouseEvent(
                    with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
                ) { window.sendEvent(event) }
                spin(0.05)
            }
            spin(0.3)
        }
        print(finished ? "CLICKTEST PASS: a click on Not now finished the guide" : "CLICKTEST FAIL: the guide did not finish")
        window.close()
        defaults.removePersistentDomain(forName: suite)
    }

    private static func spin(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
