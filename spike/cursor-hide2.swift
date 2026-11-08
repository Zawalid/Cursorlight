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

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

Task { @MainActor in
    guard let screen = NSScreen.main, let content = try? await SCShareableContent.current,
          let display = content.displays.first else { print("RESULT error: no display"); exit(1) }
    let scale = screen.backingScaleFactor
    let pt = CGPoint(x: screen.frame.midX, y: screen.frame.height / 2)  // CG coords (top-left origin)
    if let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) { finder.activate() }
    try? await Task.sleep(nanoseconds: 1_200_000_000)
    CGWarpMouseCursorPosition(pt); try? await Task.sleep(nanoseconds: 600_000_000)
    print("RESULT frontmost: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
    print("RESULT baseline cursor-pixel diff (expect > 0): \(await cursorDiff(display: display, scale: scale, at: pt))")

    NSCursor.hide(); try? await Task.sleep(nanoseconds: 500_000_000)
    print("RESULT (b) NSCursor.hide: diff = \(await cursorDiff(display: display, scale: scale, at: pt))  (0 means hidden)")
    NSCursor.unhide(); try? await Task.sleep(nanoseconds: 300_000_000)

    CGDisplayHideCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 500_000_000)
    print("RESULT (a1) CGDisplayHideCursor: diff = \(await cursorDiff(display: display, scale: scale, at: pt))")
    CGDisplayShowCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 300_000_000)

    let rc = setsCursorInBackground()
    CGDisplayHideCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 500_000_000)
    print("RESULT (a2) SetsCursorInBackground rc=\(rc) + CGDisplayHideCursor: diff = \(await cursorDiff(display: display, scale: scale, at: pt))")
    CGDisplayShowCursor(CGMainDisplayID()); try? await Task.sleep(nanoseconds: 300_000_000)
    print("RESULT after restore: diff = \(await cursorDiff(display: display, scale: scale, at: pt))  (expect > 0)")

    // Cursor kind detection by image bytes.
    func tiff(_ c: NSCursor) -> Int { c.image.tiffRepresentation?.count ?? -1 }
    let cur = NSCursor.currentSystem
    print("RESULT kind: currentSystem tiffBytes=\(cur.map(tiff) ?? -1) hotspot=\(cur?.hotSpot ?? .zero); arrow=\(tiff(.arrow)) hand=\(tiff(.pointingHand)) ibeam=\(tiff(.iBeam))")
    exit(0)
}
app.run()
