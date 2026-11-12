import Foundation

/// The look and drawing choices a profile stores. Triggers, shake sensitivity and cursor size stay global.
public struct ProfileSnapshot: Codable, Equatable, Sendable {
    public var highlightStyle: HighlightStyle
    public var accent: AccentChoice
    public var highlightSize: Double
    public var highlightIntensity: Double
    public var lensDim: Double
    public var clickRipples: Bool
    public var inkStyle: InkStyle
    public var inkColor: InkColor
    public var inkCleanup: Bool
    public var inkFadeAfter: Double
    public var options: HighlightOptions

    public init(
        highlightStyle: HighlightStyle = .aura, accent: AccentChoice = .styleDefault, highlightSize: Double = 1,
        highlightIntensity: Double = 1, lensDim: Double = 0.5, clickRipples: Bool = true, inkStyle: InkStyle = .marker,
        inkColor: InkColor = .red, inkCleanup: Bool = true, inkFadeAfter: Double = 2,
        options: HighlightOptions = HighlightOptions()
    ) {
        self.highlightStyle = highlightStyle
        self.accent = accent
        self.highlightSize = highlightSize
        self.highlightIntensity = highlightIntensity
        self.lensDim = lensDim
        self.clickRipples = clickRipples
        self.inkStyle = inkStyle
        self.inkColor = inkColor
        self.inkCleanup = inkCleanup
        self.inkFadeAfter = inkFadeAfter
        self.options = options
    }

    private enum CodingKeys: String, CodingKey {
        case highlightStyle, accent, highlightSize, highlightIntensity, lensDim, clickRipples
        case inkStyle, inkColor, inkCleanup, inkFadeAfter, options
    }

    /// Tolerant: a missing field takes its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ProfileSnapshot()
        highlightStyle = (try? c.decode(HighlightStyle.self, forKey: .highlightStyle)) ?? d.highlightStyle
        accent = (try? c.decode(AccentChoice.self, forKey: .accent)) ?? d.accent
        highlightSize = (try? c.decode(Double.self, forKey: .highlightSize)) ?? d.highlightSize
        highlightIntensity = (try? c.decode(Double.self, forKey: .highlightIntensity)) ?? d.highlightIntensity
        lensDim = (try? c.decode(Double.self, forKey: .lensDim)) ?? d.lensDim
        clickRipples = (try? c.decode(Bool.self, forKey: .clickRipples)) ?? d.clickRipples
        inkStyle = (try? c.decode(InkStyle.self, forKey: .inkStyle)) ?? d.inkStyle
        inkColor = (try? c.decode(InkColor.self, forKey: .inkColor)) ?? d.inkColor
        inkCleanup = (try? c.decode(Bool.self, forKey: .inkCleanup)) ?? d.inkCleanup
        inkFadeAfter = (try? c.decode(Double.self, forKey: .inkFadeAfter)) ?? d.inkFadeAfter
        options = ((try? c.decode(HighlightOptions.self, forKey: .options)) ?? d.options).sanitized()
    }
}

public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var snapshot: ProfileSnapshot

    public init(id: String, name: String, snapshot: ProfileSnapshot) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
    }

    public static let streamID = "stream"

    /// The three presets. Stream carries the app's own defaults.
    public static func presets(stream: ProfileSnapshot = ProfileSnapshot()) -> [Profile] {
        [
            Profile(id: streamID, name: "Stream", snapshot: stream),
            Profile(id: "meeting", name: "Meeting", snapshot: ProfileSnapshot(
                highlightStyle: .keyline, highlightSize: 1, highlightIntensity: 0.85, inkStyle: .marker, inkColor: .blue
            )),
            Profile(id: "recording", name: "Recording", snapshot: ProfileSnapshot(
                highlightStyle: .sonar, highlightSize: 0.85, inkStyle: .neon, inkColor: .green
            )),
        ]
    }

    /// One line describing the profile, for cards.
    public var summary: String {
        let size = snapshot.highlightSize
        let sizeWord = size >= 1.3 ? "large" : (size <= 0.85 ? "small" : "medium")
        return "\(snapshot.highlightStyle.displayName), \(sizeWord)"
    }

    /// The color the highlight really draws in: the chosen accent, or the style's own.
    public var highlightColor: RGBA {
        snapshot.accent.color ?? Palette.accent(for: snapshot.highlightStyle)
    }

    /// Longest name a scene can have.
    public static let maxNameLength = 24

    /// A name for a copy: "Meeting copy", then "Meeting copy 2", and so on, within the name limit.
    public static func copyName(of name: String, existing: [Profile]) -> String {
        let taken = Set(existing.map(\.name))
        let first = String("\(name) copy".prefix(maxNameLength))
        if !taken.contains(first) { return first }
        var number = 2
        while true {
            let suffix = " copy \(number)"
            let candidate = String(name.prefix(maxNameLength - suffix.count)) + suffix
            if !taken.contains(candidate) { return candidate }
            number += 1
        }
    }

    /// The list with `id` moved to sit just before `target`, or to the end when `target` is nil.
    /// Unknown ids, or a move onto itself, return the list unchanged.
    public static func reordered(_ profiles: [Profile], moving id: String, before target: String?) -> [Profile] {
        guard id != target, let from = profiles.firstIndex(where: { $0.id == id }) else { return profiles }
        if let target, !profiles.contains(where: { $0.id == target }) { return profiles }
        var result = profiles
        let moved = result.remove(at: from)
        if let target, let to = result.firstIndex(where: { $0.id == target }) {
            result.insert(moved, at: to)
        } else {
            result.append(moved)
        }
        return result
    }
}

/// What to do when an app is frontmost: use a profile, or switch Beacon off.
public struct AppRule: Codable, Equatable, Identifiable, Sendable {
    public var bundleID: String
    public var appName: String
    /// nil means Beacon is off while this app is frontmost.
    public var profileID: String?

    public var id: String { bundleID }

    public init(bundleID: String, appName: String, profileID: String?) {
        self.bundleID = bundleID
        self.appName = appName
        self.profileID = profileID
    }
}

/// Where effects are shown.
public enum DisplayScope: String, CaseIterable, Codable, Sendable {
    /// Every display; effects follow the pointer.
    case all
    /// Only the display with the menu bar.
    case mainOnly

    public var displayName: String {
        switch self {
        case .all: "All displays"
        case .mainOnly: "Main display only"
        }
    }
}

public enum ProfileSelection: Equatable, Sendable {
    case profile(String)
    /// A per-app rule switched Beacon off.
    case off
}

/// Picks the profile to use. The user's manual choice (`base`) wins until the frontmost app changes; after that a
/// matching per-app rule applies, and without one the base profile is used. Pure: no workspace access.
public struct ProfileSwitcher: Equatable, Sendable {
    public private(set) var base: String
    public private(set) var frontmost: String?
    private var manualHold = false

    public init(base: String) {
        self.base = base
    }

    public mutating func chooseManually(_ profileID: String) {
        base = profileID
        manualHold = true
    }

    /// Sets the base without holding it (used at launch and when the base profile is removed).
    public mutating func setBase(_ profileID: String) {
        base = profileID
    }

    public mutating func frontmostChanged(to bundleID: String?) {
        guard bundleID != frontmost else { return }
        frontmost = bundleID
        manualHold = false
    }

    public func selection(rules: [AppRule], knownProfiles: Set<String>) -> ProfileSelection {
        if !manualHold, let bundle = frontmost, let rule = rules.first(where: { $0.bundleID == bundle }) {
            guard let id = rule.profileID else { return .off }
            // A rule pointing at a deleted profile is ignored.
            if knownProfiles.contains(id) { return .profile(id) }
        }
        return .profile(base)
    }
}
