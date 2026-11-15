import Foundation

/// Reads process-level flags. CURSORLIGHT_AGENT=1 marks an agent-mode (visual check)
/// build: nothing global may be installed (launch at login, updater).
struct AppEnvironment: Sendable {
    let isAgentMode: Bool
    let isDemo: Bool
    /// CURSORLIGHT_OPEN=settings opens the settings window at launch (for looking at the app).
    let opensSettingsAtLaunch: Bool
    /// CURSORLIGHT_OPEN=settings:ink opens that page (highlight, ink, triggers, profiles, displays, about).
    let launchPage: String?
    /// CURSORLIGHT_OPEN=welcome opens the welcome guide at launch.
    let opensWelcomeAtLaunch: Bool

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        isAgentMode = environment["CURSORLIGHT_AGENT"] == "1"
        isDemo = environment["CURSORLIGHT_DEMO"] == "1"
        let open = environment["CURSORLIGHT_OPEN"] ?? ""
        opensSettingsAtLaunch = open.hasPrefix("settings")
        opensWelcomeAtLaunch = open == "welcome"
        launchPage = open.split(separator: ":").dropFirst().first.map(String.init)
    }

    var allowsLaunchAtLogin: Bool { !isAgentMode }
    var allowsUpdater: Bool { !isAgentMode }
    /// Agent mode stays inert unless CURSORLIGHT_DEMO=1 is also set.
    var startsCoordinator: Bool { !isAgentMode || isDemo }
}
