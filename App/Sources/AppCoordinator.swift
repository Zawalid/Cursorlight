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
    let spotlight: SpotlightController
    let cursorSize: CursorSizeController
    let cursorSkin = CursorSkinController(replacer: SkyLightCursorReplacer())
    let shareSafe = ShareSafeMonitor()
    private let keyMonitor = KeyActivityMonitor()
    /// The keys the display shows right now.
    private(set) var keystrokeBuffer = KeystrokeBuffer()
    /// Called after a key was added to the buffer, so the display can show.
    var onKeystroke: (() -> Void)?

    /// Called after the cursor size changes, so the menu can refresh its checkmark.
    var onSizeChange: (() -> Void)?
    /// Called after pause state or trigger settings change, so the menu can refresh.
    var onTriggersChange: (() -> Void)?
    /// Set by the app delegate; runs the timer parts of a link.
    var onTimerLink: ((BeaconLinkCommand) -> Void)?
    /// Set by the app delegate; shows or hides the timer chip.
    var onToggleTimer: (() -> Void)?
    /// Called when the share status changes.
    var onShareChange: (() -> Void)?
    private(set) var isPaused = false
    /// True while Beacon is off for the frontmost app: a per-app rule, or a hide rule such as full screen.
    private(set) var isOffForApp = false
    private var profileOff = false
    /// Why a hide rule has switched Beacon off right now, if one has.
    private(set) var hideReason: HideReason?
    private var spaceObserver: NSObjectProtocol?
    /// The last app that was frontmost other than Beacon itself.
    private var frontBundleID: String?
    private var motionObserver: NSObjectProtocol?

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
        ink.setWidthScale(current.inkWidth)
        ink.setCustomColor(current.inkCustom.map { RGBA(hex: $0) })
        ink.setShapes(current.inkShapes)
        ink.setFades(current.inkFades)
        spotlight = SpotlightController(overlays: overlays)
        spotlight.setStyle(current.look.options.spotlight)
        // The overlay manager has one hook; both controllers follow window changes through it.
        overlays.onWindowsChanged = { [weak self] in
            self?.highlight.windowsChanged()
            self?.ink.windowsChanged()
            self?.spotlight.windowsChanged()
        }
    }

    func start() {
        // Diagnostic: BEACON_DISABLE=overlays,monitors,triggers,extras (or all) switches parts off to find which one breaks clicks.
        let off = Set((ProcessInfo.processInfo.environment["BEACON_DISABLE"] ?? "").split(separator: ",").map(String.init))
        let all = off.contains("all")
        if !(all || off.contains("overlays")) {
            overlays.start()
            highlight.start()
            ink.start()
            spotlight.start()
        }
        if !(all || off.contains("monitors")) {
            tracker.onMove = { [weak self] position, time in
                self?.pointerMoved(to: position, at: time)
            }
            tracker.start()
            clicks.onButton = { [weak self] button, isDown, position in
                self?.highlight.mouseButton(button, isDown: isDown, at: position)
                self?.playClickSound(isDown: isDown)
            }
            clicks.start()
        }
        if !(all || off.contains("triggers")) {
            hotkeys.onPress = { [weak self] action in self?.handle(.hotkey(action)) }
            modifiers.onEvent = { [weak self] event in self?.handle(event) }
            applyTriggers()
        }
        if !(all || off.contains("extras")) {
            cursorSkin.apply(settings.settings.cursorSkin)
            keyMonitor.onKey = { [weak self] press in self?.handleKey(press) }
            applyKeyMonitoring()
            applyDisplayScope()
            shareSafe.onChange = { [weak self] in self?.onShareChange?() }
            shareSafe.start()
            frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            switcher.frontmostChanged(to: frontBundleID)
            workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let bundle = app?.bundleIdentifier
                MainActor.assumeIsolated { self?.frontmostAppChanged(to: bundle) }
            }
            spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                // Entering full screen animates; look again once the window has settled.
                MainActor.assumeIsolated { self?.updateHideReason() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { MainActor.assumeIsolated { self?.updateHideReason() } }
            }
            reevaluateProfile()
            updateHideReason()
            motionObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in MainActor.assumeIsolated { self?.applyLook() } }
        }
    }

    // MARK: Profiles

    private func frontmostAppChanged(to bundleID: String?) {
        // Using Beacon's own windows must not switch profiles.
        guard bundleID != Bundle.main.bundleIdentifier else { return }
        frontBundleID = bundleID
        switcher.frontmostChanged(to: bundleID)
        reevaluateProfile()
        updateHideReason()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.updateHideReason() }
    }

    /// Applies whatever the switcher selects: a profile, or off for this app.
    private func reevaluateProfile() {
        let current = settings.settings
        let selection = switcher.selection(rules: current.effectiveRules(frontBundleID: frontBundleID), knownProfiles: Set(current.profiles.map(\.id)))
        switch selection {
        case let .profile(id):
            profileOff = false
            if id != appliedProfileID { applyProfile(id) }
        case .off:
            profileOff = true
        }
        refreshOff()
        onTriggersChange?()
    }

    /// Recomputes the hide rules for the frontmost app: full screen and video players.
    func updateHideReason() {
        let rules = settings.settings.hideRules
        let front = NSWorkspace.shared.frontmostApplication
        var reason: HideReason?
        // Beacon's own windows never hide effects: that is where they are set up.
        if let front, front.bundleIdentifier != Bundle.main.bundleIdentifier, rules.isActive {
            reason = rules.reason(
                frontBundleID: front.bundleIdentifier,
                frontIsFullScreen: rules.fullScreenApps && Self.isFullScreen(pid: front.processIdentifier)
            )
        }
        guard reason != hideReason else { return }
        hideReason = reason
        refreshOff()
        onTriggersChange?()
    }

    private static func isFullScreen(pid: pid_t) -> Bool {
        let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
        let windows: [WindowSnapshot] = list.compactMap { entry in
            guard let owner = entry[kCGWindowOwnerPID as String] as? Int32,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  let dict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict) else { return nil }
            return WindowSnapshot(ownerPID: owner, layer: layer, bounds: bounds)
        }
        let displays: [CGRect] = NSScreen.screens.compactMap { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDisplayBounds($0.uint32Value) }
        }
        return FullScreenDetector.isFullScreen(pid: pid, windows: windows, displays: displays)
    }

    private func refreshOff() {
        setOffForApp(profileOff || hideReason != nil)
    }

    private func setOffForApp(_ off: Bool) {
        guard off != isOffForApp else { return }
        isOffForApp = off
        router.isPaused = isPaused || off
        if off {
            highlight.setOn(false)
            highlight.setLaser(false)
            ink.deactivate()
            spotlight.clear()
        }
    }

    private func applyProfile(_ id: String) {
        guard let profile = settings.settings.profiles.first(where: { $0.id == id }) else { return }
        settings.liveProfileID = nil
        settings.update { $0.apply(profile.snapshot) }
        let current = settings.settings
        highlight.setStyle(current.highlightStyle)
        highlight.setLook(effectiveLook)
        spotlight.setStyle(current.look.options.spotlight)
        highlight.setRipplesEnabled(current.clickRipples)
        ink.setStyle(current.inkStyle)
        ink.setColor(current.inkColor)
        ink.setCleanupEnabled(current.inkCleanup)
        ink.setFadeAfter(current.inkFadeAfter)
        ink.setWidthScale(current.inkWidth)
        ink.setCustomColor(current.inkCustom.map { RGBA(hex: $0) })
        ink.setShapes(current.inkShapes)
        ink.setFades(current.inkFades)
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

    /// Copies a scene next to the original and switches to the copy.
    func duplicateProfile(_ id: String) {
        let existing = settings.settings.profiles
        guard let source = existing.first(where: { $0.id == id }) else { return }
        let copyID = "custom-\(UUID().uuidString.prefix(8).lowercased())"
        let copy = Profile(id: copyID, name: Profile.copyName(of: source.name, existing: existing), snapshot: source.snapshot)
        settings.update { s in
            let index = s.profiles.firstIndex(where: { $0.id == id }).map { $0 + 1 } ?? s.profiles.count
            s.profiles.insert(copy, at: index)
        }
        chooseProfile(copyID)
    }

    /// Moves a scene to sit just before another, or to the end when `target` is nil.
    func moveProfile(_ id: String, before target: String?) {
        settings.update { $0.profiles = Profile.reordered($0.profiles, moving: id, before: target) }
    }

    /// Adds a finished scene (from a preset or an imported file) and switches to it.
    func addProfile(_ profile: Profile) {
        settings.update { $0.profiles.append(profile) }
        chooseProfile(profile.id)
    }

    func renameProfile(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.update { s in
            if let index = s.profiles.firstIndex(where: { $0.id == id }) { s.profiles[index].name = String(trimmed.prefix(Profile.maxNameLength)) }
        }
    }

    func deleteProfile(_ id: String) {
        guard settings.settings.profiles.count > 1 else { return }
        let wasLive = settings.liveProfileID == id
        if wasLive { settings.liveProfileID = nil }
        settings.update { s in
            s.profiles.removeAll { $0.id == id }
            // Apps that used this scene go back to the default scene; a nil profile would switch Beacon off for them.
            s.appRules.removeAll { $0.profileID == id }
            s.categoryRules.removeAll { $0.profileID == id }
        }
        let remaining = settings.settings
        if switcher.base == id { switcher.setBase(remaining.baseProfileID) }
        if appliedProfileID == id { appliedProfileID = nil }
        reevaluateProfile()
    }

    /// Sets, changes or (with `none`) removes the rule for a kind of app.
    func setCategoryRule(_ category: AppCategory, profileID: String?, none: Bool) {
        settings.update { s in
            s.categoryRules.removeAll { $0.category == category }
            if !none { s.categoryRules.append(CategoryRule(category: category, profileID: profileID)) }
        }
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
        spotlight.setWindowFilter(filter)
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
        case .nextScene:
            cycleScene()
        case .clearInk:
            ink.clearAll()
        case .toggleToolbar:
            setToolbar { $0.enabled.toggle() }
        case .spotlight:
            spotlight.cycle()
        case .timer:
            onToggleTimer?()
        case .whiteboard:
            if ink.isActive, ink.board != .none { ink.deactivate() } else { ink.activateBoard(.white) }
        }
    }

    func setToolbar(_ edit: (inout ToolbarSettings) -> Void) {
        settings.update { edit(&$0.toolbar) }
        onTriggersChange?()
    }

    func undoInk() { ink.undo() }
    func clearInk() { ink.clearAll() }

    /// Switches to the next scene in the list, wrapping around.
    private func resolve(_ choice: BeaconLinkCommand.Switch, current: Bool) -> Bool {
        switch choice {
        case .on: true
        case .off: false
        case .toggle: !current
        }
    }

    /// Runs what a `beacon://` link asked for, if links are allowed.
    func runLink(_ command: BeaconLinkCommand) {
        guard settings.settings.allowLinks else { return }
        switch command {
        case let .highlight(choice): highlight.setOn(resolve(choice, current: highlight.isOn))
        case let .laser(choice): highlight.setLaser(resolve(choice, current: highlight.isLaserOn))
        case let .ink(choice):
            if resolve(choice, current: ink.isActive) { if !ink.isActive { ink.activate(takesKey: true) } } else { ink.deactivate() }
        case let .spotlight(choice):
            let want = resolve(choice, current: spotlight.isOn)
            if want, !spotlight.isOn { spotlight.cycle() } else if !want { spotlight.clear() }
        case let .pause(choice): setPaused(resolve(choice, current: isPaused))
        case let .toolbar(choice): setToolbar { $0.enabled = resolve(choice, current: $0.enabled) }
        case .timerToggle, .timerStop, .timerStart: onTimerLink?(command)
        case let .whiteboard(board):
            if board == .none { if ink.board != .none { ink.deactivate() } } else { ink.activateBoard(board) }
        case .clearInk: ink.clearAll()
        case .undoInk: ink.undo()
        case .nextScene: cycleScene()
        case let .scene(name):
            if let match = settings.settings.profiles.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { chooseProfile(match.id) }
        case let .penColor(color): setInkColor(color)
        case let .penTool(tool): ink.setTool(tool)
        }
        onTriggersChange?()
    }

    func setAllowLinks(_ allow: Bool) {
        settings.update { $0.allowLinks = allow }
        onTriggersChange?()
    }

    func cycleScene() {
        let ids = settings.settings.profiles.map(\.id)
        guard ids.count > 1 else { return }
        let current = appliedProfileID ?? settings.settings.baseProfileID
        let next = ids[((ids.firstIndex(of: current) ?? -1) + 1) % ids.count]
        chooseProfile(next)
        onTriggersChange?()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        router.isPaused = paused || isOffForApp
        if paused {
            highlight.setOn(false)
            highlight.setLaser(false)
            ink.deactivate()
            spotlight.clear()
        }
        onTriggersChange?()
    }

    /// Puts every setting back to how Beacon starts, keeping only that the welcome was seen.
    func resetAllSettings() {
        let seen = settings.settings.welcomeSeen
        settings.liveProfileID = nil
        settings.update {
            $0 = BeaconSettings.defaults
            $0.welcomeSeen = seen
        }
        switcher.setBase(settings.settings.baseProfileID)
        applyProfile(settings.settings.baseProfileID)
        applyTriggers()
        applyDisplayScope()
        updateHideReason()
    }

    func suspendHotkeys(_ on: Bool) {
        if on { hotkeys.unregisterAll() } else { applyTriggers() }
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
        let gestures = (t.doubleTapEnabled || t.holdEnabled) && !modifiers.hasGlobalAccess
        let keys = wantsKeyMonitoring && !keyMonitor.hasGlobalAccess
        return gestures || keys
    }

    /// The keystroke display, key sound and hide-while-typing all listen to the keyboard.
    private var wantsKeyMonitoring: Bool {
        let s = settings.settings
        return s.keystrokes.enabled || s.keystrokes.sound || s.highlightOptions.hideWhileTyping
    }

    /// Starts or stops the keyboard listener to match what is switched on.
    func applyKeyMonitoring() {
        if wantsKeyMonitoring { keyMonitor.start() } else { keyMonitor.stop() }
        if !settings.settings.keystrokes.enabled { keystrokeBuffer.clear() }
    }

    private func handleKey(_ press: KeyPress) {
        guard !isPaused, !isOffForApp else { return }
        let s = settings.settings
        highlight.typed()
        if s.keystrokes.enabled {
            keystrokeBuffer.push(press, shortcutsOnly: s.keystrokes.shortcutsOnly, at: ProcessInfo.processInfo.systemUptime)
            onKeystroke?()
        }
        if s.keystrokes.sound, !press.isRepeat, let sound = NSSound(named: NSSound.Name("Pop")) {
            sound.volume = 0.25
            sound.play()
        }
    }

    func setKeystrokes(_ edit: (inout KeystrokeSettings) -> Void) {
        settings.update { edit(&$0.keystrokes) }
        applyKeyMonitoring()
        onTriggersChange?()
    }

    func refreshInputMonitoring() {
        modifiers.refreshAccess()
        keyMonitor.refreshAccess()
    }

    func requestInputMonitoring() {
        if InputMonitoring.isGranted {
            modifiers.refreshAccess()
            keyMonitor.refreshAccess()
        } else {
            InputMonitoring.request()
            InputMonitoring.openSettings()
        }
    }

    private var lastDisplay: CGDirectDisplayID?

    private func playClickSound(isDown: Bool) {
        guard isDown, highlight.ripplesEnabled, settings.settings.highlightOptions.clickSound, !isOffForApp, !isPaused else { return }
        NSSound(named: NSSound.Name("Tink"))?.play()
    }

    /// Reads the system "Reduce motion" setting into the look, when the user asked Beacon to follow it.
    private var effectiveLook: HighlightLook {
        let look = settings.settings.look
        return look.options.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? look.reducingMotion() : look
    }

    private func pointerMoved(to position: CGPoint, at time: TimeInterval) {
        let display = NSScreen.screens.first { $0.frame.contains(position) }.flatMap { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value }
        if let display, let last = lastDisplay, display != last, settings.settings.highlightOptions.locatorPulse, !isOffForApp {
            highlight.locate(at: position)
        }
        if display != nil { lastDisplay = display }
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

    func setHighlightOptions(_ edit: (inout HighlightOptions) -> Void) {
        settings.update { edit(&$0.highlightOptions) }
        applyLook()
        applyKeyMonitoring()
    }

    func setHideRules(_ edit: (inout HideRules) -> Void) {
        settings.update { edit(&$0.hideRules) }
        updateHideReason()
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
        highlight.setLook(effectiveLook)
        spotlight.setStyle(settings.settings.look.options.spotlight)
    }

    func toggleInk() {
        if ink.isActive { ink.deactivate() } else { ink.activate(takesKey: true) }
    }

    func setInkStyle(_ style: InkStyle) {
        ink.setStyle(style)
        settings.update { $0.inkStyle = style }
    }

    /// Picking a preset pen color clears any custom one.
    func setInkColor(_ color: InkColor) {
        ink.setColor(color)
        ink.setCustomColor(nil)
        settings.update { $0.inkColor = color; $0.inkCustom = nil }
    }

    func setInkCustom(_ hex: String) {
        guard RGBA.isValidHex(hex) else { return }
        settings.update { $0.inkCustom = hex.hasPrefix("#") ? hex : "#" + hex }
        ink.setCustomColor(settings.settings.inkCustom.map { RGBA(hex: $0) })
    }

    func setInkShapes(_ shapes: InkShapeSet) {
        settings.update { $0.inkShapes = shapes }
        ink.setShapes(settings.settings.inkShapes)
    }

    func setInkFades(_ fades: Bool) {
        settings.update { $0.inkFades = fades }
        ink.setFades(fades)
    }

    func setInkWidth(_ scale: Double) {
        settings.update { $0.inkWidth = scale }
        ink.setWidthScale(settings.settings.inkWidth)
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

    func setCursorSkin(_ edit: (inout CursorSkinSettings) -> Void) {
        settings.update { edit(&$0.cursorSkin) }
        cursorSkin.apply(settings.settings.cursorSkin)
    }

    func shutdown() {
        cursorSkin.stop()
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
