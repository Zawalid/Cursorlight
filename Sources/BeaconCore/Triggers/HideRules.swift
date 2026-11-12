import CoreGraphics
import Foundation

/// Why Beacon stays out of the way right now.
public enum HideReason: Equatable, Sendable {
    case fullScreen
    case videoPlayer

    public var displayName: String {
        switch self {
        case .fullScreen: "Full-screen app"
        case .videoPlayer: "Video player"
        }
    }
}

/// Situations where effects hide on their own, so a presenter does not have to switch them off. All off by default:
/// a full-screen slide deck is exactly where effects are wanted.
public struct HideRules: Codable, Equatable, Sendable {
    public var fullScreenApps = false
    public var videoPlayers = false

    public init(fullScreenApps: Bool = false, videoPlayers: Bool = false) {
        self.fullScreenApps = fullScreenApps
        self.videoPlayers = videoPlayers
    }

    public var isActive: Bool { fullScreenApps || videoPlayers }

    /// Apps that exist to play video.
    public static let videoPlayerBundleIDs: Set<String> = [
        "com.apple.QuickTimePlayerX", "com.apple.TV", "org.videolan.vlc", "com.colliderli.iina", "io.mpv",
        "com.plexapp.plexmediaplayer", "com.plexapp.plex", "tv.plex.desktop", "com.netflix.Netflix", "com.apple.Photo-Booth",
    ]

    /// The reason to hide, if any, for the frontmost app.
    public func reason(frontBundleID: String?, frontIsFullScreen: Bool) -> HideReason? {
        if videoPlayers, let frontBundleID, Self.videoPlayerBundleIDs.contains(frontBundleID) { return .videoPlayer }
        if fullScreenApps, frontIsFullScreen { return .fullScreen }
        return nil
    }

    private enum CodingKeys: String, CodingKey { case fullScreenApps, videoPlayers }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fullScreenApps = (try? c.decode(Bool.self, forKey: .fullScreenApps)) ?? false
        videoPlayers = (try? c.decode(Bool.self, forKey: .videoPlayers)) ?? false
    }
}

/// One window, as the window server lists it.
public struct WindowSnapshot: Equatable, Sendable {
    public var ownerPID: Int32
    public var layer: Int
    public var bounds: CGRect

    public init(ownerPID: Int32, layer: Int, bounds: CGRect) {
        self.ownerPID = ownerPID
        self.layer = layer
        self.bounds = bounds
    }
}

public enum FullScreenDetector {
    /// True when an ordinary window of the app covers a whole display, menu bar included: that is what a native
    /// full-screen window looks like. `displays` are in the same coordinate space as the window bounds.
    public static func isFullScreen(pid: Int32, windows: [WindowSnapshot], displays: [CGRect], tolerance: CGFloat = 1.5) -> Bool {
        windows.contains { window in
            window.ownerPID == pid && window.layer == 0 && displays.contains { display in
                abs(window.bounds.minX - display.minX) <= tolerance && abs(window.bounds.minY - display.minY) <= tolerance
                    && abs(window.bounds.width - display.width) <= tolerance && abs(window.bounds.height - display.height) <= tolerance
            }
        }
    }
}
