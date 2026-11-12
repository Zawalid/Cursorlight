import XCTest
@testable import BeaconCore

final class ProfileSwitcherTests: XCTestCase {
    private let known: Set<String> = ["stream", "meeting", "recording"]
    private let zoom = AppRule(bundleID: "us.zoom.xos", appName: "Zoom", profileID: "meeting")
    private let keynote = AppRule(bundleID: "com.apple.iWork.Keynote", appName: "Keynote", profileID: nil)

    func testNoRuleKeepsBaseProfile() {
        var s = ProfileSwitcher(base: "stream")
        s.frontmostChanged(to: "com.apple.finder")
        XCTAssertEqual(s.selection(rules: [zoom], knownProfiles: known), .profile("stream"))
    }

    func testRuleAppliesAfterFrontmostChange() {
        var s = ProfileSwitcher(base: "stream")
        s.frontmostChanged(to: "us.zoom.xos")
        XCTAssertEqual(s.selection(rules: [zoom], knownProfiles: known), .profile("meeting"))
        s.frontmostChanged(to: "com.apple.finder")
        XCTAssertEqual(s.selection(rules: [zoom], knownProfiles: known), .profile("stream"))
    }

    func testManualChoiceWinsUntilFrontmostChanges() {
        var s = ProfileSwitcher(base: "stream")
        s.frontmostChanged(to: "us.zoom.xos")
        s.chooseManually("recording")
        XCTAssertEqual(s.selection(rules: [zoom], knownProfiles: known), .profile("recording"))
        s.frontmostChanged(to: "us.zoom.xos")
        XCTAssertEqual(s.selection(rules: [zoom], knownProfiles: known), .profile("recording"), "same app: still held")
        s.frontmostChanged(to: "com.apple.finder")
        XCTAssertEqual(s.selection(rules: [zoom], knownProfiles: known), .profile("recording"), "base is now recording")
        s.frontmostChanged(to: "us.zoom.xos")
        XCTAssertEqual(s.selection(rules: [zoom], knownProfiles: known), .profile("meeting"))
    }

    func testDisabledRuleTurnsEverythingOff() {
        var s = ProfileSwitcher(base: "stream")
        s.frontmostChanged(to: "com.apple.iWork.Keynote")
        XCTAssertEqual(s.selection(rules: [keynote], knownProfiles: known), .off)
    }

    func testRuleForDeletedProfileIsIgnored() {
        var s = ProfileSwitcher(base: "stream")
        s.frontmostChanged(to: "us.zoom.xos")
        XCTAssertEqual(s.selection(rules: [zoom], knownProfiles: ["stream"]), .profile("stream"))
    }

    func testNilFrontmostUsesBase() {
        var s = ProfileSwitcher(base: "meeting")
        s.frontmostChanged(to: nil)
        XCTAssertEqual(s.selection(rules: [zoom, keynote], knownProfiles: known), .profile("meeting"))
    }
}

final class ProfileSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() {
        super.setUp()
        suite = "beacon.profile.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDefaultsHaveThreePresetsWithStreamFirst() {
        let s = BeaconSettings.defaults
        XCTAssertEqual(s.profiles.map(\.name), ["Stream", "Meeting", "Recording"])
        XCTAssertEqual(s.baseProfileID, "stream")
        XCTAssertEqual(s.profiles[0].snapshot, s.snapshot)
    }

    func testProfilesRoundTripThroughStore() {
        let store = SettingsStore(defaults: defaults)
        store.update {
            $0.profiles.append(Profile(id: "mine", name: "Mine", snapshot: ProfileSnapshot(highlightStyle: .lens)))
            $0.appRules = [AppRule(bundleID: "a.b", appName: "AB", profileID: "mine")]
            $0.displayScope = .mainOnly
        }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.profiles.last?.snapshot.highlightStyle, .lens)
        XCTAssertEqual(reloaded.settings.appRules.first?.profileID, "mine")
        XCTAssertEqual(reloaded.settings.displayScope, .mainOnly)
    }

    func testLiveProfileFollowsEdits() {
        let store = SettingsStore(defaults: defaults)
        store.liveProfileID = "meeting"
        store.update { $0.highlightStyle = .comet; $0.clickRipples = false }
        let meeting = store.settings.profiles.first { $0.id == "meeting" }
        XCTAssertEqual(meeting?.snapshot.highlightStyle, .comet)
        XCTAssertEqual(meeting?.snapshot.clickRipples, false)
        XCTAssertEqual(store.settings.profiles.first { $0.id == "stream" }?.snapshot.highlightStyle, .aura)
    }

    func testApplySnapshotCopiesEveryField() {
        var s = BeaconSettings.defaults
        let snap = ProfileSnapshot(highlightStyle: .sonar, accent: .teal, highlightSize: 1.4, highlightIntensity: 0.6, lensDim: 0.3, clickRipples: false, inkStyle: .neon, inkColor: .green, inkCleanup: false, inkFadeAfter: 4)
        s.apply(snap)
        XCTAssertEqual(s.snapshot, snap)
    }

    func testSettingsWithoutProfilesMigrateCurrentLookIntoStream() throws {
        let json = #"{"version":1,"highlightStyle":"lens","highlightSize":1.5}"#
        defaults.set(Data(json.utf8), forKey: SettingsStore.storageKey)
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.profiles.first?.snapshot.highlightStyle, .lens)
        XCTAssertEqual(store.settings.profiles.first?.snapshot.highlightSize ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(store.settings.profiles.count, 3)
    }

    func testUnknownBaseProfileFallsBackToFirst() {
        let store = SettingsStore(defaults: defaults)
        store.update { $0.baseProfileID = "ghost" }
        XCTAssertEqual(store.settings.baseProfileID, "stream")
    }

    func testSummaryDescribesStyleAndSize() {
        XCTAssertEqual(Profile(id: "x", name: "X", snapshot: ProfileSnapshot(highlightStyle: .lens, highlightSize: 1.5)).summary, "Lens, large")
    }
}

final class SceneListTests: XCTestCase {
    private func scenes(_ names: [String]) -> [Profile] {
        names.map { Profile(id: $0.lowercased(), name: $0, snapshot: ProfileSnapshot()) }
    }

    func testCopyNameAddsCopyThenNumbers() {
        let list = scenes(["Meeting"])
        XCTAssertEqual(Profile.copyName(of: "Meeting", existing: list), "Meeting copy")
        let withCopy = scenes(["Meeting", "Meeting copy"])
        XCTAssertEqual(Profile.copyName(of: "Meeting", existing: withCopy), "Meeting copy 2")
    }

    func testCopyNameStaysWithinTheLimit() {
        let long = String(repeating: "x", count: Profile.maxNameLength)
        let name = Profile.copyName(of: long, existing: scenes([long]))
        XCTAssertLessThanOrEqual(name.count, Profile.maxNameLength)
        let second = Profile.copyName(of: long, existing: scenes([long]) + scenes([name]))
        XCTAssertLessThanOrEqual(second.count, Profile.maxNameLength)
        XCTAssertNotEqual(name, second)
    }

    func testMoveBeforeTarget() {
        let list = scenes(["A", "B", "C", "D"])
        XCTAssertEqual(Profile.reordered(list, moving: "d", before: "b").map(\.name), ["A", "D", "B", "C"])
        XCTAssertEqual(Profile.reordered(list, moving: "a", before: "d").map(\.name), ["B", "C", "A", "D"])
    }

    func testMoveToEndWhenNoTarget() {
        let list = scenes(["A", "B", "C"])
        XCTAssertEqual(Profile.reordered(list, moving: "a", before: nil).map(\.name), ["B", "C", "A"])
    }

    func testMoveIgnoresUnknownAndSelf() {
        let list = scenes(["A", "B"])
        XCTAssertEqual(Profile.reordered(list, moving: "zzz", before: "a"), list)
        XCTAssertEqual(Profile.reordered(list, moving: "a", before: "zzz"), list)
        XCTAssertEqual(Profile.reordered(list, moving: "a", before: "a"), list)
    }

    func testHighlightColorFollowsAccentThenStyle() {
        var scene = Profile(id: "x", name: "X", snapshot: ProfileSnapshot(highlightStyle: .sonar))
        XCTAssertEqual(scene.highlightColor, Palette.accent(for: .sonar))
        scene.snapshot.accent = .blue
        XCTAssertEqual(scene.highlightColor, RGBA(hex: "#4DA3FF"))
    }
}
