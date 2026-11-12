import AppKit
import BeaconCore
import ServiceManagement
import SwiftUI

struct ProfilesPage: View {
    var body: some View {
        VStack(spacing: 18) {
            PageHeader(title: "Profiles and apps", subtitle: "Saved sets of choices, and rules that pick one for each app.")
            SettingsGroup {
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 26)).foregroundStyle(Theme.faint)
                    Text("Coming next").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                    Text("Stream, Meeting and Recording profiles, and per-app rules, arrive in the next update. Your current choices keep working.")
                        .font(.system(size: 12)).foregroundStyle(Theme.dim).multilineTextAlignment(.center).frame(maxWidth: 380)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
    }
}

struct DisplaysPage: View {
    private var screens: [NSScreen] { NSScreen.screens }

    var body: some View {
        VStack(spacing: 18) {
            PageHeader(title: "Displays", subtitle: "Effects follow the pointer from screen to screen.")
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                    let aspect = screen.frame.height / max(screen.frame.width, 1)
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.11)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(index == 0 ? Theme.accent : Color(white: 0.3), lineWidth: 2))
                            .frame(width: 190, height: 190 * aspect)
                        Text(screen.localizedName).font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                }
            }
            .frame(maxWidth: .infinity).padding(28)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line))
            SettingsGroup {
                SettingRow(title: "Show effects on", subtitle: "Choosing one display arrives with profiles", showsDivider: false) {
                    Pill(text: "All displays")
                }
            }
            SettingsGroup {
                SettingRow(title: "Sharing a single window?", subtitle: "Viewers will not see effects. Beacon works when you share the whole screen.", showsDivider: false) {
                    EmptyView()
                }
            }
        }
    }
}

struct AboutPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 18) {
            PageHeader(title: "About", subtitle: "\(Branding.appName)  \(version)")
            SettingsGroup {
                SettingRow(title: "Launch at login", subtitle: LaunchAtLogin.isAvailable ? nil : "Not available in this build") {
                    BeaconToggle(isOn: Binding(
                        get: { launchAtLogin },
                        set: { value in
                            LaunchAtLogin.set(value)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    ))
                    .opacity(LaunchAtLogin.isAvailable ? 1 : 0.4)
                    .allowsHitTesting(LaunchAtLogin.isAvailable)
                }
                SettingRow(title: "Updates", subtitle: "Update checks arrive with the first release") {
                    Pill(text: "Not yet")
                }
                SettingRow(title: "Welcome guide", subtitle: "See the shake demo and the optional permissions again", showsDivider: false) {
                    Button("Open") { model.openWelcome() }.buttonStyle(GhostButtonStyle())
                }
            }
            SettingsGroup {
                SettingRow(title: "Privacy", subtitle: "No accounts and no analytics. The network is used only for update checks, once they exist.", showsDivider: false) {
                    EmptyView()
                }
            }
        }
    }
}

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
