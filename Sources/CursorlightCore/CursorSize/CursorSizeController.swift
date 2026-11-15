import Foundation

/// Persisted original scale, set while Cursorlight has changed the system cursor size, so a relaunch after a crash can restore it.
public protocol ScaleMarkerStore: AnyObject {
    var originalScale: Float? { get set }
}

public final class UserDefaultsScaleMarker: ScaleMarkerStore {
    public static let key = "originalCursorScale"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var originalScale: Float? {
        get { defaults.object(forKey: Self.key) as? Float }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}

/// Changes the system cursor size and always remembers how to put it back.
@MainActor
public final class CursorSizeController {
    public static let range: ClosedRange<Float> = 0.5...4.0

    private let scaling: CursorScaling
    private let markers: ScaleMarkerStore

    public init(scaling: CursorScaling, markers: ScaleMarkerStore) {
        self.scaling = scaling
        self.markers = markers
    }

    /// The scale the system reports right now, nil when unavailable.
    public var currentScale: Float? { scaling.currentScale() }

    /// Sets the cursor scale (clamped to 0.5...4.0). NaN and non-positive values are ignored.
    public func apply(_ scale: Float) {
        guard scale.isFinite, scale > 0 else { return }
        let target = min(max(scale, Self.range.lowerBound), Self.range.upperBound)
        let hadMarker = markers.originalScale != nil
        if !hadMarker {
            guard let original = scaling.currentScale() else { return }
            markers.originalScale = original
        }
        if !scaling.setScale(target), !hadMarker {
            markers.originalScale = nil
        }
    }

    /// Restores the scale saved before the first change and clears the marker.
    public func reset() {
        guard let original = markers.originalScale else { return }
        if scaling.setScale(original) {
            markers.originalScale = nil
        }
    }

    /// At launch: a previous run that died mid-change left a marker; put the original size back.
    public func restoreIfStale() {
        reset()
    }
}
