import BeaconCore
import SwiftUI

struct TriggersPage: View {
    @EnvironmentObject private var model: AppModel
    private var triggers: TriggerSettings { model.settings.triggers }

    private static let effects: [(value: EffectKind, title: String)] = EffectKind.allCases.map { ($0, $0.displayName) }
    private static let keys: [(value: ModifierKey, title: String)] = ModifierKey.allCases.map { ($0, $0.displayName) }

    var body: some View {
        VStack(spacing: 18) {
            PageHeader(title: "Triggers", subtitle: "How you summon each effect. Every trigger can be turned off or pointed at another effect.")

            SettingsGroup {
                SettingRow(title: "Shake the pointer", subtitle: "Wiggle it side to side") {
                    HStack(spacing: 12) {
                        BeaconMenu(options: Self.effects, selection: Binding(get: { triggers.shakeAction }, set: { v in model.updateTriggers { $0.shakeAction = v } }))
                        BeaconToggle(isOn: Binding(get: { triggers.shakeEnabled }, set: { v in model.updateTriggers { $0.shakeEnabled = v } }))
                    }
                }
                SettingRow(title: "Double-tap a key", subtitle: "Two quick taps, nothing else pressed") {
                    HStack(spacing: 12) {
                        BeaconMenu(options: Self.keys, selection: Binding(get: { triggers.doubleTapKey }, set: { v in model.updateTriggers { $0.doubleTapKey = v } }), width: 120)
                        BeaconMenu(options: Self.effects, selection: Binding(get: { triggers.doubleTapAction }, set: { v in model.updateTriggers { $0.doubleTapAction = v } }), width: 100)
                        BeaconToggle(isOn: Binding(get: { triggers.doubleTapEnabled }, set: { v in model.updateTriggers { $0.doubleTapEnabled = v } }))
                    }
                }
                SettingRow(title: "Hold a key", subtitle: "Active while it is down, stops when you let go", showsDivider: false) {
                    HStack(spacing: 12) {
                        BeaconMenu(options: Self.keys, selection: Binding(get: { triggers.holdKey }, set: { v in model.updateTriggers { $0.holdKey = v } }), width: 120)
                        BeaconMenu(options: Self.effects, selection: Binding(get: { triggers.holdAction }, set: { v in model.updateTriggers { $0.holdAction = v } }), width: 100)
                        BeaconToggle(isOn: Binding(get: { triggers.holdEnabled }, set: { v in model.updateTriggers { $0.holdEnabled = v } }))
                    }
                }
            }

            if model.needsInputMonitoring {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Double-tap and hold need one permission").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.warn)
                        Text("Input Monitoring lets Beacon see the key while another app is in front. Shake and shortcuts work without it.")
                            .font(.system(size: 12)).foregroundStyle(Theme.warn.opacity(0.8))
                    }
                    Spacer()
                    Button("Allow") { model.requestInputMonitoring() }.buttonStyle(PrimaryButtonStyle())
                }
                .padding(14)
                .background(Theme.warn.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.warn.opacity(0.25)))
            }

            SettingsGroup {
                SettingRow(title: "Keyboard shortcuts", subtitle: "Work in every app, no permission needed") {
                    BeaconToggle(isOn: Binding(get: { triggers.hotkeysEnabled }, set: { v in model.updateTriggers { $0.hotkeysEnabled = v } }))
                }
                ForEach(Array(HotKeyAction.allCases.enumerated()), id: \.element) { index, action in
                    SettingRow(
                        title: action.displayName,
                        subtitle: model.failedHotkeys.contains(action) && triggers.hotkeysEnabled ? "Taken by another app" : nil,
                        showsDivider: true
                    ) {
                        HStack(spacing: 4) {
                            ForEach(Self.caps(for: triggers.hotkey(for: action)), id: \.self) { Keycap(text: $0) }
                        }
                    }
                }
                SettingRow(title: "Shake sensitivity", showsDivider: false) {
                    BeaconSlider(value: Binding(get: { model.settings.shakeSensitivity }, set: { model.setShakeSensitivity($0) }), range: 0...100)
                }
            }
        }
        .onAppear { model.refreshInputMonitoring() }
    }

    static func caps(for key: HotKey?) -> [String] {
        guard let key else { return ["Not set"] }
        let text = key.displayString
        // The display string is modifier symbols followed by the key name; show each as its own keycap.
        var caps: [String] = []
        var rest = Substring(text)
        while let first = rest.first, "⌃⌥⇧⌘".contains(first) {
            caps.append(String(first))
            rest = rest.dropFirst()
        }
        if !rest.isEmpty { caps.append(String(rest)) }
        return caps
    }
}
