import AppKit
import BeaconCore

/// Owns the live pieces (overlays, pointer and button tracking, the highlight, cursor size).
@MainActor
final class AppCoordinator {
    private let overlays = OverlayManager(screens: SystemScreens())
    private let tracker = CursorTracker()
    private let clicks = ClickMonitor()
    private var shake: ShakeRecognizer
    private let hotkeys = CarbonHotKeys()
    private let modifiers = ModifierGestureMonitor()
    private var router: TriggerRouter
    private var switcher: ProfileSwitcher
    private(set) var appliedProfileID: String?
    private var workspaceObserver: NSObjectProtocol?
    let settings: SettingsStore
    let highlight: HighlightController
    let ink: InkController
    let cursorSize: CursorSizeController
    let shareSafe = ShareSafeMonitor()

    /// Called after the cursor size changes, so the menu can refresh its checkmark.
    var onSizeChange: (() -> Void)?
    /// Called after pause state or trigger settings change, so the menu can refresh.
    var onTriggersChange: (() -> Void)?
    /// Called when the share status changes.
    var onShareChange: (() -> Void)?
    private(set) var isPaused = false
    /// True while a per-app rule has switched Beacon off for the frontmost app.
    private(set) var isOffForApp = false

    init(cursorSize: CursorSizeController, settings: SettingsStore = SettingsStore()) {
        self.cursorSize = cursorSize
        self.settings = settings
        let current = settings.settings
        shake = ShakeRecognizer(sensitivity: current.shakeSensitivity)
        router = TriggerRouter(settings: current.triggers)
        switcher = ProfileSwitcher(base: current.baseProfileID)
        highlight = HighlightController(
            overlays: overlays,
            style: current.highlightStyle,
            ripplesEnabled: current.clickRipples,
            look: current.look
        )
        ink = InkController(
            overlays: overlays, style: current.inkStyle, color: current.inkColor, cleanupEnabled: current.inkCleanup,
            fadeAfter: current.inkFadeAfter
        )
        // The overlay manager has one hook; both controllers follow window changes through it.
        overlays.onWindowsChanged = { [weak self] in
            self?.highlight.windowsChanged()
            self?.ink.windowsChanged()
        }
    }

    func start() {
        overlays.start()
        highlight.start()
        ink.start()
        tracker.onMove = { [weak self] position, time in
            self?.pointerMoved(to: position, at: time)
        }
        tracker.start()
        clicks.onButton = { [weak self] button, isDown, position in
            self?.highlight.mouseButton(button, isDown: isDown, at: position)
        }
        clicks.start()
        hotkeys.onPress = { [weak self] action in self?.handle(.hotkey(action)) }
        modifiers.onEvent = { [weak self] event in self?.handle(event) }
        applyTriggers()
        applyDisplayScope()
        shareSafe.onChange = { [weak self] in self?.onShareChange?() }
        shareSafe.start()
        switcher.frontmostChanged(to: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundle = app?.bundleIdentifier
            MainActor.assumeIsolated { self?.frontmostAppChanged(to: bundle) }
        }
        reevaluateProfile()
    }

    // MARK: Profiles

    private func frontmostAppChanged(to bundleID: String?) {
        // Using Beacon's own windows must not switch profiles.
        guard bundleID != Bundle.main.bundleIdentifier else { return }
        switcher.frontmostChanged(to: bundleID)
        reevaluateProfile()
    }

    /// Applies whatever the switcher selects: a profile, or off for this app.
    private func reevaluateProfile() {
        let current = settings.settings
        let selection = switcher.selection(rules: current.appRules, knownProfiles: Set(current.profiles.map(\.id)))
        switch selection {
        case let .profile(id):
            setOffForApp(false)
            if id != appliedProfileID { applyProfile(id) }
        case .off:
            setOffForApp(true)
        }
        onTriggersChange?()
    }

    private func setOffForApp(_ off: Bool) {
        guard off != isOffForApp else { return }
        isOffForApp = off
        router.isPaused = isPaused || off
        if off {
            highlight.setOn(false)
            highlight.setLaser(false)
            ink.deactivate()
        }
    }

    private func applyProfile(_ id: String) {
        guard let profile = settings.settings.profiles.first(where: { $0.id == id }) else { return }
        settings.liveProfileID = nil
        settings.update { $0.apply(profile.snapshot) }
        let current = settings.settings
        highlight.setStyle(current.highlightStyle)
        highlight.setLook(current.look)
        highlight.setRipplesEnabled(current.clickRipples)
        ink.setStyle(current.inkStyle)
        ink.setColor(current.inkColor)
        ink.setCleanupEnabled(current.inkCleanup)
        ink.setFadeAfter(current.inkFadeAfter)
        settings.liveProfileID = id
        appliedProfileID = id
    }

    /// The user picked a profile: it wins until the frontmost app changes.
    func chooseProfile(_ id: String) {
        guard settings.settings.profiles.contains(where: { $0.id == id }) else { return }
        settings.update { $0.baseProfileID = id }
        switcher.chooseManually(id)
        reevaluateProfile()
    }

    /// Saves the current look as a new profile and switches to it.
    func addProfile() {
        let existing = settings.settings.profiles
        var number = 1
        while existing.contains(where: { $0.name == "Custom \(number)" }) { number += 1 }
        let id = "custom-\(UUID().uuidString.prefix(8).lowercased())"
        let profile = Profile(id: id, name: "Custom \(number)", snapshot: settings.settings.snapshot)
        settings.update { $0.profiles.append(profile) }
        chooseProfile(id)
    }

    func deleteProfile(_ id: String) {
        guard settings.settings.profiles.count > 1 else { return }
        let wasLive = settings.liveProfileID == id
        if wasLive { settings.liveProfileID = nil }
        settings.update { s in
            s.profiles.removeAll { $0.id == id }
            for index in s.appRules.indices where s.appRules[index].profileID == id { s.appRules[index].profileID = nil }
        }
        let remaining = settings.settings
        if switcher.base == id { switcher.setBase(remaining.baseProfileID) }
        if appliedProfileID == id { appliedProfileID = nil }
        reevaluateProfile()
    }

    func setAppRule(_ rule: AppRule) {
        settings.update { s in
            if let index = s.appRules.firstIndex(where: { $0.bundleID == rule.bundleID }) {
                s.appRules[index] = rule
            } else {
                s.appRules.append(rule)
            }
        }
        reevaluateProfile()
    }

    func removeAppRule(bundleID: String) {
        settings.update { $0.appRules.removeAll { $0.bundleID == bundleID } }
        reevaluateProfile()
    }

    func setDisplayScope(_ scope: DisplayScope) {
        settings.update { $0.displayScope = scope }
        applyDisplayScope()
        onTriggersChange?()
    }

    private func applyDisplayScope() {
        let scope = settings.settings.displayScope
        let filter: @MainActor (OverlayWindow) -> Bool = { window in
            scope == .all || window.displayID == CGMainDisplayID()
        }
        highlight.setWindowFilter(filter)
        ink.setWindowFilter(filter)
    }

    // MARK: Triggers

    private func handle(_ event: TriggerEvent) {
        let active = ActiveEffects(inkActive: ink.isActive, laserOn: highlight.isLaserOn)
        for command in router.route(event, active: active) { perform(command) }
    }

    private func perform(_ command: TriggerCommand) {
        switch command {
        case let .toggle(effect):
            switch effect {
            case .highlight: highlight.toggle()
            case .laser: highlight.setLaser(!highlight.isLaserOn)
            case .ink: toggleInk()
            case .none: break
            }
        case let .set(effect, on):
            switch effect {
            case .highlight: highlight.setOn(on)
            case .laser: highlight.setLaser(on)
            case .ink: if on { ink.activate(takesKey: false) } else { ink.deactivate() }
            case .none: break
            }
        case .togglePause:
            setPaused(!isPaused)
        }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        router.isPaused = paused || isOffForApp
        if paused {
            highlight.setOn(false)
            highlight.setLaser(false)
            ink.deactivate()
        }
        onTriggersChange?()
    }

    func updateTriggers(_ edit: (inout TriggerSettings) -> Void) {
        settings.update { edit(&$0.triggers) }
        applyTriggers()
    }

    /// Registers shortcuts and starts or stops the modifier monitor to match the settings.
    func applyTriggers() {
        let triggers = settings.settings.triggers
        router.settings = triggers
        if triggers.hotkeysEnabled {
            var keys: [HotKeyAction: HotKey] = [:]
            for action in HotKeyAction.allCases { keys[action] = triggers.hotkey(for: action) }
            hotkeys.register(keys)
        } else {
            hotkeys.unregisterAll()
        }
        if triggers.doubleTapEnabled || triggers.holdEnabled {
            modifiers.start()
        } else {
            modifiers.stop()
        }
        onTriggersChange?()
    }

    var failedHotkeys: [HotKeyAction] { hotkeys.failed }

    /// True when a modifier trigger is on but cannot see keys outside Beacon yet.
    var needsInputMonitoring: Bool {
        let t = settings.settings.triggers
        return (t.doubleTapEnabled || t.holdEnabled) && !modifiers.hasGlobalAccess
    }

    func refreshInputMonitoring() {
        modifiers.refreshAccess()
    }

    func requestInputMonitoring() {
        if InputMonitoring.isGranted {
            modifiers.refreshAccess()
        } else {
            InputMonitoring.request()
            InputMonitoring.openSettings()
        }
    }

    private func pointerMoved(to position: CGPoint, at time: TimeInterval) {
        highlight.pointerMoved()
        if shake.feed(position: position, time: time) {
            handle(.shake)
        }
    }

    func setAccent(_ accent: AccentChoice) {
        settings.update { $0.accent = accent }
        applyLook()
    }

    func setHighlightSize(_ size: Double) {
        settings.update { $0.highlightSize = size }
        applyLook()
    }

    func setHighlightIntensity(_ intensity: Double) {
        settings.update { $0.highlightIntensity = intensity }
        applyLook()
    }

    func setLensDim(_ dim: Double) {
        settings.update { $0.lensDim = dim }
        applyLook()
    }

    /// Menu toggle for the laser trail. A held-key trigger arrives with the trigger milestone.
    func toggleLaser() {
        highlight.setLaser(!highlight.isLaserOn)
    }

    private func applyLook() {
        highlight.setLook(settings.settings.look)
    }

    func toggleInk() {
        if ink.isActive { ink.deactivate() } else { ink.activate(takesKey: true) }
    }

    func setInkStyle(_ style: InkStyle) {
        ink.setStyle(style)
        settings.update { $0.inkStyle = style }
    }

    func setInkColor(_ color: InkColor) {
        ink.setColor(color)
        settings.update { $0.inkColor = color }
    }

    func setInkFadeAfter(_ seconds: Double) {
        settings.update { $0.inkFadeAfter = seconds }
        ink.setFadeAfter(settings.settings.inkFadeAfter)
    }

    func markWelcomeSeen() {
        settings.update { $0.welcomeSeen = true }
    }

    func setInkCleanup(_ enabled: Bool) {
        ink.setCleanupEnabled(enabled)
        settings.update { $0.inkCleanup = enabled }
    }

    func setShakeSensitivity(_ value: Double) {
        settings.update { $0.shakeSensitivity = value }
        shake = ShakeRecognizer(sensitivity: settings.settings.shakeSensitivity)
    }

    func toggleHighlight() {
        highlight.toggle()
    }

    /// Picking a style also turns the highlight on, so the choice is visible right away.
    func setHighlightStyle(_ style: HighlightStyle) {
        highlight.setStyle(style)
        highlight.setOn(true)
        settings.update { $0.highlightStyle = style }
    }

    func setClickRipples(_ enabled: Bool) {
        highlight.setRipplesEnabled(enabled)
        settings.update { $0.clickRipples = enabled }
    }

    func setCursorScale(_ scale: Float) {
        cursorSize.apply(scale)
        onSizeChange?()
    }

    func resetCursorScale() {
        cursorSize.reset()
        onSizeChange?()
    }

    func shutdown() {
        cursorSize.reset()
        tracker.onMove = nil
        tracker.stop()
        clicks.onButton = nil
        clicks.stop()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        workspaceObserver = nil
        shareSafe.stop()
        modifiers.stop()
        hotkeys.unregisterAll()
        ink.stop()
        highlight.stop()
        overlays.stop()
    }
}
