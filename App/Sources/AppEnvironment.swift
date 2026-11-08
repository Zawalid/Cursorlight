import Foundation

/// Reads process-level flags. BEACON_AGENT=1 marks an agent-mode (visual check)
/// build: nothing global may be installed (launch at login, updater).
struct AppEnvironment: Sendable {
    let isAgentMode: Bool

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        isAgentMode = environment["BEACON_AGENT"] == "1"
    }

    var allowsLaunchAtLogin: Bool { !isAgentMode }
    var allowsUpdater: Bool { !isAgentMode }
}
