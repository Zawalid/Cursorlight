import AppKit
import CursorlightCore
import SwiftUI

/// Visual check without a screen: with CURSORLIGHT_SNAPSHOT_DIR set, renders each page to a PNG there and quits.
/// Needs no Screen Recording permission because nothing is captured from the screen.
@MainActor
enum SnapshotRunner {
    static var directory: String? { ProcessInfo.processInfo.environment["CURSORLIGHT_SNAPSHOT_DIR"] }

    static func run(into directory: String) {
        let suite = "cursorlight.snapshot.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        let coordinator = AppCoordinator(
            cursorSize: CursorSizeController(scaling: SystemCursorScale(), markers: UserDefaultsScaleMarker(defaults: defaults)),
            settings: SettingsStore(defaults: defaults)
        )
        coordinator.setAppRule(AppRule(bundleID: "us.zoom.xos", appName: "Zoom", profileID: "meeting"))
        coordinator.setAppRule(AppRule(bundleID: "com.apple.iWork.Keynote", appName: "Keynote", profileID: nil))
        let model = AppModel(coordinator: coordinator, updater: AppUpdater(startingUpdater: false))
        for page in SettingsPage.allCases {
            for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
                renderWindowed(
                    SettingsView(page: page).environmentObject(model).tint(Theme.accent), size: CGSize(width: 1040, height: 720),
                    appearance: appearance, name: "settings-\(page.rawValue)-\(name)", into: directory
                )
            }
        }
        for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            renderWindowed(LookPage().environmentObject(model).tint(Theme.accent), size: CGSize(width: 780, height: 720), appearance: appearance, name: "page-look-\(name)", into: directory)
            renderWindowed(TriggersPage().environmentObject(model).tint(Theme.accent), size: CGSize(width: 780, height: 720), appearance: appearance, name: "page-keys-\(name)", into: directory)
        }
        for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            renderWindowed(PopoverView().environmentObject(model).background(Theme.window), size: CGSize(width: 360, height: 560), appearance: appearance, name: "popover-\(name)", into: directory)
            let icons = HStack(spacing: 26) {
                ForEach([MenuBarIconState.idle, .active, .paused], id: \.self) { state in
                    Image(nsImage: MenuBarIcon.image(state, color: appearance == .darkAqua ? .white : .black)).resizable().frame(width: 100, height: 90)
                }
            }.padding(24).background(appearance == .darkAqua ? Color(white: 0.16) : Color(white: 0.93))
            renderWindowed(icons, size: CGSize(width: 440, height: 140), appearance: appearance, name: "menubar-icon-\(name)", into: directory)
        }
        let states: [(String, GuideStep, GuideView.Phase, Bool)] = [
            ("guide-1-intro", .intro, .waiting, false), ("guide-2-shake", .shake, .waiting, false), ("guide-2-shake-done", .shake, .success, false),
            ("guide-3-laser", .laser, .waiting, false), ("guide-4-ink", .ink, .waiting, false), ("guide-4-ink-drawing", .ink, .waiting, true),
            ("guide-5-done", .done, .waiting, false),
        ]
        for (name, step, phase, inkSeen) in states {
            let guide = GuideView(startAt: step, phase: phase, inkSeen: inkSeen, autonomous: false, finish: {})
            let framed = ZStack { Color(red: 0.16, green: 0.15, blue: 0.2); guide.environmentObject(model) }.frame(width: step.panelSize.width, height: step.panelSize.height)
            renderWindowed(framed, size: step.panelSize, name: name, into: directory, settle: 1.2)
        }
        for step in [GuideStep.shake, .laser, .ink] {
            let state = IllustrationState()
            state.step = step
            let framed = ZStack { Color(red: 0.86, green: 0.87, blue: 0.9); IllustrationRoot(state: state) }.frame(width: 620, height: 360)
            renderWindowed(framed, size: CGSize(width: 620, height: 360), name: "illustration-\(step.rawValue)", into: directory, settle: 1.1)
        }
        // Marketing sheets: every highlight style on the demo desktop, and the pointer skins.
        for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            let styles = LazyVGrid(columns: Array(repeating: GridItem(.fixed(600), spacing: 14), count: 3), spacing: 14) {
                ForEach(HighlightStyle.allCases, id: \.self) { style in
                    VStack(alignment: .leading, spacing: 6) {
                        PreviewCanvas(style: style, look: .standard, height: 420).frame(width: 600, height: 420).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(style.displayName).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    }
                }
            }.padding(24).background(Theme.window)
            renderWindowed(styles, size: CGSize(width: 1890, height: 960), appearance: appearance, name: "styles-\(name)", into: directory, settle: 1.0)
            renderWindowed(CursorSkinRow(settings: CursorSkinSettings(design: .bolt), available: true, edit: { _ in }).padding(24).frame(width: 760).background(Theme.window), size: CGSize(width: 760, height: 330), appearance: appearance, name: "skins-\(name)", into: directory, settle: 0.8)
        }
        defaults.removePersistentDomain(forName: suite)
    }

    /// Renders in a real but never-shown window, so native controls (switch, slider, menus) draw as they do on screen.
    private static func renderWindowed<V: View>(_ view: V, size: CGSize, appearance: NSAppearance.Name = .darkAqua, name: String, into directory: String, settle: TimeInterval = 0.5) {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        window.close()
    }

    private static func render<V: View>(_ view: V, name: String, into directory: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { NSLog("snapshot failed: \(name)"); return }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
}
