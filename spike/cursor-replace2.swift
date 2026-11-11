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

// A large, unmistakable test cursor: red ring with white outline and a black centre dot, drawn at 2x.
func testImage(points: CGFloat, scale: CGFloat) -> CGImage? {
    let px = Int(points * scale)
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.scaleBy(x: scale, y: scale)
    let c = CGPoint(x: points / 2, y: points / 2)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.setLineWidth(9)
    ctx.strokeEllipse(in: CGRect(x: c.x - 18, y: c.y - 18, width: 36, height: 36))
    ctx.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx.setLineWidth(5)
    ctx.strokeEllipse(in: CGRect(x: c.x - 18, y: c.y - 18, width: 36, height: 36))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6))
    return ctx.makeImage()
}
let pts: CGFloat = 48
guard let img = testImage(points: pts, scale: 2) else { print("RESULT cannot draw test image"); exit(1) }
let testArr = [img] as CFArray
var seed = 0
let r2 = arrowName.withCString { registerImages(cid, $0, true, true, 1, testArr, CGSize(width: pts, height: pts), CGPoint(x: pts / 2, y: pts / 2), &seed, CGRect(x: 0, y: 0, width: pts, height: pts), 0, 0) }
var s3 = CGSize.zero, h3 = CGPoint.zero, f3: UInt = 0, d3: CGFloat = 0
var a3: Unmanaged<CFArray>? = nil
let rc3 = arrowName.withCString { copyImages(cid, $0, &s3, &h3, &f3, &d3, &a3) }
print("RESULT READ-BACK after register: rc=\(rc3) size=\(s3) hotspot=\(h3) images=\(a3.map { CFArrayGetCount($0.takeUnretainedValue()) } ?? -1) (original was size=(28.0, 40.0) images=4) seed now=\(seedFn?() ?? -1)")
let kick = setSys?(cid, 0) ?? -1
print("RESULT SetSystemDefinedCursor(arrow) rc=\(kick) seed now=\(seedFn?() ?? -1)")
print("RESULT registered test arrow rc=\(r2) seed=\(seed). LOOK AT YOUR CURSOR NOW (move over desktop, a Finder window, a link). Restoring in 12 s.")

DispatchQueue.main.asyncAfter(deadline: .now() + 12) { restore(); exit(0) }
app.run()
