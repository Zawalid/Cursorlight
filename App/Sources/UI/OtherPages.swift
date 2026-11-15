import AppKit
import CursorlightCore
import ServiceManagement
import SwiftUI

/// Launch at login through the system service. Off in agent-mode builds.
enum LaunchAtLogin {
    static var isAvailable: Bool { !AppEnvironment().isAgentMode }
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        guard isAvailable else { return }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Launch at login change failed: \(error.localizedDescription)")
        }
    }
}
