// THROWAWAY SPIKE (Task 0, v2). Objective check: is the real cursor still drawn after each hide attempt?
// Method: warp the pointer to screen centre, capture the display with and without cursor via ScreenCaptureKit,
// count differing pixels in a 80x80 region around the pointer. Diff > 0 means the cursor is drawn.
import AppKit
import ScreenCaptureKit

typealias CGSConnectionID = UInt32
typealias MainConnFn = @convention(c) () -> CGSConnectionID
typealias SetPropFn = @convention(c) (CGSConnectionID, CGSConnectionID, CFString, CFTypeRef) -> Int32
func setsCursorInBackground() -> Int32 {
    guard let h = dlopen(nil, RTLD_NOW), let a = dlsym(h, "CGSMainConnectionID"), let b = dlsym(h, "CGSSetConnectionProperty") else { return -999 }
    let cid = unsafeBitCast(a, to: MainConnFn.self)()
    return unsafeBitCast(b, to: SetPropFn.self)(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
}

func pixels(_ img: CGImage) -> [UInt8] {
    var d = [UInt8](repeating: 0, count: img.width * img.height * 4)
    let ctx = CGContext(data: &d, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: img.width * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    return d
}

func cursorDiff(display: SCDisplay, scale: CGFloat, at p: CGPoint) async -> Int {
    func shot(_ cursor: Bool) async -> CGImage? {
        let cfg = SCStreamConfiguration()
        cfg.width = Int(CGFloat(display.width) * scale); cfg.height = Int(CGFloat(display.height) * scale)
        cfg.showsCursor = cursor
        return try? await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: []), configuration: cfg)
    }
    guard let a = await shot(true), let b = await shot(false) else { return -1 }
    let pa = pixels(a), pb = pixels(b)
    let cx = Int(p.x * scale), cy = Int(p.y * scale), r = Int(80 * scale / 2)
    var diff = 0
    for y in max(0, cy - r)..<min(a.height, cy + r) {
        for x in max(0, cx - r)..<min(a.width, cx + r) {
            let i = (y * a.width + x) * 4
            if abs(Int(pa[i]) - Int(pb[i])) + abs(Int(pa[i+1]) - Int(pb[i+1])) + abs(Int(pa[i+2]) - Int(pb[i+2])) > 30 { diff += 1 }
        }
    }
    return diff
}


let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "main"
if mode == "hold" {
    _ = setsCursorInBackground(); CGDisplayHideCursor(CGMainDisplayID())
    sleep(60); exit(0)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in
    guard let screen = NSScreen.main, let content = try? await SCShareableContent.current, let display = content.displays.first else { exit(1) }
    let scale = screen.backingScaleFactor
    let pt = CGPoint(x: screen.frame.midX, y: screen.frame.height / 2)
    CGWarpMouseCursorPosition(pt); try? await Task.sleep(nanoseconds: 500_000_000)
    print("RESULT T0 baseline diff: \(await cursorDiff(display: display, scale: scale, at: pt))")
    // Test 1: hide once, then show repeatedly and watch when it returns.
    _ = setsCursorInBackground(); CGDisplayHideCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 500_000_000)
    print("RESULT T1 after hide: diff \(await cursorDiff(display: display, scale: scale, at: pt))")
    for i in 1...4 {
        CGDisplayShowCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 600_000_000)
        print("RESULT T1 after show #\(i): diff \(await cursorDiff(display: display, scale: scale, at: pt))")
    }
    // Test 2: another process hides, then is killed with SIGKILL.
    let child = Process(); child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]); child.arguments = ["hold"]
    try? child.run(); try? await Task.sleep(nanoseconds: 1_000_000_000)
    print("RESULT T2 child holding hide: diff \(await cursorDiff(display: display, scale: scale, at: pt))")
    kill(child.processIdentifier, SIGKILL); try? await Task.sleep(nanoseconds: 1_000_000_000)
    print("RESULT T2 after kill -9 of child: diff \(await cursorDiff(display: display, scale: scale, at: pt))  (expect > 0 if the system restores it)")
    exit(0)
}
app.run()
