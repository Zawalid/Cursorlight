import AppKit
import Foundation

/// What the user says they are sharing. There is no reliable public way to detect it (see
/// docs/research/2026-11-12-share-detection.md), so Cursorlight asks and never claims to know.
public enum DeclaredShare: String, CaseIterable, Codable, Sendable {
    case notSharing, wholeScreen, singleWindow

    public var displayName: String {
        switch self {
        case .notSharing: "Not sharing"
        case .wholeScreen: "Whole screen"
        case .singleWindow: "One window"
        }
    }
}

/// What to tell the user about whether viewers can see Cursorlight's effects.
public enum ShareSafeStatus: Equatable, Sendable {
    /// Not sharing as far as the user said, and no conferencing app is open.
    case idle
    /// The user said the whole screen is shared: effects are visible to viewers.
    case ok
    /// The user said one window is shared: viewers will not see effects.
    case warnSingleWindow
    /// Nothing declared, but a conferencing app is open: a reminder, not a claim.
    case reminder(app: String)
    /// The user said they are not sharing.
    case notSharing

    /// True when the status should draw attention (menu bar tint, amber card).
    public var needsAttention: Bool {
        switch self {
        case .warnSingleWindow, .reminder: true
        case .idle, .ok, .notSharing: false
        }
    }
}

public struct ConferencingApp: Equatable, Sendable {
    public let bundleID: String
    public let name: String
}

public enum ShareSafe {
    /// Apps that are usually open only for calls. Browsers (Meet) and chat apps (Slack, Discord) are left out on
    /// purpose: they are always running, so they would only add noise.
    public static let knownApps: [ConferencingApp] = [
        ConferencingApp(bundleID: "us.zoom.xos", name: "Zoom"),
        ConferencingApp(bundleID: "com.microsoft.teams2", name: "Microsoft Teams"),
        ConferencingApp(bundleID: "com.microsoft.teams", name: "Microsoft Teams"),
        ConferencingApp(bundleID: "Cisco-Systems.Spark", name: "Webex"),
        ConferencingApp(bundleID: "com.cisco.webexmeetingsapp", name: "Webex"),
        ConferencingApp(bundleID: "com.apple.FaceTime", name: "FaceTime"),
        ConferencingApp(bundleID: "com.skype.skype", name: "Skype"),
        ConferencingApp(bundleID: "com.logmein.GoToMeeting", name: "GoToMeeting"),
        ConferencingApp(bundleID: "com.bluejeans.BlueJeans", name: "BlueJeans"),
    ]

    public static func conferencingApp(for bundleID: String) -> ConferencingApp? {
        knownApps.first { $0.bundleID == bundleID }
    }

    /// Never returns `.ok` unless the user said so.
    public static func status(declared: DeclaredShare?, running: [ConferencingApp]) -> ShareSafeStatus {
        switch declared {
        case .singleWindow: return .warnSingleWindow
        case .wholeScreen: return .ok
        case .notSharing: return .notSharing
        case nil:
            if let app = running.first { return .reminder(app: app.name) }
            return .idle
        }
    }
}

/// Holds the user's declaration (in memory only: it should not outlive a call) and the conferencing apps that are
/// running, and exposes the resulting status.
@MainActor
public final class ShareSafeMonitor {
    public private(set) var declared: DeclaredShare?
    public private(set) var running: [ConferencingApp] = []
    public var onChange: (() -> Void)?

    private let runningBundleIDs: @MainActor () -> [String]
    private var observers: [NSObjectProtocol] = []

    public init(runningBundleIDs: @escaping @MainActor () -> [String] = {
        NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
    }) {
        self.runningBundleIDs = runningBundleIDs
        refresh()
    }

    public var status: ShareSafeStatus { ShareSafe.status(declared: declared, running: running) }

    public func declare(_ value: DeclaredShare?) {
        guard value != declared else { return }
        declared = value
        onChange?()
    }

    /// Re-reads which conferencing apps are running. A declaration is dropped when the last of them quits, so a
    /// stale "whole screen" does not outlive its call.
    public func refresh() {
        let ids = Set(runningBundleIDs())
        var seen = Set<String>()
        let apps = ShareSafe.knownApps.filter { ids.contains($0.bundleID) && seen.insert($0.name).inserted }
        let hadApps = !running.isEmpty
        let changed = apps != running
        running = apps
        if hadApps, apps.isEmpty, declared != nil { declared = nil }
        if changed { onChange?() }
    }

    public func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        refresh()
    }

    public func stop() {
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers = []
    }
}
