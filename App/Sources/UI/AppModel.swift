import AppKit
import BeaconCore
import SwiftUI

/// The bridge between the coordinator and the views. Views read settings from here and call its methods; every
/// change bumps `revision` so SwiftUI redraws. Holds no behavior of its own.
@MainActor
final class AppModel: ObservableObject {
    let coordinator: AppCoordinator
    @Published private(set) var revision = 0
    /// Set by the app delegate; opens the settings window on a page.
    var openSettings: (SettingsPage) -> Void = { _ in }
    var openWelcome: () -> Void = {}
    var quit: () -> Void = { NSApp.terminate(nil) }

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        coordinator.highlight.onChange = { [weak self] in self?.bump() }
        coordinator.ink.onChange = { [weak self] in self?.bump() }
        coordinator.onSizeChange = { [weak self] in self?.bump() }
        coordinator.onTriggersChange = { [weak self] in self?.bump() }
    }

    func bump() { revision += 1 }

    var settings: BeaconSettings { coordinator.settings.settings }
    var look: HighlightLook { settings.look }
    var isPaused: Bool { coordinator.isPaused }
    var needsInputMonitoring: Bool { coordinator.needsInputMonitoring }
    var failedHotkeys: [HotKeyAction] { coordinator.failedHotkeys }
    var cursorScale: Double { Double(coordinator.cursorSize.currentScale ?? 1) }

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
    func setRipples(_ on: Bool) { coordinator.setClickRipples(on); bump() }
    func setCursorScale(_ scale: Double) { coordinator.setCursorScale(Float(scale)) }
    func setShakeSensitivity(_ value: Double) { coordinator.setShakeSensitivity(value); bump() }

    // MARK: Ink

    func setInkStyle(_ style: InkStyle) { coordinator.setInkStyle(style); bump() }
    func setInkColor(_ color: InkColor) { coordinator.setInkColor(color); bump() }
    func setInkCleanup(_ on: Bool) { coordinator.setInkCleanup(on); bump() }
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
        case .highlight: "Highlight"
        case .ink: "Ink and laser"
        case .triggers: "Triggers"
        case .profiles: "Profiles and apps"
        case .displays: "Displays"
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
