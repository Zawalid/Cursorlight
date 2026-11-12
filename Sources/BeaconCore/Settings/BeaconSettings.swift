import Foundation

/// Everything the user can choose. One Codable value, stored as JSON under one key.
/// Decoding is tolerant: any missing field takes its default, so adding a field never loses the others.
public struct BeaconSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var highlightStyle: HighlightStyle
    public var clickRipples: Bool
    /// 0 (hardest to trigger) to 100 (easiest).
    public var shakeSensitivity: Double
    public var accent: AccentChoice
    /// Multiplier for highlight radii.
    public var highlightSize: Double
    public var highlightIntensity: Double
    public var lensDim: Double
    public var inkStyle: InkStyle
    public var inkColor: InkColor
    /// Turn circles, rectangles, lines and arrows into clean shapes when a stroke ends.
    public var inkCleanup: Bool
    public var triggers: TriggerSettings
    /// Seconds a finished stroke stays before it fades.
    public var inkFadeAfter: Double
    public var welcomeSeen: Bool
    public var profiles: [Profile]
    /// The profile the user last chose; per-app rules apply on top of it.
    public var baseProfileID: String
    public var appRules: [AppRule]
    public var displayScope: DisplayScope
    /// One option per highlight style, and fading when the pointer is still.
    public var highlightOptions: HighlightOptions
    /// Situations where effects hide by themselves.
    public var hideRules: HideRules

    public static let inkFadeRange: ClosedRange<Double> = 0.8...8

    public var look: HighlightLook {
        HighlightLook(accent: accent, size: highlightSize, intensity: highlightIntensity, lensDim: lensDim, options: highlightOptions)
    }

    public static let defaults = BeaconSettings(
        version: currentVersion,
        highlightStyle: .aura,
        clickRipples: true,
        shakeSensitivity: 50,
        accent: .styleDefault,
        highlightSize: 1,
        highlightIntensity: 1,
        lensDim: 0.5,
        inkStyle: .marker,
        inkColor: .red,
        inkCleanup: true,
        triggers: TriggerSettings(),
        inkFadeAfter: 2,
        welcomeSeen: false,
        profiles: Profile.presets(),
        baseProfileID: Profile.streamID,
        appRules: [],
        displayScope: .all,
        highlightOptions: HighlightOptions(),
        hideRules: HideRules()
    )

    public init(
        version: Int, highlightStyle: HighlightStyle, clickRipples: Bool, shakeSensitivity: Double,
        accent: AccentChoice, highlightSize: Double, highlightIntensity: Double, lensDim: Double,
        inkStyle: InkStyle = .marker, inkColor: InkColor = .red, inkCleanup: Bool = true,
        triggers: TriggerSettings = TriggerSettings(),
        inkFadeAfter: Double = 2,
        welcomeSeen: Bool = false,
        profiles: [Profile] = Profile.presets(),
        baseProfileID: String = Profile.streamID,
        appRules: [AppRule] = [],
        displayScope: DisplayScope = .all,
        highlightOptions: HighlightOptions = HighlightOptions(),
        hideRules: HideRules = HideRules()
    ) {
        self.version = version
        self.highlightStyle = highlightStyle
        self.clickRipples = clickRipples
        self.shakeSensitivity = shakeSensitivity
        self.accent = accent
        self.highlightSize = highlightSize
        self.highlightIntensity = highlightIntensity
        self.lensDim = lensDim
        self.inkStyle = inkStyle
        self.inkColor = inkColor
        self.inkCleanup = inkCleanup
        self.triggers = triggers
        self.inkFadeAfter = inkFadeAfter
        self.welcomeSeen = welcomeSeen
        self.profiles = profiles
        self.baseProfileID = baseProfileID
        self.appRules = appRules
        self.displayScope = displayScope
        self.highlightOptions = highlightOptions
        self.hideRules = hideRules
    }

    private enum CodingKeys: String, CodingKey {
        case version, highlightStyle, clickRipples, shakeSensitivity, accent, highlightSize, highlightIntensity, lensDim
        case inkStyle, inkColor, inkCleanup, triggers, inkFadeAfter, welcomeSeen
        case profiles, baseProfileID, appRules, displayScope, highlightOptions, hideRules
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BeaconSettings.defaults
        version = (try? c.decode(Int.self, forKey: .version)) ?? d.version
        highlightStyle = (try? c.decode(HighlightStyle.self, forKey: .highlightStyle)) ?? d.highlightStyle
        clickRipples = (try? c.decode(Bool.self, forKey: .clickRipples)) ?? d.clickRipples
        shakeSensitivity = (try? c.decode(Double.self, forKey: .shakeSensitivity)) ?? d.shakeSensitivity
        accent = (try? c.decode(AccentChoice.self, forKey: .accent)) ?? d.accent
        highlightSize = (try? c.decode(Double.self, forKey: .highlightSize)) ?? d.highlightSize
        highlightIntensity = (try? c.decode(Double.self, forKey: .highlightIntensity)) ?? d.highlightIntensity
        lensDim = (try? c.decode(Double.self, forKey: .lensDim)) ?? d.lensDim
        inkStyle = (try? c.decode(InkStyle.self, forKey: .inkStyle)) ?? d.inkStyle
        inkColor = (try? c.decode(InkColor.self, forKey: .inkColor)) ?? d.inkColor
        inkCleanup = (try? c.decode(Bool.self, forKey: .inkCleanup)) ?? d.inkCleanup
        triggers = (try? c.decode(TriggerSettings.self, forKey: .triggers)) ?? d.triggers
        inkFadeAfter = (try? c.decode(Double.self, forKey: .inkFadeAfter)) ?? d.inkFadeAfter
        welcomeSeen = (try? c.decode(Bool.self, forKey: .welcomeSeen)) ?? d.welcomeSeen
        baseProfileID = (try? c.decode(String.self, forKey: .baseProfileID)) ?? d.baseProfileID
        appRules = (try? c.decode([AppRule].self, forKey: .appRules)) ?? d.appRules
        displayScope = (try? c.decode(DisplayScope.self, forKey: .displayScope)) ?? d.displayScope
        highlightOptions = ((try? c.decode(HighlightOptions.self, forKey: .highlightOptions)) ?? d.highlightOptions).sanitized()
        hideRules = (try? c.decode(HideRules.self, forKey: .hideRules)) ?? d.hideRules
        // Settings saved before profiles existed: their current look becomes the Stream profile.
        if let stored = try? c.decode([Profile].self, forKey: .profiles), !stored.isEmpty {
            profiles = stored
        } else {
            profiles = Profile.presets(stream: ProfileSnapshot(
                highlightStyle: highlightStyle, accent: accent, highlightSize: highlightSize,
                highlightIntensity: highlightIntensity, lensDim: lensDim, clickRipples: clickRipples,
                inkStyle: inkStyle, inkColor: inkColor, inkCleanup: inkCleanup, inkFadeAfter: inkFadeAfter,
                options: highlightOptions
            ))
        }
    }

    /// Returns a copy with every value forced into its valid range.
    func sanitized() -> BeaconSettings {
        var copy = self
        copy.shakeSensitivity = shakeSensitivity.isFinite ? min(max(shakeSensitivity, 0), 100) : 50
        copy.highlightSize = Self.clamp(highlightSize, HighlightLook.sizeRange, fallback: 1)
        copy.highlightIntensity = Self.clamp(highlightIntensity, HighlightLook.intensityRange, fallback: 1)
        copy.lensDim = Self.clamp(lensDim, HighlightLook.dimRange, fallback: 0.5)
        copy.inkFadeAfter = Self.clamp(inkFadeAfter, Self.inkFadeRange, fallback: 2)
        copy.highlightOptions = highlightOptions.sanitized()
        if !copy.profiles.contains(where: { $0.id == copy.baseProfileID }) {
            copy.baseProfileID = copy.profiles.first?.id ?? Profile.streamID
        }
        return copy
    }

    /// The current look and drawing choices as a profile snapshot.
    public var snapshot: ProfileSnapshot {
        ProfileSnapshot(
            highlightStyle: highlightStyle, accent: accent, highlightSize: highlightSize,
            highlightIntensity: highlightIntensity, lensDim: lensDim, clickRipples: clickRipples,
            inkStyle: inkStyle, inkColor: inkColor, inkCleanup: inkCleanup, inkFadeAfter: inkFadeAfter,
            options: highlightOptions
        )
    }

    public mutating func apply(_ s: ProfileSnapshot) {
        highlightStyle = s.highlightStyle
        accent = s.accent
        highlightSize = s.highlightSize
        highlightIntensity = s.highlightIntensity
        lensDim = s.lensDim
        clickRipples = s.clickRipples
        inkStyle = s.inkStyle
        inkColor = s.inkColor
        inkCleanup = s.inkCleanup
        inkFadeAfter = s.inkFadeAfter
        highlightOptions = s.options
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
}
