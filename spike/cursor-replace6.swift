// THROWAWAY SPIKE (Task 0b). Not product code.
// Question: can we replace the REAL system arrow cursor image (no hiding, no overlay) and restore it afterwards?
// Function names were found by listing SkyLight's own exports on this Mac (dyld_info -exports).
// Signatures follow the public CGSInternal header layout (MIT); everything here is our own code.
// Safety: the original arrow is read first and re-registered on exit, on SIGINT and on SIGTERM.
// If anything goes wrong the cursor returns to normal after logging out and in.
import AppKit

typealias CID = Int32
typealias MainConnFn = @convention(c) () -> CID
typealias NameForIDFn = @convention(c) (Int32) -> UnsafePointer<CChar>?
typealias CopyImagesFn = @convention(c) (CID, UnsafePointer<CChar>, UnsafeMutablePointer<CGSize>, UnsafeMutablePointer<CGPoint>,
                                         UnsafeMutablePointer<UInt>, UnsafeMutablePointer<CGFloat>,
                                         UnsafeMutablePointer<Unmanaged<CFArray>?>) -> Int32
typealias RegisterImagesFn = @convention(c) (CID, UnsafePointer<CChar>, Bool, Bool, UInt, CFArray, CGSize, CGPoint,
                                             UnsafeMutablePointer<Int>, CGRect, CGFloat, Int) -> Int32

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
guard let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else { print("RESULT no SkyLight"); exit(1) }
func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(sky, n).map { unsafeBitCast($0, to: t) } }
guard let mainConn = sym("SLSMainConnectionID", MainConnFn.self),
      let nameFor = sym("SLSCursorNameForSystemCursor", NameForIDFn.self),
      let copyImages = sym("SLSCopyRegisteredCursorImages", CopyImagesFn.self),
      let registerImages = sym("SLSRegisterCursorWithImages", RegisterImagesFn.self) else { print("RESULT missing symbols"); exit(1) }
typealias RemoveFn = @convention(c) (CID, UnsafePointer<CChar>, Bool) -> Int32
let removeFn = sym("SLSRemoveRegisteredCursor", RemoveFn.self)
typealias SeedFn = @convention(c) () -> Int32
typealias SetSysFn = @convention(c) (CID, Int32) -> Int32
let seedFn = sym("SLSCurrentCursorSeed", SeedFn.self)
let setSys = sym("SLSSetSystemDefinedCursor", SetSysFn.self)
let cid = mainConn()
print("RESULT connection id=\(cid) seed before=\(seedFn?() ?? -1)")

print("RESULT system cursor names by id:")
for i in 0..<16 { if let p = nameFor(Int32(i)) { print("RESULT   id \(i) = \(String(cString: p))") } }

let arrowName = "com.apple.coregraphics.Arrow"
var size = CGSize.zero, hot = CGPoint.zero, frames: UInt = 0, dur: CGFloat = 0
var arr: Unmanaged<CFArray>? = nil
let rc = arrowName.withCString { copyImages(cid, $0, &size, &hot, &frames, &dur, &arr) }
print("RESULT copy original arrow: rc=\(rc) size=\(size) hotspot=\(hot) frames=\(frames) duration=\(dur) images=\(arr.map { CFArrayGetCount($0.takeUnretainedValue()) } ?? -1)")
guard rc == 0, let original = arr?.takeRetainedValue() else { print("RESULT cannot read the original arrow; stopping without changes"); exit(1) }

func restore() {
    var seed = 0
    let r = arrowName.withCString { registerImages(cid, $0, true, true, frames, original, size, hot, &seed, CGRect(origin: .zero, size: size), dur, 0) }
    print("RESULT restored original arrow rc=\(r)")
}
signal(SIGINT, SIG_IGN); signal(SIGTERM, SIG_IGN)
let s1 = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main); s1.setEventHandler { restore(); exit(0) }; s1.resume()
let s2 = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main); s2.setEventHandler { restore(); exit(0) }; s2.resume()


// A clean pointer: violet arrow with white outline and a soft shadow, hotspot at the tip.
func arrowImage(points: CGFloat, scale: CGFloat) -> CGImage? {
    let px = Int(points * scale)
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: 0, y: points); ctx.scaleBy(x: 1, y: -1)
    let o = CGPoint(x: 4, y: 3)
    let path = CGMutablePath()
    path.move(to: o)
    path.addLine(to: CGPoint(x: o.x, y: o.y + 22))
    path.addLine(to: CGPoint(x: o.x + 5.5, y: o.y + 17))
    path.addLine(to: CGPoint(x: o.x + 9.5, y: o.y + 25))
    path.addLine(to: CGPoint(x: o.x + 13, y: o.y + 23.5))
    path.addLine(to: CGPoint(x: o.x + 9, y: o.y + 15.5))
    path.addLine(to: CGPoint(x: o.x + 15.5, y: o.y + 15.5))
    path.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 3, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
    ctx.addPath(path); ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.translateBy(x: 1.1, y: 1.6); ctx.scaleBy(x: 0.9, y: 0.9)
    ctx.addPath(path); ctx.setFillColor(CGColor(red: 0.45, green: 0.3, blue: 1, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()
    return ctx.makeImage()
}
let pts: CGFloat = 32
let imgs = [1, 2, 3, 4].compactMap { arrowImage(points: pts, scale: CGFloat($0)) }
typealias SetPropFn = @convention(c) (CID, CID, CFString, CFTypeRef) -> Int32
typealias SetRegFn = @convention(c) (CID, UnsafePointer<CChar>, UnsafeMutablePointer<Int>?) -> Int32
let setProp = dlsym(dlopen(nil, RTLD_NOW), "CGSSetConnectionProperty").map { unsafeBitCast($0, to: SetPropFn.self) }
let setReg = sym("SLSSetRegisteredCursor", SetRegFn.self)
print("RESULT SetsCursorInBackground rc=\(setProp?(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue) ?? -999)")
let name = "com.beacon.spike.arrow"
var seed = 0
let r2 = name.withCString { registerImages(cid, $0, true, true, 1, imgs as CFArray, CGSize(width: pts, height: pts), CGPoint(x: 4, y: 3), &seed, CGRect(x: 0, y: 0, width: pts, height: pts), 0, 0) }
print("RESULT register rc=\(r2) images=\(imgs.count)")

var applies = 0
let lock = NSLock()
func apply() { var sd = 0; lock.lock(); _ = name.withCString { setReg?(cid, $0, &sd) }; applies += 1; lock.unlock() }
apply()
var ours = seedFn?() ?? 0
// Fast watcher: re-apply the instant anyone else changes the cursor.
let watcher = Thread {
    while true {
        let now = seedFn?() ?? 0
        if now != ours { apply(); ours = seedFn?() ?? now }
        usleep(400)
    }
}
watcher.qualityOfService = .userInteractive
watcher.start()
NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]) { _ in apply(); ours = seedFn?() ?? ours }
typealias DockFn = @convention(c) (CID, Bool) -> Int32
if let dock = sym("SLSSetDockCursorOverride", DockFn.self) { print("RESULT SetDockCursorOverride(true) rc=\(dock(cid, true))") }
print("RESULT seed watcher at 0.4 ms plus mouse events. Hover the Dock too. Auto-exit in 60 s.")
DispatchQueue.main.asyncAfter(deadline: .now() + 60) { print("RESULT applies=\(applies)"); restore(); exit(0) }
app.run()
