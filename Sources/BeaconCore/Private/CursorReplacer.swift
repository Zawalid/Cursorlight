import AppKit
import Foundation

// Private API, isolated here like SystemCursorScale. Everything outside this folder talks to `CursorReplacing`.

/// Shows a custom image as the real system pointer, everywhere.
@MainActor
public protocol CursorReplacing: AnyObject {
    /// False when this Mac cannot replace the pointer; the skin picker then says so.
    var isAvailable: Bool { get }
    /// Shows the pointer. Returns false when the system refused.
    func show(_ skin: CursorSkinImage) -> Bool
    /// Gives the pointer back to the system.
    func clear()
}

/// Used when SkyLight cannot be loaded: nothing changes and the picker is disabled.
@MainActor
public final class UnavailableCursorReplacer: CursorReplacing {
    public init() {}
    public var isAvailable: Bool { false }
    public func show(_ skin: CursorSkinImage) -> Bool { false }
    public func clear() {}
}

/// SkyLight implementation. The cursor is registered under Beacon's own name and set as the current cursor. The window
/// server resets the cursor when the pointer crosses windows, so a fast thread watches the cursor seed and sets it again
/// the instant anything else changes it. Nothing system-owned is overwritten: stopping returns the pointer to normal,
/// and a crash leaves at most the custom pointer until the next mouse move into any window.
@MainActor
public final class SkyLightCursorReplacer: CursorReplacing {
    private typealias ConnFn = @convention(c) () -> Int32
    private typealias RegisterFn = @convention(c) (
        Int32, UnsafePointer<CChar>, Bool, Bool, UInt, CFArray, CGSize, CGPoint,
        UnsafeMutablePointer<Int>, CGRect, CGFloat, Int
    ) -> Int32
    private typealias SetRegisteredFn = @convention(c) (Int32, UnsafePointer<CChar>, UnsafeMutablePointer<Int>?) -> Int32
    private typealias RemoveFn = @convention(c) (Int32, UnsafePointer<CChar>, Bool) -> Int32
    private typealias SeedFn = @convention(c) () -> Int32
    private typealias SetSystemFn = @convention(c) (Int32, Int32) -> Int32
    private typealias DockFn = @convention(c) (Int32, Bool) -> Int32
    private typealias SetPropFn = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    /// What the watcher thread needs, so it never touches main-actor state.
    private final class Worker: @unchecked Sendable {
        let connection: Int32
        let setRegistered: SetRegisteredFn
        let seed: SeedFn
        let name: String
        private let lock = NSLock()
        private var running = true
        private var lastSeed: Int32

        init(connection: Int32, setRegistered: @escaping SetRegisteredFn, seed: @escaping SeedFn, name: String) {
            self.connection = connection
            self.setRegistered = setRegistered
            self.seed = seed
            self.name = name
            lastSeed = seed()
        }

        func apply() {
            lock.lock(); defer { lock.unlock() }
            guard running else { return }
            var token = 0
            _ = name.withCString { setRegistered(connection, $0, &token) }
            lastSeed = seed()
        }

        func stop() {
            lock.lock(); running = false; lock.unlock()
        }

        /// Polls fast for a moment after the window server touched the cursor, then slows down: a reset only follows
        /// pointer movement, so an idle pointer needs no tight loop.
        func watch() {
            var quietPolls = 0
            while true {
                lock.lock()
                let alive = running
                let changed = seed() != lastSeed
                lock.unlock()
                if !alive { return }
                if changed {
                    apply()
                    quietPolls = 0
                } else {
                    quietPolls = min(quietPolls + 1, Self.burstPolls + 1)
                }
                usleep(quietPolls > Self.burstPolls ? Self.idleSleep : Self.burstSleep)
            }
        }

        private static let burstPolls = 600
        private static let burstSleep: UInt32 = 400
        private static let idleSleep: UInt32 = 4000
    }

    private let connection: ConnFn?
    private let register: RegisterFn?
    private let setRegistered: SetRegisteredFn?
    private let remove: RemoveFn?
    private let seed: SeedFn?
    private let setSystem: SetSystemFn?
    private let dock: DockFn?
    private let setProperty: SetPropFn?
    private let name = "com.beacon.cursor.skin"
    private var worker: Worker?
    private var monitor: Any?

    public init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else {
            connection = nil; register = nil; setRegistered = nil; remove = nil; seed = nil; setSystem = nil; dock = nil; setProperty = nil
            return
        }
        func load<T>(_ symbol: String, as type: T.Type) -> T? { dlsym(handle, symbol).map { unsafeBitCast($0, to: type) } }
        connection = load("SLSMainConnectionID", as: ConnFn.self)
        register = load("SLSRegisterCursorWithImages", as: RegisterFn.self)
        setRegistered = load("SLSSetRegisteredCursor", as: SetRegisteredFn.self)
        remove = load("SLSRemoveRegisteredCursor", as: RemoveFn.self)
        seed = load("SLSCurrentCursorSeed", as: SeedFn.self)
        setSystem = load("SLSSetSystemDefinedCursor", as: SetSystemFn.self)
        dock = load("SLSSetDockCursorOverride", as: DockFn.self)
        setProperty = dlsym(dlopen(nil, RTLD_NOW), "CGSSetConnectionProperty").map { unsafeBitCast($0, to: SetPropFn.self) }
    }

    public var isAvailable: Bool { connection != nil && register != nil && setRegistered != nil && seed != nil }

    public func show(_ skin: CursorSkinImage) -> Bool {
        guard let connection, let register, let setRegistered, let seed, !skin.images.isEmpty else { return false }
        clear()
        let cid = connection()
        _ = setProperty?(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        var token = 0
        let result = name.withCString {
            register(
                cid, $0, true, true, 1, skin.images as CFArray, skin.size, skin.hotspot, &token,
                CGRect(origin: .zero, size: skin.size), 0, 0
            )
        }
        guard result == 0 else { return false }
        _ = dock?(cid, true)
        let worker = Worker(connection: cid, setRegistered: setRegistered, seed: seed, name: name)
        self.worker = worker
        worker.apply()
        let thread = Thread { worker.watch() }
        thread.qualityOfService = .userInteractive
        thread.start()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .leftMouseUp]) { [weak worker] _ in
            worker?.apply()
        }
        return true
    }

    public func clear() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard let worker else { return }
        worker.stop()
        self.worker = nil
        guard let connection else { return }
        let cid = connection()
        _ = dock?(cid, false)
        _ = name.withCString { remove?(cid, $0, true) }
        _ = setSystem?(cid, 0)
    }
}
