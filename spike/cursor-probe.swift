// THROWAWAY SPIKE. Reads the current cursor's size and hotspot from the window server over different targets.
import AppKit

typealias CID = Int32
typealias ConnFn = @convention(c) () -> CID
typealias SizeFn = @convention(c) (CID, UnsafeMutablePointer<Int32>) -> Int32
typealias DataFn = @convention(c) (CID, UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<CGRect>, UnsafeMutablePointer<CGPoint>, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
typealias SeedFn = @convention(c) () -> Int32

let app = NSApplication.shared
app.setActivationPolicy(.regular)
guard let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else { print("RESULT no SkyLight"); exit(1) }
func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(sky, n).map { unsafeBitCast($0, to: t) } }
guard let conn = sym("SLSMainConnectionID", ConnFn.self), let sizeFn = sym("SLSGetGlobalCursorDataSize", SizeFn.self),
      let dataFn = sym("SLSGetGlobalCursorData", DataFn.self), let seedFn = sym("SLSCurrentCursorSeed", SeedFn.self) else { print("RESULT missing symbols"); exit(1) }
let cid = conn()

final class HandView: NSView {
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}
let win = NSWindow(contentRect: NSRect(x: 200, y: 400, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
win.title = "probe"
let text = NSTextView(frame: NSRect(x: 0, y: 150, width: 500, height: 150)); text.string = "hello world"; text.isEditable = true
let hand = HandView(frame: NSRect(x: 0, y: 0, width: 500, height: 150))
win.contentView?.addSubview(text); win.contentView?.addSubview(hand)
win.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)

func snapshot(_ label: String) {
    var n: Int32 = 0
    let rs = sizeFn(cid, &n)
    var buf = [UInt8](repeating: 0, count: max(Int(n), 1))
    var len = n, rowBytes: Int32 = 0, depth: Int32 = 0, comps: Int32 = 0, bpc: Int32 = 0
    var rect = CGRect.zero, hot = CGPoint.zero
    let rd = dataFn(cid, &buf, &len, &rowBytes, &rect, &hot, &depth, &comps, &bpc)
    let nonzero = buf.reduce(0) { $0 + ($1 != 0 ? 1 : 0) }
    print("RESULT \(label): sizeRC=\(rs) bytes=\(n) dataRC=\(rd) rect=\(rect) hotspot=\(hot) rowBytes=\(rowBytes) depth=\(depth) comps=\(comps) bpc=\(bpc) nonzero=\(nonzero) seed=\(seedFn())")
}
func warp(_ p: CGPoint) { CGWarpMouseCursorPosition(p); CGAssociateMouseAndMouseCursorPosition(1) }
let f = win.frame
let screenH = NSScreen.screens[0].frame.height
func top(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: screenH - p.y) }
let steps: [(String, CGPoint)] = [
    ("desktop-arrow", top(CGPoint(x: 1100, y: 700))),
    ("text-ibeam", top(CGPoint(x: f.minX + 250, y: f.minY + 120))),
    ("hand", top(CGPoint(x: f.minX + 250, y: f.minY + 40))),
    ("desktop-arrow-again", top(CGPoint(x: 1100, y: 720))),
]
var i = 0
Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { t in
    if i >= steps.count { print("RESULT done"); exit(0) }
    warp(steps[i].1)
    // a small nudge so tracking areas and cursor rects update
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let p = steps[i].1; warp(CGPoint(x: p.x + 2, y: p.y + 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { snapshot(steps[i].0); i += 1 }
    }
}
app.run()
