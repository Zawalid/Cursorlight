import Foundation

/// Loads and saves `CursorlightSettings`. Main-thread use only.
public final class SettingsStore {
    public static let storageKey = "cursorlight.settings.v1"
    private static let legacyStyleKey = "highlightStyle"
    private static let legacyRipplesKey = "clickRipples"

    private let defaults: UserDefaults
    public private(set) var settings: CursorlightSettings
    /// Called after a change that altered the stored value.
    public var onChange: ((CursorlightSettings) -> Void)?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(CursorlightSettings.self, from: data) {
            settings = decoded.sanitized()
        } else {
            settings = Self.migrateLegacy(from: defaults)
            save()
        }
    }

    /// The profile whose snapshot follows every change to the look and drawing settings. nil: none.
    public var liveProfileID: String?

    public func update(_ change: (inout CursorlightSettings) -> Void) {
        var next = settings
        change(&next)
        next = next.sanitized()
        if let live = liveProfileID, let index = next.profiles.firstIndex(where: { $0.id == live }) {
            next.profiles[index].snapshot = next.snapshot
        }
        guard next != settings else { return }
        settings = next
        save()
        onChange?(next)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Reads the two keys written by early builds, then removes them.
    private static func migrateLegacy(from defaults: UserDefaults) -> CursorlightSettings {
        var result = CursorlightSettings.defaults
        if let raw = defaults.string(forKey: legacyStyleKey), let style = HighlightStyle(rawValue: raw) {
            result.highlightStyle = style
        }
        if let ripples = defaults.object(forKey: legacyRipplesKey) as? Bool {
            result.clickRipples = ripples
        }
        defaults.removeObject(forKey: legacyStyleKey)
        defaults.removeObject(forKey: legacyRipplesKey)
        return result
    }
}
