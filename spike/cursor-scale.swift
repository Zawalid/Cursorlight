// THROWAWAY SPIKE (Task 0c). Does the system cursor SCALE call work? Reads, sets 3x for 8 s, reads back, restores.
import AppKit
typealias CID = Int32
typealias MainConnFn = @convention(c) () -> CID
typealias GetScaleFn = @convention(c) (CID, UnsafeMutablePointer<Float>) -> Int32
typealias SetScaleFn = @convention(c) (CID, Float) -> Int32
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
guard let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
      let a = dlsym(sky, "SLSMainConnectionID"), let g = dlsym(sky, "SLSGetCursorScale"), let s = dlsym(sky, "SLSSetCursorScale") else { print("RESULT missing symbols"); exit(1) }
let cid = unsafeBitCast(a, to: MainConnFn.self)()
let getScale = unsafeBitCast(g, to: GetScaleFn.self), setScale = unsafeBitCast(s, to: SetScaleFn.self)
var original: Float = 0
let r0 = getScale(cid, &original)
print("RESULT get scale rc=\(r0) value=\(original)")
guard r0 == 0, original > 0 else { print("RESULT cannot read scale; no changes made"); exit(1) }
func restore() { print("RESULT restore rc=\(setScale(cid, original))"); var v: Float = 0; _ = getScale(cid, &v); print("RESULT scale after restore=\(v)") }
signal(SIGINT, SIG_IGN); signal(SIGTERM, SIG_IGN)
let s1 = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main); s1.setEventHandler { restore(); exit(0) }; s1.resume()
let s2 = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main); s2.setEventHandler { restore(); exit(0) }; s2.resume()
let r1 = setScale(cid, 3.0)
var after: Float = 0; _ = getScale(cid, &after)
print("RESULT set 3.0 rc=\(r1), read back=\(after). LOOK AT YOUR CURSOR (should be about 3x bigger) for 8 s")
DispatchQueue.main.asyncAfter(deadline: .now() + 8) { restore(); exit(0) }
app.run()
