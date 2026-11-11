import Foundation

// The only place in Beacon that touches private API. Everything outside this folder talks to `CursorScaling`.

/// Reads and sets the system cursor scale (the Accessibility "cursor size" factor, 1.0 is normal).
public protocol CursorScaling {
    /// The current scale, or nil when it cannot be read.
    func currentScale() -> Float?
    /// Sets the scale. Returns false when the system refused or the call is unavailable.
    func setScale(_ value: Float) -> Bool
}

/// SkyLight implementation. Symbols are resolved at runtime; when any is missing every call soft-fails.
/// The process must be a normal NSApplication process for the window server connection to be valid.
public final class SystemCursorScale: CursorScaling {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias GetScaleFn = @convention(c) (Int32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetScaleFn = @convention(c) (Int32, Float) -> Int32

    private let mainConnection: MainConnectionFn?
    private let getScale: GetScaleFn?
    private let setScaleFn: SetScaleFn?

    public init() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let handle = dlopen(path, RTLD_NOW),
              let connection = dlsym(handle, "SLSMainConnectionID"),
              let getter = dlsym(handle, "SLSGetCursorScale"),
              let setter = dlsym(handle, "SLSSetCursorScale")
        else {
            mainConnection = nil
            getScale = nil
            setScaleFn = nil
            return
        }
        mainConnection = unsafeBitCast(connection, to: MainConnectionFn.self)
        getScale = unsafeBitCast(getter, to: GetScaleFn.self)
        setScaleFn = unsafeBitCast(setter, to: SetScaleFn.self)
    }

    public func currentScale() -> Float? {
        guard let mainConnection, let getScale else { return nil }
        var value: Float = 0
        let result = getScale(mainConnection(), &value)
        guard result == 0, value > 0 else { return nil }
        return value
    }

    public func setScale(_ value: Float) -> Bool {
        guard let mainConnection, let setScaleFn else { return false }
        return setScaleFn(mainConnection(), value) == 0
    }
}
