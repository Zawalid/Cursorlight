import AppKit
import CursorlightCore
import SwiftUI

/// Proves real mouse events reach the SwiftUI buttons, without touching the screen: with CURSORLIGHT_CLICKTEST=1 it builds the
/// welcome window far off screen, sends one synthetic click per step at the Continue button and checks that the guide finished.
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
        let size = NSSize(width: FirstRunView.size.width, height: FirstRunView.size.height)
        let window = WindowControllers.makeWindow(size: size, resizable: false)
        window.contentView = FirstClickHostingView(rootView: AnyView(FirstRunView { finished = true }.environmentObject(model)))
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: -9000, y: 100))
        window.orderFront(nil)
        spin(0.6)
        // Continue sits in the bottom right: 44 points from the right edge, 30 from the bottom, about 40 high.
        let point = NSPoint(x: size.width - 44 - 40, y: 30 + 20)
        for _ in 0..<FirstRunView.stepCount {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                if let event = NSEvent.mouseEvent(
                    with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
                ) { window.sendEvent(event) }
                spin(0.05)
            }
            spin(0.8)
        }
        print(finished ? "CLICKTEST PASS: one click per step on Continue finished the guide" : "CLICKTEST FAIL: the guide did not finish")
        window.close()
        defaults.removePersistentDomain(forName: suite)
    }

    private static func spin(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
