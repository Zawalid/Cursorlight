import Foundation

/// Kinds of app that can share one rule, so you do not have to add every editor or browser by hand.
public enum AppCategory: String, CaseIterable, Codable, Sendable {
    case calls, editors, browsers, presentations, design, video

    public var displayName: String {
        switch self {
        case .calls: "Video calls"
        case .editors: "Code and terminals"
        case .browsers: "Browsers"
        case .presentations: "Slide decks"
        case .design: "Design tools"
        case .video: "Video players"
        }
    }

    public var symbol: String {
        switch self {
        case .calls: "video"
        case .editors: "chevron.left.forwardslash.chevron.right"
        case .browsers: "safari"
        case .presentations: "play.rectangle"
        case .design: "pencil.and.ruler"
        case .video: "play.tv"
        }
    }

    /// Exact bundle identifiers and prefixes (ending in a dot) of the apps in this category.
    var bundleIDs: Set<String> {
        switch self {
        case .calls: Set(ShareSafe.knownApps.map(\.bundleID))
        case .editors:
            ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "dev.zed.Zed", "com.sublimetext.4",
             "com.panic.Nova", "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable"]
        case .browsers:
            ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "company.thebrowser.Browser", "com.brave.Browser",
             "com.microsoft.edgemac", "com.operasoftware.Opera", "app.zen-browser.zen"]
        case .presentations: ["com.apple.iWork.Keynote", "com.microsoft.Powerpoint"]
        case .design: ["com.figma.Desktop", "com.bohemiancoding.sketch3", "com.seriflabs.affinitydesigner2", "com.adobe.Photoshop"]
        case .video: HideRules.videoPlayerBundleIDs
        }
    }

    private var prefixes: [String] {
        self == .editors ? ["com.jetbrains."] : []
    }

    public func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID) || prefixes.contains { bundleID.hasPrefix($0) }
    }

    /// The category of an app, if it is in one.
    public static func of(_ bundleID: String) -> AppCategory? {
        allCases.first { $0.contains(bundleID) }
    }
}

/// What to do for every app of one category. nil scene: Cursorlight is off for them.
public struct CategoryRule: Codable, Equatable, Identifiable, Sendable {
    public var category: AppCategory
    public var profileID: String?

    public var id: String { category.rawValue }

    public init(category: AppCategory, profileID: String?) {
        self.category = category
        self.profileID = profileID
    }
}
