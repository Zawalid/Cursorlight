import Foundation

/// Ready-made scenes people can add from the scene strip. Names are plain jobs, not styles.
public enum ScenePresets {
    public struct Preset: Equatable, Sendable {
        public let key: String
        public let name: String
        public let detail: String
        public let snapshot: ProfileSnapshot
    }

    public static let all: [Preset] = [
        Preset(
            key: "teaching", name: "Teaching", detail: "A large soft glow, a thick yellow marker, strokes that stay a while.",
            snapshot: ProfileSnapshot(
                highlightStyle: .aura, accent: .iris, highlightSize: 1.3, highlightIntensity: 1, clickRipples: true,
                inkStyle: .marker, inkColor: .yellow, inkCleanup: true, inkFadeAfter: 5, inkWidth: 1.4,
                options: options { $0.clickEffect = .doubleRing }
            )
        ),
        Preset(
            key: "webinar", name: "Webinar", detail: "Dims everything but a circle around the pointer, with a highlighter for emphasis.",
            snapshot: ProfileSnapshot(
                highlightStyle: .lens, accent: .styleDefault, highlightSize: 1.2, lensDim: 0.55, clickRipples: true,
                inkStyle: .highlighter, inkColor: .yellow, inkCleanup: true, inkFadeAfter: 3, inkWidth: 1,
                options: options { $0.lensSoftness = 0.3 }
            )
        ),
        Preset(
            key: "tutorial", name: "Tutorial", detail: "A comet with a long tail that follows fast movement, and clear click bursts.",
            snapshot: ProfileSnapshot(
                highlightStyle: .comet, accent: .coral, highlightSize: 1.1, clickRipples: true,
                inkStyle: .neon, inkColor: .green, inkCleanup: true, inkFadeAfter: 2.5, inkWidth: 1,
                options: options { $0.cometTail = 1.5; $0.clickEffect = .burst }
            )
        ),
        Preset(
            key: "pairing", name: "Pairing", detail: "A slim blue ring that stays out of the code, and a thin pencil.",
            snapshot: ProfileSnapshot(
                highlightStyle: .keyline, accent: .blue, highlightSize: 0.9, highlightIntensity: 0.9, clickRipples: true,
                inkStyle: .pencil, inkColor: .blue, inkCleanup: true, inkFadeAfter: 2, inkWidth: 1.2,
                options: options { $0.keylineWidth = 0.8; $0.clickEffect = .pulse }
            )
        ),
        Preset(
            key: "high-visibility", name: "High visibility", detail: "Yellow at full strength and larger, for small screens, bad video and low vision.",
            snapshot: ProfileSnapshot(
                highlightStyle: .sonar, accent: .highContrast, highlightSize: 1.4, highlightIntensity: 1, clickRipples: true,
                inkStyle: .marker, inkColor: .white, inkCleanup: true, inkFadeAfter: 4, inkWidth: 1.6,
                options: options { $0.clickEffect = .doubleRing }
            )
        ),
    ]

    private static func options(_ edit: (inout HighlightOptions) -> Void) -> HighlightOptions {
        var o = HighlightOptions()
        edit(&o)
        return o.sanitized()
    }

    /// A scene made from a preset, with an id of its own and a name that does not clash with `existing`.
    public static func scene(from preset: Preset, existing: [Profile]) -> Profile {
        Profile(
            id: "custom-\(UUID().uuidString.prefix(8).lowercased())",
            name: Profile.uniqueName(preset.name, existing: existing), snapshot: preset.snapshot
        )
    }
}

/// A scene saved to a file, so it can be shared. Versioned, tolerant, and never trusted: whatever comes in is clamped.
public struct SceneFile: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let fileExtension = "cursorlightscene"

    public var format: String = "cursorlight-scene"
    public var version: Int = SceneFile.currentVersion
    public var name: String
    public var snapshot: ProfileSnapshot

    public init(name: String, snapshot: ProfileSnapshot) {
        self.name = name
        self.snapshot = snapshot
    }

    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(self)
    }

    /// The scene in `data`, or nil when it is not a Cursorlight scene file. Files from a newer version are refused.
    public static func decode(_ data: Data) -> SceneFile? {
        guard data.count < 200_000, let file = try? JSONDecoder().decode(SceneFile.self, from: data),
              file.format == "cursorlight-scene", file.version <= currentVersion else { return nil }
        return file
    }

    /// A scene ready to add: new id, a unique, clamped name, and every value forced into range.
    public func scene(existing: [Profile]) -> Profile {
        var clean = CursorlightSettings.defaults
        clean.apply(snapshot)
        let base = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Profile.maxNameLength))
        return Profile(
            id: "custom-\(UUID().uuidString.prefix(8).lowercased())",
            name: Profile.uniqueName(base.isEmpty ? "Imported" : base, existing: existing),
            snapshot: clean.sanitized().snapshot
        )
    }
}

extension Profile {
    /// `name`, or `name 2`, `name 3` when it is taken, within the name limit.
    public static func uniqueName(_ name: String, existing: [Profile]) -> String {
        let taken = Set(existing.map(\.name))
        let base = String(name.prefix(maxNameLength))
        if !taken.contains(base) { return base }
        var number = 2
        while true {
            let suffix = " \(number)"
            let candidate = String(base.prefix(maxNameLength - suffix.count)) + suffix
            if !taken.contains(candidate) { return candidate }
            number += 1
        }
    }
}
