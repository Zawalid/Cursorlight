import AppKit
import BeaconCore
import ServiceManagement
import SwiftUI

struct ProfilesPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            PageHeader(title: "Profiles and apps", subtitle: "A profile is a saved set of look and drawing choices. Switch from the menu bar, or let an app pick one.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(model.profiles) { profile in
                    profileCard(profile)
                }
                Button { model.addProfile() } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 16, weight: .medium))
                        Text("Save current look").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                }
                .buttonStyle(.plain)
            }
            Text("Changes you make on the other pages are saved to the active profile.")
                .font(.system(size: 12)).foregroundStyle(Theme.faint).frame(maxWidth: .infinity, alignment: .leading)

            SettingsGroup {
                SettingRow(title: "Per-app rules", subtitle: "When one of these apps is in front, Beacon switches profile or turns off.", showsDivider: !model.settings.appRules.isEmpty) {
                    Button("Add an app") { model.addRuleFromPanel() }.buttonStyle(GhostButtonStyle())
                }
                ForEach(Array(model.settings.appRules.enumerated()), id: \.element.id) { index, rule in
                    SettingRow(title: rule.appName, subtitle: rule.bundleID, showsDivider: index < model.settings.appRules.count - 1) {
                        HStack(spacing: 10) {
                            BeaconMenu(options: ruleOptions, selection: Binding(
                                get: { rule.profileID ?? "" },
                                set: { model.setRule(rule, profileID: $0.isEmpty ? nil : $0) }
                            ), width: 130)
                            Button { model.removeRule(rule) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove rule for \(rule.appName)")
                        }
                    }
                }
            }
            if model.settings.appRules.isEmpty {
                Text("No rules yet. A manual profile choice always wins until you switch to another app.")
                    .font(.system(size: 12)).foregroundStyle(Theme.faint).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var ruleOptions: [(value: String, title: String)] {
        model.profiles.map { ($0.id, $0.name) } + [("", "Off")]
    }

    private func profileCard(_ profile: Profile) -> some View {
        let active = model.appliedProfileID == profile.id
        return Button { model.chooseProfile(profile.id) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(rgba: model.look.accentColor(for: profile.snapshot.highlightStyle)).opacity(0.85))
                        .frame(width: 24, height: 24)
                    Spacer()
                    if active { Pill(text: "Active", tint: Theme.accent) }
                }
                Text(profile.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text).padding(.top, 6)
                Text(profile.summary).font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(active ? Theme.accent : Theme.line, lineWidth: active ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if model.profiles.count > 1 { Button("Delete \(profile.name)", role: .destructive) { model.deleteProfile(profile.id) } }
        }
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

struct DisplaysPage: View {
    @EnvironmentObject private var model: AppModel
    private var screens: [NSScreen] { NSScreen.screens }

    var body: some View {
        VStack(spacing: 18) {
            PageHeader(title: "Displays", subtitle: "Effects follow the pointer from screen to screen, or stay on the main display.")
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                    let aspect = screen.frame.height / max(screen.frame.width, 1)
                    let shown = model.displayScope == .all || index == 0
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.11)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(shown ? Theme.accent : Color(white: 0.3), lineWidth: 2))
                            .shadow(color: shown ? Theme.accent.opacity(0.25) : .clear, radius: 12)
                            .frame(width: 190, height: 190 * aspect)
                        Text(index == 0 ? "\(screen.localizedName) (main)" : screen.localizedName)
                            .font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                }
            }
            .frame(maxWidth: .infinity).padding(28)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line))
            SettingsGroup {
                SettingRow(title: "Show effects on", subtitle: "The main display is the one with the menu bar", showsDivider: false) {
                    BeaconSegmented(options: DisplayScope.allCases.map { ($0, $0.displayName) }, selection: Binding(get: { model.displayScope }, set: { model.setDisplayScope($0) }))
                }
            }
            ShareStatusCard()
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
                SettingRow(
                    title: "Check for updates automatically",
                    subtitle: model.updatesConfigured ? "Asks GitHub once a day. Nothing installs without your OK." : "This build has no update signing key yet"
                ) {
                    BeaconToggle(isOn: Binding(get: { model.automaticUpdateChecks }, set: { model.setAutomaticUpdateChecks($0) }))
                        .opacity(model.updatesConfigured ? 1 : 0.4)
                        .allowsHitTesting(model.updatesConfigured)
                }
                SettingRow(title: "Check now") {
                    Button("Check") { model.checkForUpdates() }.buttonStyle(GhostButtonStyle())
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
