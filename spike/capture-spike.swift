// THROWAWAY SPIKE. Not product code. Answers one question:
// does a separate overlay window show up in (A) a full-display capture, (B) a single-window capture,
// (C) a single-window capture when the overlay is attached as a child window of the shared window?
// Uses ScreenCaptureKit, the same engine conferencing apps use for screen and window share.
import AppKit
import ScreenCaptureKit

final class RingView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()
        NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setStroke()
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: 10, dy: 10))
        path.lineWidth = 16
        path.stroke()
    }
}

func redPixels(_ image: CGImage) -> Int {
    let w = image.width, h = image.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return -1 }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var count = 0
    var i = 0
    while i < data.count {
        if data[i] > 200 && data[i + 1] < 70 && data[i + 2] < 70 { count += 1 }
        i += 4
    }
    return count
}

func save(_ image: CGImage, _ name: String) {
    let url = URL(fileURLWithPath: "~/Personal/Projects/Beacon/spike/\(name).png")
    let rep = NSBitmapImageRep(cgImage: image)
    if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: url) }
}

@MainActor
func run() async {
    let screen = NSScreen.main ?? NSScreen.screens[0]
    let center = NSPoint(x: screen.frame.midX, y: screen.frame.midY)

    // The window that stands in for "the app being shared": solid blue.
    let target = NSWindow(contentRect: NSRect(x: center.x - 300, y: center.y - 200, width: 600, height: 400),
                          styleMask: [.titled], backing: .buffered, defer: false)
    target.title = "BeaconSpikeTarget"
    target.backgroundColor = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
    target.makeKeyAndOrderFront(nil)

    // The overlay: a transparent click-through panel with a red ring, like a cursor halo.
    let overlay = NSPanel(contentRect: NSRect(x: center.x - 100, y: center.y - 100, width: 200, height: 200),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    overlay.isOpaque = false
    overlay.backgroundColor = .clear
    overlay.hasShadow = false
    overlay.ignoresMouseEvents = true
    overlay.level = .screenSaver
    overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    overlay.contentView = RingView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
    overlay.orderFrontRegardless()

    try? await Task.sleep(nanoseconds: 1_000_000_000)

    do {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == (screen.deviceDescriptionDisplayID ?? 0) }) ?? content.displays.first else {
            print("RESULT error: no display"); return
        }
        let scale = screen.backingScaleFactor

        func capture(label: String, filter: SCContentFilter, width: Int, height: Int) async {
            let cfg = SCStreamConfiguration()
            cfg.width = width
            cfg.height = height
            cfg.showsCursor = false
            do {
                let img = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
                save(img, label)
                print("RESULT \(label): \(img.width)x\(img.height) red pixels = \(redPixels(img))")
            } catch {
                print("RESULT \(label): capture failed: \(error.localizedDescription)")
            }
        }

        await capture(label: "A-display", filter: SCContentFilter(display: display, excludingWindows: []),
                      width: Int(CGFloat(display.width) * scale), height: Int(CGFloat(display.height) * scale))

        func shareableTarget() async -> SCWindow? {
            let c = try? await SCShareableContent.current
            return c?.windows.first(where: { $0.windowID == CGWindowID(target.windowNumber) })
        }

        if let scTarget = await shareableTarget() {
            await capture(label: "B-window-separate-overlay", filter: SCContentFilter(desktopIndependentWindow: scTarget),
                          width: Int(scTarget.frame.width * scale), height: Int(scTarget.frame.height * scale))
        } else { print("RESULT B: target window not found in shareable content") }

        // Variant C: attach the overlay to the shared window as a child window.
        target.addChildWindow(overlay, ordered: .above)
        try? await Task.sleep(nanoseconds: 800_000_000)
        if let scTarget = await shareableTarget() {
            await capture(label: "C-window-child-overlay", filter: SCContentFilter(desktopIndependentWindow: scTarget),
                          width: Int(scTarget.frame.width * scale), height: Int(scTarget.frame.height * scale))
        } else { print("RESULT C: target window not found in shareable content") }
    } catch {
        print("RESULT error: \(error.localizedDescription)")
    }
}

extension NSScreen {
    var deviceDescriptionDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in
    await run()
    exit(0)
}
app.run()
