import XCTest
@testable import BeaconCore

final class ScenePresetTests: XCTestCase {
    func testPresetsAreDistinctAndValid() {
        XCTAssertEqual(Set(ScenePresets.all.map(\.key)).count, ScenePresets.all.count)
        XCTAssertEqual(Set(ScenePresets.all.map(\.name)).count, ScenePresets.all.count)
        for preset in ScenePresets.all {
            XCTAssertLessThanOrEqual(preset.name.count, Profile.maxNameLength)
            var s = BeaconSettings.defaults
            s.apply(preset.snapshot)
            XCTAssertEqual(s.sanitized().snapshot, preset.snapshot, "\(preset.name) holds only valid values")
        }
    }

    func testAddingAPresetTwiceKeepsNamesUnique() {
        var scenes = Profile.presets()
        let first = ScenePresets.scene(from: ScenePresets.all[0], existing: scenes)
        scenes.append(first)
        let second = ScenePresets.scene(from: ScenePresets.all[0], existing: scenes)
        XCTAssertEqual(first.name, "Teaching")
        XCTAssertEqual(second.name, "Teaching 2")
        XCTAssertNotEqual(first.id, second.id)
    }

    func testSceneFileRoundTrips() throws {
        let preset = ScenePresets.all[2]
        let data = try XCTUnwrap(SceneFile(name: preset.name, snapshot: preset.snapshot).encoded())
        let file = try XCTUnwrap(SceneFile.decode(data))
        XCTAssertEqual(file.snapshot, preset.snapshot)
        let scene = file.scene(existing: Profile.presets())
        XCTAssertEqual(scene.snapshot, preset.snapshot)
        XCTAssertTrue(scene.id.hasPrefix("custom-"))
    }

    func testImportRefusesOtherFilesAndNewerVersions() {
        XCTAssertNil(SceneFile.decode(Data("not json".utf8)))
        XCTAssertNil(SceneFile.decode(Data(#"{"format":"something-else","version":1,"name":"x","snapshot":{}}"#.utf8)))
        XCTAssertNil(SceneFile.decode(Data(#"{"format":"beacon-scene","version":99,"name":"x","snapshot":{}}"#.utf8)))
        XCTAssertNil(SceneFile.decode(Data(count: 300_000)))
    }

    func testImportClampsWildValuesAndLongNames() throws {
        let json = #"{"format":"beacon-scene","version":1,"name":"  An extremely long scene name that goes on and on  ","snapshot":{"highlightSize":99,"inkWidth":-5,"lensDim":7}}"#
        let file = try XCTUnwrap(SceneFile.decode(Data(json.utf8)))
        let scene = file.scene(existing: [])
        XCTAssertLessThanOrEqual(scene.name.count, Profile.maxNameLength)
        XCTAssertEqual(scene.snapshot.highlightSize, HighlightLook.sizeRange.upperBound)
        XCTAssertEqual(scene.snapshot.inkWidth, BeaconSettings.inkWidthRange.lowerBound)
        XCTAssertEqual(scene.snapshot.lensDim, HighlightLook.dimRange.upperBound)
    }
}

final class AppCategoryTests: XCTestCase {
    func testCategoriesRecognizeApps() {
        XCTAssertEqual(AppCategory.of("us.zoom.xos"), .calls)
        XCTAssertEqual(AppCategory.of("com.apple.dt.Xcode"), .editors)
        XCTAssertEqual(AppCategory.of("com.jetbrains.intellij"), .editors, "prefix match")
        XCTAssertEqual(AppCategory.of("company.thebrowser.Browser"), .browsers)
        XCTAssertEqual(AppCategory.of("org.videolan.vlc"), .video)
        XCTAssertNil(AppCategory.of("com.example.unknown"))
    }

    func testCategoryRuleAppliesWhenTheAppHasNoRuleOfItsOwn() {
        var s = BeaconSettings.defaults
        s.categoryRules = [CategoryRule(category: .browsers, profileID: "meeting")]
        let rules = s.effectiveRules(frontBundleID: "com.google.Chrome")
        XCTAssertEqual(rules.last?.profileID, "meeting")
        XCTAssertEqual(s.effectiveRules(frontBundleID: "com.apple.finder"), s.appRules)
        XCTAssertEqual(s.effectiveRules(frontBundleID: nil), s.appRules)
    }

    func testARuleForOneAppBeatsItsCategory() {
        var s = BeaconSettings.defaults
        s.categoryRules = [CategoryRule(category: .browsers, profileID: "meeting")]
        s.appRules = [AppRule(bundleID: "com.google.Chrome", appName: "Chrome", profileID: "recording")]
        let rules = s.effectiveRules(frontBundleID: "com.google.Chrome")
        XCTAssertEqual(rules, s.appRules, "no extra rule is added")
    }

    func testOffCategoryAndCleanupOfDeletedScenes() throws {
        var s = BeaconSettings.defaults
        s.categoryRules = [CategoryRule(category: .video, profileID: nil), CategoryRule(category: .calls, profileID: "gone")]
        let clean = s.sanitized()
        XCTAssertEqual(clean.categoryRules.map(\.category), [.video], "off stays, a rule for a missing scene goes")
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded.categoryRules.count, 2)
    }
}
