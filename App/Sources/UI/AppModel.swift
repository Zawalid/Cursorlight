import AppKit
import BeaconCore
import SwiftUI
import UniformTypeIdentifiers

/// The bridge between the coordinator and the views. Views read settings from here and call its methods; every
/// change bumps `revision` so SwiftUI redraws. Holds no behavior of its own.
@MainActor
final class AppModel: ObservableObject {
    let coordinator: AppCoordinator
    let updater: AppUpdater
    @Published private(set) var revision = 0
    /// Set by the app delegate; opens the settings window on a page.
    var openSettings: (SettingsPage) -> Void = { _ in }
    var openWelcome: () -> Void = {}
    var quit: () -> Void = { NSApp.terminate(nil) }

    init(coordinator: AppCoordinator, updater: AppUpdater) {
        self.coordinator = coordinator
        self.updater = updater
        coordinator.highlight.onChange = { [weak self] in self?.bump() }
        coordinator.ink.onChange = { [weak self] in self?.bump() }
        coordinator.onSizeChange = { [weak self] in self?.bump() }
        coordinator.onTriggersChange = { [weak self] in self?.bump() }
        coordinator.onShareChange = { [weak self] in self?.bump() }
    }

    func bump() { revision += 1 }

    var settings: BeaconSettings { coordinator.settings.settings }
    var look: HighlightLook { settings.look }
    var isPaused: Bool { coordinator.isPaused }
    var needsInputMonitoring: Bool { coordinator.needsInputMonitoring }
    var failedHotkeys: [HotKeyAction] { coordinator.failedHotkeys }
    var cursorScale: Double { Double(coordinator.cursorSize.currentScale ?? 1) }

    // MARK: Updates

    var updatesConfigured: Bool { updater.isConfigured }
    var automaticUpdateChecks: Bool { updater.automaticallyChecks }
    func setAutomaticUpdateChecks(_ on: Bool) { updater.automaticallyChecks = on; bump() }
    func checkForUpdates() { updater.checkNow() }

    // MARK: Share safety

    var shareStatus: ShareSafeStatus { coordinator.shareSafe.status }
    /// The call apps that are open right now, for their icons.
    var conferencingApps: [ConferencingApp] { coordinator.shareSafe.running }
    var declaredShare: DeclaredShare? { coordinator.shareSafe.declared }
    func declareShare(_ value: DeclaredShare?) { coordinator.shareSafe.declare(value); bump() }

    // MARK: Profiles

    var profiles: [Profile] { settings.profiles }
    var appliedProfileID: String { coordinator.appliedProfileID ?? settings.baseProfileID }
    var isOffForApp: Bool { coordinator.isOffForApp }
    var displayScope: DisplayScope { settings.displayScope }

    func chooseProfile(_ id: String) { coordinator.chooseProfile(id); bump() }
    func addProfile() { coordinator.addProfile(); bump() }
    func duplicateProfile(_ id: String) { coordinator.duplicateProfile(id); bump() }
    func moveProfile(_ id: String, before target: String?) { coordinator.moveProfile(id, before: target); bump() }
    func deleteProfile(_ id: String) { coordinator.deleteProfile(id); bump() }
    func renameProfile(_ id: String, to name: String) { coordinator.renameProfile(id, to: name); bump() }
    func setDisplayScope(_ scope: DisplayScope) { coordinator.setDisplayScope(scope); bump() }

    /// Sets the profile for an app, or nil to switch Beacon off while it is frontmost.
    func setRule(_ rule: AppRule, profileID: String?) {
        var updated = rule
        updated.profileID = profileID
        coordinator.setAppRule(updated)
        bump()
    }

    func removeRule(_ rule: AppRule) { coordinator.removeAppRule(bundleID: rule.bundleID); bump() }

    /// Asks the user for an app and adds a rule for it, starting with the current base profile.
    /// Regular apps that are open right now, except Beacon, sorted by name.
    func runningAppCandidates() -> [RunningApp] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app -> RunningApp? in
                guard let id = app.bundleIdentifier, let name = app.localizedName, seen.insert(id).inserted else { return nil }
                return RunningApp(bundleID: id, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Adds a rule for an app. `preferring` is a scene id to use if it exists; otherwise the default scene.
    func addRule(bundleID: String, name: String, preferring: String?) {
        let scene = preferring.flatMap { id in settings.profiles.contains { $0.id == id } ? id : nil } ?? settings.baseProfileID
        coordinator.setAppRule(AppRule(bundleID: bundleID, appName: name, profileID: scene))
        bump()
    }

    func addRuleFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose an app to give its own profile"
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        coordinator.setAppRule(AppRule(bundleID: id, appName: name, profileID: settings.baseProfileID))
        bump()
    }

    // MARK: Effects

    func isOn(_ effect: EffectKind) -> Bool {
        switch effect {
        case .highlight: coordinator.highlight.isOn
        case .laser: coordinator.highlight.isLaserOn
        case .ink: coordinator.ink.isActive
        case .none: false
        }
    }

    func toggle(_ effect: EffectKind) {
        switch effect {
        case .highlight: coordinator.toggleHighlight()
        case .laser: coordinator.toggleLaser()
        case .ink: coordinator.toggleInk()
        case .none: break
        }
        bump()
    }

    func setPaused(_ paused: Bool) { coordinator.setPaused(paused) }

    // MARK: Highlight

    func setStyle(_ style: HighlightStyle) { coordinator.setHighlightStyle(style); bump() }
    func setAccent(_ accent: AccentChoice) { coordinator.setAccent(accent); bump() }
    func setSize(_ value: Double) { coordinator.setHighlightSize(value); bump() }
    func setIntensity(_ value: Double) { coordinator.setHighlightIntensity(value); bump() }
    func setLensDim(_ value: Double) { coordinator.setLensDim(value); bump() }
    func setOptions(_ edit: (inout HighlightOptions) -> Void) { coordinator.setHighlightOptions(edit); bump() }
    /// Pauses the global shortcuts while one is being recorded, so pressing it does not trigger it.
    /// A plain-text summary for a bug report: no names, no settings content.
    func diagnostics(version: String) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let displays = NSScreen.screens.map { "\(Int($0.frame.width))x\(Int($0.frame.height)) @\(Int($0.backingScaleFactor))x" }.joined(separator: ", ")
        return """
        \(Branding.appName) \(version)
        macOS \(os)
        Displays: \(displays)
        Scenes: \(settings.profiles.count), app rules: \(settings.appRules.count)
        Input Monitoring needed: \(needsInputMonitoring ? "yes" : "no")
        """
    }

    func resetAllSettings() { coordinator.resetAllSettings(); bump() }

    func suspendHotkeys(_ on: Bool) { coordinator.suspendHotkeys(on) }
    func setHideRules(_ edit: (inout HideRules) -> Void) { coordinator.setHideRules(edit); bump() }
    var hideReason: HideReason? { coordinator.hideReason }
    func setRipples(_ on: Bool) { coordinator.setClickRipples(on); bump() }
    func setCursorScale(_ scale: Double) { coordinator.setCursorScale(Float(scale)) }
    func setShakeSensitivity(_ value: Double) { coordinator.setShakeSensitivity(value); bump() }

    // MARK: Ink

    func setInkStyle(_ style: InkStyle) { coordinator.setInkStyle(style); bump() }
    func setInkColor(_ color: InkColor) { coordinator.setInkColor(color); bump() }
    func setInkCleanup(_ on: Bool) { coordinator.setInkCleanup(on); bump() }
    func setInkShapes(_ shapes: InkShapeSet) { coordinator.setInkShapes(shapes); bump() }
    func setInkFades(_ fades: Bool) { coordinator.setInkFades(fades); bump() }
    func setInkWidth(_ scale: Double) { coordinator.setInkWidth(scale); bump() }
    func setInkFade(_ seconds: Double) { coordinator.setInkFadeAfter(seconds); bump() }

    // MARK: Triggers

    func updateTriggers(_ edit: (inout TriggerSettings) -> Void) { coordinator.updateTriggers(edit); bump() }
    func requestInputMonitoring() { coordinator.requestInputMonitoring(); bump() }
    func refreshInputMonitoring() { coordinator.refreshInputMonitoring(); bump() }
    func markWelcomeSeen() { coordinator.markWelcomeSeen() }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case highlight, ink, triggers, profiles, displays, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highlight: "Look"
        case .ink: "Draw"
        case .triggers: "Keys"
        case .profiles: "Apps"
        case .displays: "Screens"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .highlight: "scope"
        case .ink: "scribble"
        case .triggers: "keyboard"
        case .profiles: "square.grid.2x2"
        case .displays: "display"
        case .about: "info.circle"
        }
    }
}

struct RunningApp: Equatable {
    let bundleID: String
    let name: String
}
