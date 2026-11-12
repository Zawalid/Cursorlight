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
    let settings: SettingsStore
    let highlight: HighlightController
    let ink: InkController
    let cursorSize: CursorSizeController

    /// Called after the cursor size changes, so the menu can refresh its checkmark.
    var onSizeChange: (() -> Void)?
    /// Called after pause state or trigger settings change, so the menu can refresh.
    var onTriggersChange: (() -> Void)?
    private(set) var isPaused = false

    init(cursorSize: CursorSizeController, settings: SettingsStore = SettingsStore()) {
        self.cursorSize = cursorSize
        self.settings = settings
        let current = settings.settings
        shake = ShakeRecognizer(sensitivity: current.shakeSensitivity)
        router = TriggerRouter(settings: current.triggers)
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
        router.isPaused = paused
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
        modifiers.stop()
        hotkeys.unregisterAll()
        ink.stop()
        highlight.stop()
        overlays.stop()
    }
}
