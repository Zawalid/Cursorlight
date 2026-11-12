import AppKit
import BeaconCore
import SwiftUI

/// Every page is a native grouped Form, the same structure System Settings uses, so spacing, row heights, controls and
/// light and dark all come from the system.

enum Swatches {
    static func fill(for accent: AccentChoice) -> AnyShapeStyle {
        if let color = accent.color { return AnyShapeStyle(Color(rgba: color)) }
        return AnyShapeStyle(AngularGradient(colors: [.purple, .orange, .red, .blue, .teal, .purple], center: .center))
    }
}

/// A row of selectable thumbnails inside a form section, with a line about the chosen one underneath.
struct TileRow<Item: Hashable, Thumb: View>: View {
    let items: [Item]
    let selection: Item
    let title: (Item) -> String
    let select: (Item) -> Void
    @ViewBuilder let thumbnail: (Item) -> Thumb

    var body: some View {
        HStack(spacing: 12) {
            ForEach(items, id: \.self) { item in
                let on = item == selection
                Button { select(item) } label: {
                    VStack(spacing: 7) {
                        thumbnail(item)
                            .frame(height: 62).frame(maxWidth: .infinity)
                            .background(Theme.stage, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(on ? Theme.accent : Color.clear, lineWidth: 2.5))
                        Text(title(item)).font(.system(size: 12, weight: on ? .semibold : .regular)).foregroundStyle(on ? Theme.text : Theme.dim)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private extension View {
    /// A form row that is just content: no inset, no background.
    func bareRow() -> some View {
        self.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
    }

    func page() -> some View {
        self.formStyle(.grouped).scrollContentBackground(.hidden).background(Theme.window)
    }
}

// MARK: Look

struct LookPage: View {
    @EnvironmentObject private var model: AppModel
    private var settings: BeaconSettings { model.settings }

    var body: some View {
        VStack(spacing: 0) {
            Stage(style: settings.highlightStyle, look: settings.look)
                .frame(height: 250)
                .padding(.horizontal, 22).padding(.top, 8)
            form
        }
        .background(Theme.window)
    }

    private var form: some View {
        Form {
            Section {
                TileRow(
                    items: HighlightStyle.allCases, selection: settings.highlightStyle, title: { $0.displayName },
                    select: { model.setStyle($0) }
                ) { StyleThumbnail(style: $0) }
            } header: {
                Text("Style")
            } footer: {
                Text(Self.blurb(settings.highlightStyle))
            }
            Section("Appearance") {
                LabeledContent("Color") {
                    HStack(spacing: 0) {
                        ForEach(AccentChoice.allCases, id: \.self) { accent in
                            SwatchButton(fill: Swatches.fill(for: accent), isSelected: settings.accent == accent, label: accent.displayName) {
                                model.setAccent(accent)
                            }
                        }
                    }
                }
                LabeledContent("Size") {
                    Slider(value: Binding(get: { settings.highlightSize }, set: { model.setSize($0) }), in: HighlightLook.sizeRange).frame(width: 200)
                }
                if settings.highlightStyle == .lens {
                    LabeledContent("Screen dim") {
                        Slider(value: Binding(get: { settings.lensDim }, set: { model.setLensDim($0) }), in: HighlightLook.dimRange).frame(width: 200)
                    }
                } else {
                    LabeledContent("Intensity") {
                        Slider(value: Binding(get: { settings.highlightIntensity }, set: { model.setIntensity($0) }), in: HighlightLook.intensityRange)
                            .frame(width: 200).disabled(settings.accent == .highContrast)
                    }
                }
            }
            Section("Behavior") {
                Toggle("Click ripples", isOn: Binding(get: { settings.clickRipples }, set: { model.setRipples($0) }))
                Picker("Pointer size", selection: Binding(get: { Self.nearest(model.cursorScale) }, set: { model.setCursorScale($0) })) {
                    Text("1x").tag(1.0); Text("1.5x").tag(1.5); Text("2x").tag(2.0); Text("3x").tag(3.0)
                }
                .pickerStyle(.segmented).fixedSize()
            }
        }
        .page()
    }

    private static func blurb(_ style: HighlightStyle) -> String {
        switch style {
        case .aura: "A soft light that follows you and breathes when you stop."
        case .lens: "Dims the whole screen except a circle around the pointer."
        case .comet: "A bright head with a tail, so viewers can follow fast movement."
        case .keyline: "A thin two-tone ring that stays readable on any background."
        case .sonar: "Rings pulse in and lock onto the pointer, then a small dot stays."
        }
    }

    private static func nearest(_ scale: Double) -> Double {
        [1.0, 1.5, 2.0, 3.0].min { abs($0 - scale) < abs($1 - scale) } ?? 1
    }
}

// MARK: Draw

struct InkPage: View {
    @EnvironmentObject private var model: AppModel
    private var settings: BeaconSettings { model.settings }

    var body: some View {
        VStack(spacing: 0) {
            InkPreview(style: settings.inkStyle, color: settings.inkColor, cleanup: settings.inkCleanup, fade: settings.inkFadeAfter)
                .padding(.horizontal, 22).padding(.top, 8)
            form
        }
        .background(Theme.window)
    }

    private var form: some View {
        Form {
            Section("Pen") {
                TileRow(
                    items: InkStyle.allCases, selection: settings.inkStyle, title: { $0.displayName },
                    select: { model.setInkStyle($0) }
                ) { InkSwatchStroke(style: $0, color: settings.inkColor) }
                LabeledContent("Color") {
                    HStack(spacing: 0) {
                        ForEach(InkColor.allCases, id: \.self) { color in
                            SwatchButton(fill: AnyShapeStyle(Color(rgba: color.rgba)), isSelected: settings.inkColor == color, label: color.displayName) {
                                model.setInkColor(color)
                            }
                        }
                    }
                }
            }
            Section {
                Toggle("Clean up shapes", isOn: Binding(get: { settings.inkCleanup }, set: { model.setInkCleanup($0) }))
                LabeledContent("Fade after") {
                    HStack(spacing: 10) {
                        Slider(value: Binding(get: { settings.inkFadeAfter }, set: { model.setInkFade($0) }), in: BeaconSettings.inkFadeRange).frame(width: 180)
                        Text(String(format: "%.1f s", settings.inkFadeAfter)).monospacedDigit().foregroundStyle(Theme.dim).frame(width: 44, alignment: .trailing)
                    }
                }
            } header: {
                Text("Behavior")
            } footer: {
                Text("Circles, rectangles, lines, underlines and arrows straighten themselves when you let go. Press 1 to 5 while drawing to change color.")
            }
            Section {
                LabeledContent("Draw now") {
                    Button(model.isOn(.ink) ? "Stop" : "Start") { model.toggle(.ink) }
                }
            } footer: {
                Text("Or use the Ink trigger on the Keys page.")
            }
        }
        .page()
    }
}

// MARK: Keys

struct TriggersPage: View {
    @EnvironmentObject private var model: AppModel
    private var triggers: TriggerSettings { model.settings.triggers }

    private static let effects: [EffectKind] = EffectKind.allCases
    private static let keys: [ModifierKey] = ModifierKey.allCases

    var body: some View {
        Form {
            Section {
                row("Shake the pointer", enabled: Binding(get: { triggers.shakeEnabled }, set: { v in model.updateTriggers { $0.shakeEnabled = v } })) {
                    effectPicker(Binding(get: { triggers.shakeAction }, set: { v in model.updateTriggers { $0.shakeAction = v } }))
                }
                row("Double-tap a key", enabled: Binding(get: { triggers.doubleTapEnabled }, set: { v in model.updateTriggers { $0.doubleTapEnabled = v } })) {
                    keyPicker(Binding(get: { triggers.doubleTapKey }, set: { v in model.updateTriggers { $0.doubleTapKey = v } }))
                    effectPicker(Binding(get: { triggers.doubleTapAction }, set: { v in model.updateTriggers { $0.doubleTapAction = v } }))
                }
                row("Hold a key", enabled: Binding(get: { triggers.holdEnabled }, set: { v in model.updateTriggers { $0.holdEnabled = v } })) {
                    keyPicker(Binding(get: { triggers.holdKey }, set: { v in model.updateTriggers { $0.holdKey = v } }))
                    effectPicker(Binding(get: { triggers.holdAction }, set: { v in model.updateTriggers { $0.holdAction = v } }))
                }
                LabeledContent("Shake sensitivity") {
                    Slider(value: Binding(get: { model.settings.shakeSensitivity }, set: { model.setShakeSensitivity($0) }), in: 0...100).frame(width: 180)
                }
            } header: {
                Text("Gestures")
            } footer: {
                Text(model.needsInputMonitoring
                     ? "Double-tap and hold need Input Monitoring to see the key while another app is in front. Shake and shortcuts work without it."
                     : "Double-tap and hold work in every app.")
            }
            if model.needsInputMonitoring {
                Section {
                    LabeledContent {
                        Button("Allow Input Monitoring") { model.requestInputMonitoring() }
                    } label: {
                        Label("One permission is missing", systemImage: "exclamationmark.triangle").foregroundStyle(Theme.warn)
                    }
                }
            }
            Section {
                Toggle("Keyboard shortcuts", isOn: Binding(get: { triggers.hotkeysEnabled }, set: { v in model.updateTriggers { $0.hotkeysEnabled = v } }))
                ForEach(HotKeyAction.allCases, id: \.self) { action in
                    LabeledContent(action.displayName) {
                        HStack(spacing: 4) {
                            if model.failedHotkeys.contains(action) && triggers.hotkeysEnabled {
                                Text("Taken by another app").font(.system(size: 12)).foregroundStyle(Theme.warn).padding(.trailing, 6)
                            }
                            ForEach(Self.caps(for: triggers.hotkey(for: action)), id: \.self) { Keycap(text: $0) }
                        }
                    }
                }
            } header: {
                Text("Keyboard")
            } footer: {
                Text("Shortcuts work in every app and need no permission.")
            }
        }
        .page()
        .onAppear { model.refreshInputMonitoring() }
    }

    private func row<Content: View>(_ title: String, enabled: Binding<Bool>, @ViewBuilder _ content: () -> Content) -> some View {
        LabeledContent {
            HStack(spacing: 8) {
                content().disabled(!enabled.wrappedValue)
                Toggle("", isOn: enabled).toggleStyle(.switch).labelsHidden()
            }
        } label: {
            Text(title)
        }
    }

    private func effectPicker(_ selection: Binding<EffectKind>) -> some View {
        Picker("", selection: selection) { ForEach(Self.effects, id: \.self) { Text($0.displayName).tag($0) } }
            .pickerStyle(.menu).labelsHidden().fixedSize()
    }

    private func keyPicker(_ selection: Binding<ModifierKey>) -> some View {
        Picker("", selection: selection) { ForEach(Self.keys, id: \.self) { Text($0.displayName).tag($0) } }
            .pickerStyle(.menu).labelsHidden().fixedSize()
    }

    static func caps(for key: HotKey?) -> [String] {
        guard let key else { return ["Not set"] }
        var caps: [String] = []
        var rest = Substring(key.displayString)
        while let first = rest.first, "⌃⌥⇧⌘".contains(first) {
            caps.append(String(first))
            rest = rest.dropFirst()
        }
        if !rest.isEmpty { caps.append(String(rest)) }
        return caps
    }
}

// MARK: Apps

struct ProfilesPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(model.profiles) { profile in
                    Button { model.chooseProfile(profile.id) } label: {
                        HStack {
                            Text(profile.name)
                            Spacer()
                            Text(profile.summary).foregroundStyle(Theme.dim)
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                .opacity(model.appliedProfileID == profile.id ? 1 : 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if model.profiles.count > 1 { Button("Delete \(profile.name)", role: .destructive) { model.deleteProfile(profile.id) } }
                    }
                }
                Button("Save Current Look as New Scene") { model.addProfile() }
            } header: {
                Text("Scenes")
            } footer: {
                Text("A scene is a saved set of look and drawing choices. Changes you make on the other pages are saved to the active scene.")
            }
            Section {
                ForEach(model.settings.appRules) { rule in
                    LabeledContent(rule.appName) {
                        HStack {
                            Picker("", selection: Binding(get: { rule.profileID ?? "" }, set: { model.setRule(rule, profileID: $0.isEmpty ? nil : $0) })) {
                                ForEach(model.profiles) { Text($0.name).tag($0.id) }
                                Divider()
                                Text("Off").tag("")
                            }
                            .labelsHidden().fixedSize()
                            Button { model.removeRule(rule) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).help("Remove this rule")
                        }
                    }
                }
                Button("Add App…") { model.addRuleFromPanel() }
            } header: {
                Text("App Rules")
            } footer: {
                Text("When one of these apps is in front, Beacon switches scene or turns off. A scene you pick by hand wins until you switch to another app.")
            }
        }
        .page()
    }
}

// MARK: Screens

struct DisplaysPage: View {
    @EnvironmentObject private var model: AppModel
    private var screens: [NSScreen] { NSScreen.screens }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .bottom, spacing: 18) {
                    Spacer()
                    ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                        let aspect = screen.frame.height / max(screen.frame.width, 1)
                        let shown = model.displayScope == .all || index == 0
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.stage)
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(shown ? Theme.accent : Theme.line, lineWidth: 2))
                                .frame(width: 180, height: 180 * aspect)
                            Text(index == 0 ? "\(screen.localizedName) (main)" : screen.localizedName)
                                .font(.system(size: 11)).foregroundStyle(Theme.dim)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                Picker("Show effects on", selection: Binding(get: { model.displayScope }, set: { model.setDisplayScope($0) })) {
                    ForEach(DisplayScope.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Displays")
            } footer: {
                Text("The main display is the one with the menu bar.")
            }
            Section {
                let info = ShareStatusInfo(model.shareStatus)
                Label { Text(info.title) } icon: { Image(systemName: info.symbol).foregroundStyle(info.tint) }
                Text(info.body).foregroundStyle(Theme.dim)
                Picker("I am sharing", selection: Binding(get: { model.declaredShare }, set: { model.declareShare($0) })) {
                    Text("Nothing").tag(DeclaredShare?.some(.notSharing))
                    Text("The whole screen").tag(DeclaredShare?.some(.wholeScreen))
                    Text("One window").tag(DeclaredShare?.some(.singleWindow))
                }
            } header: {
                Text("Sharing")
            } footer: {
                Text("Beacon cannot tell what you share, so it asks. Viewers only see effects when you share the whole screen.")
            }
        }
        .page()
    }
}

// MARK: About

struct AboutPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { LaunchAtLogin.set($0); launchAtLogin = LaunchAtLogin.isEnabled }))
                    .disabled(!LaunchAtLogin.isAvailable)
            } header: {
                Text(Branding.appName)
            }
            Section {
                Toggle("Check for updates automatically", isOn: Binding(get: { model.automaticUpdateChecks }, set: { model.setAutomaticUpdateChecks($0) }))
                    .disabled(!model.updatesConfigured)
                Button("Check Now") { model.checkForUpdates() }
            } header: {
                Text("Updates")
            } footer: {
                Text(model.updatesConfigured ? "Asks GitHub once a day. Nothing installs without your OK." : "This build has no update signing key yet.")
            }
            Section {
                Button("Show Welcome Guide") { model.openWelcome() }
            } footer: {
                Text("No accounts and no analytics. The network is used only for update checks, once they exist.")
            }
        }
        .page()
    }
}
