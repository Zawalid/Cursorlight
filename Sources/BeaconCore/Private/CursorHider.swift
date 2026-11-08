import AppKit
import os

// The only place in Beacon that touches private API. Everything outside this folder talks to `CursorHider`.

/// Hides and restores the system cursor so a skin can be drawn in its place.
public protocol CursorHider: AnyObject, Sendable {
    /// True only while this hider really has the system cursor hidden. When false after `hide()`, the
    /// renderer draws the skin beside the real cursor instead of on top of it.
    var isHidden: Bool { get }
    /// Hides the system cursor. Calling it again while hidden does nothing.
    func hide()
    /// Shows the system cursor again. Idempotent; safe from any thread and from deinit.
    func restore()
}

/// Persisted `cursorHidden` marker: set while the cursor is hidden, so a relaunch after a crash can restore it.
public protocol CursorHiddenMarkerStore: AnyObject, Sendable {
    var isCursorHidden: Bool { get set }
}

public final class UserDefaultsCursorMarker: CursorHiddenMarkerStore {
    public static let key = "cursorHidden"
    /// nil means the standard defaults. A suite name rather than a `UserDefaults` instance keeps this `Sendable`.
    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    public var isCursorHidden: Bool {
        get { defaults.bool(forKey: Self.key) }
        set {
            if newValue {
                defaults.set(true, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}

/// The raw system operations behind `SystemCursorHider` (injectable for tests).
public protocol CursorVisibilityBackend: Sendable {
    /// Lets this background process change cursor visibility. Must succeed before any hide.
    func allowBackgroundCursorControl() -> Bool
    func hideCursor()
    func showCursor()
}

/// Hides the cursor with the Task 0 mechanism and keeps every hide paired with exactly one show.
public final class SystemCursorHider: CursorHider {
    private let backend: CursorVisibilityBackend
    private let markers: CursorHiddenMarkerStore
    /// Number of system hides this process owns and has not yet shown. Never above 1.
    private let hideCount = OSAllocatedUnfairLock(initialState: 0)

    public init(backend: CursorVisibilityBackend, markers: CursorHiddenMarkerStore) {
        self.backend = backend
        self.markers = markers
    }

    public var isHidden: Bool { hideCount.withLock { $0 > 0 } }

    public func hide() {
        hideCount.withLock { count in
            guard count == 0 else { return }
            // Never hide without the property: an unbalanced hide survived a show in the spike.
            guard backend.allowBackgroundCursorControl() else { return }
            // Marker first, so a crash between the two calls errs on the side of a relaunch restore.
            markers.isCursorHidden = true
            backend.hideCursor()
            count += 1
        }
    }

    public func restore() {
        hideCount.withLock { count in
            // Only show what this process hid. A stale marker from a dead process needs no show: the system
            // restores a dead process's hide, and an extra show would unbalance the count.
            while count > 0 {
                backend.showCursor()
                count -= 1
            }
            markers.isCursorHidden = false
        }
    }
}

/// Public fallback when the private symbols are missing: the real cursor stays, and the skin is drawn beside it.
public final class FallbackCursorHider: CursorHider {
    public init() {}
    public var isHidden: Bool { false }
    public func hide() {}
    public func restore() {}
}

public enum CursorRecovery {
    /// Call first thing at launch. If a previous run left the `cursorHidden` marker set, restores and clears it.
    @discardableResult
    public static func restoreIfStale(markers: CursorHiddenMarkerStore, hider: CursorHider) -> Bool {
        guard markers.isCursorHidden else { return false }
        hider.restore()
        markers.isCursorHidden = false
        return true
    }
}

public enum CursorHiders {
    /// The private-API hider when its symbols resolve, otherwise the public fallback.
    public static func makeDefault(markers: CursorHiddenMarkerStore = UserDefaultsCursorMarker()) -> CursorHider {
        guard let backend = WindowServerCursorBackend() else { return FallbackCursorHider() }
        return SystemCursorHider(backend: backend, markers: markers)
    }
}

/// Private WindowServer mechanism verified in the Task 0 spike: set `SetsCursorInBackground` on the main
/// connection, then `CGDisplayHideCursor`. Symbols are looked up at runtime so a missing symbol means fallback,
/// never a crash.
struct WindowServerCursorBackend: CursorVisibilityBackend {
    private typealias MainConnectionFunction = @convention(c) () -> UInt32
    private typealias SetConnectionPropertyFunction = @convention(c) (UInt32, UInt32, CFString, CFTypeRef) -> Int32

    private let mainConnection: MainConnectionFunction
    private let setConnectionProperty: SetConnectionPropertyFunction

    init?() {
        guard let handle = dlopen(nil, RTLD_NOW),
              let mainSymbol = dlsym(handle, "CGSMainConnectionID"),
              let setSymbol = dlsym(handle, "CGSSetConnectionProperty")
        else { return nil }
        mainConnection = unsafeBitCast(mainSymbol, to: MainConnectionFunction.self)
        setConnectionProperty = unsafeBitCast(setSymbol, to: SetConnectionPropertyFunction.self)
    }

    func allowBackgroundCursorControl() -> Bool {
        let connection = mainConnection()
        return setConnectionProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue) == 0
    }

    func hideCursor() {
        CGDisplayHideCursor(CGMainDisplayID())
    }

    func showCursor() {
        CGDisplayShowCursor(CGMainDisplayID())
    }
}
