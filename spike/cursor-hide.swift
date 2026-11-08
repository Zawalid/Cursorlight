// THROWAWAY SPIKE (Task 0). Not product code. Tests ways to hide the real cursor while another app is frontmost.
import AppKit
import CoreGraphics

typealias CGSConnectionID = UInt32
typealias MainConnFn = @convention(c) () -> CGSConnectionID
typealias SetPropFn = @convention(c) (CGSConnectionID, CGSConnectionID, CFString, CFTypeRef) -> Int32

func privateHide() -> String {
    guard let h = dlopen(nil, RTLD_NOW),
          let a = dlsym(h, "CGSMainConnectionID"), let b = dlsym(h, "CGSSetConnectionProperty") else { return "private symbols missing" }
    let mainConn = unsafeBitCast(a, to: MainConnFn.self)
    let setProp = unsafeBitCast(b, to: SetPropFn.self)
    let cid = mainConn()
    let r = setProp(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    return "SetsCursorInBackground rc=\(r)"
}

final class Dot: NSView {
    override func draw(_ r: NSRect) { NSColor.red.setFill(); NSBezierPath(ovalIn: bounds).fill() }
}

var lags: [Double] = []
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let dotWin = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 24, height: 24), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
dotWin.isOpaque = false; dotWin.backgroundColor = .clear; dotWin.ignoresMouseEvents = true
dotWin.level = .screenSaver; dotWin.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
dotWin.contentView = Dot(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
dotWin.orderFrontRegardless()

func place() {
    let p = NSEvent.mouseLocation
    dotWin.setFrameOrigin(NSPoint(x: p.x - 12, y: p.y - 12))
}
NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { e in
    place()
    lags.append((ProcessInfo.processInfo.systemUptime - e.timestamp) * 1000)
}

typealias VisFn = @convention(c) () -> UInt32
let visFn: VisFn? = {
    guard let h = dlopen(nil, RTLD_NOW) else { return nil }
    for name in ["CGCursorIsVisible", "CGSCursorIsVisible"] {
        if let s = dlsym(h, name) { return unsafeBitCast(s, to: VisFn.self) }
    }
    return nil
}()
func visible() -> Bool { (visFn?() ?? 99) != 0 }

func kindName() -> String {
    guard let c = NSCursor.currentSystem else { return "nil" }
    if c == NSCursor.arrow { return "arrow" }
    if c == NSCursor.pointingHand { return "hand" }
    if c == NSCursor.iBeam { return "ibeam" }
    return "other(hotspot \(c.hotSpot))"
}

func frontName() -> String { NSWorkspace.shared.frontmostApplication?.localizedName ?? "?" }

Task { @MainActor in
    // Make another app frontmost.
    if let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
        finder.activate()
    }
    try? await Task.sleep(nanoseconds: 1_500_000_000)
    print("RESULT frontmost app: \(frontName()), cursor visible at start: \(visible())")
    print("RESULT cursor kind now: \(kindName())")

    // Candidate (b): NSCursor.hide() from a background app.
    NSCursor.hide(); try? await Task.sleep(nanoseconds: 500_000_000)
    print("RESULT (b) NSCursor.hide while \(frontName()) front: CGCursorIsVisible=\(visible())")
    NSCursor.unhide(); try? await Task.sleep(nanoseconds: 300_000_000)

    // Candidate (a): CGDisplayHideCursor alone.
    CGDisplayHideCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 500_000_000)
    print("RESULT (a1) CGDisplayHideCursor alone while \(frontName()) front: CGCursorIsVisible=\(visible())")
    CGDisplayShowCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 300_000_000)

    // Candidate (a2): private SetsCursorInBackground, then CGDisplayHideCursor.
    print("RESULT (a2) private: \(privateHide())")
    CGDisplayHideCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 500_000_000)
    print("RESULT (a2) CGDisplayHideCursor after private property: CGCursorIsVisible=\(visible())")

    // Leave the cursor hidden for 8 s: user moves the mouse over text, links, desktop; dot should follow.
    print("RESULT MOVE THE MOUSE NOW for 8 seconds (over a link or text if you can). The red dot should follow and the real cursor should be gone.")
    lags.removeAll()
    for _ in 0..<8 {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        print("RESULT   kind=\(kindName()) front=\(frontName())")
    }
    CGDisplayShowCursor(CGMainDisplayID())
    NSCursor.unhide()
    let sorted = lags.sorted()
    if sorted.isEmpty { print("RESULT lag: no mouse events (did you move the mouse?)") }
    else {
        let p50 = sorted[sorted.count / 2], p95 = sorted[Int(Double(sorted.count) * 0.95)]
        print("RESULT lag handler-vs-event ms: n=\(sorted.count) p50=\(String(format: "%.1f", p50)) p95=\(String(format: "%.1f", p95)) max=\(String(format: "%.1f", sorted.last ?? 0))")
    }
    print("RESULT restored: CGCursorIsVisible=\(visible())")
    exit(0)
}
app.run()
