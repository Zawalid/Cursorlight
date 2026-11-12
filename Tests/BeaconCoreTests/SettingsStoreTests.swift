import XCTest
@testable import BeaconCore

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "beacon.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testFreshStoreReturnsDefaults() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings, BeaconSettings.defaults)
        XCTAssertEqual(store.settings.highlightStyle, .aura)
        XCTAssertTrue(store.settings.clickRipples)
        XCTAssertEqual(store.settings.shakeSensitivity, 50)
    }

    func testUpdatePersistsAcrossInstances() {
        let store = SettingsStore(defaults: defaults)
        store.update { $0.highlightStyle = .sonar; $0.clickRipples = false; $0.shakeSensitivity = 80 }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.highlightStyle, .sonar)
        XCTAssertFalse(reloaded.settings.clickRipples)
        XCTAssertEqual(reloaded.settings.shakeSensitivity, 80)
    }

    func testUpdateNotifiesOnlyWhenValueChanges() {
        let store = SettingsStore(defaults: defaults)
        var calls = 0
        store.onChange = { _ in calls += 1 }
        store.update { $0.highlightStyle = .lens }
        store.update { $0.highlightStyle = .lens }
        XCTAssertEqual(calls, 1)
    }

    func testSensitivityIsClamped() {
        let store = SettingsStore(defaults: defaults)
        store.update { $0.shakeSensitivity = 500 }
        XCTAssertEqual(store.settings.shakeSensitivity, 100)
        store.update { $0.shakeSensitivity = -3 }
        XCTAssertEqual(store.settings.shakeSensitivity, 0)
        store.update { $0.shakeSensitivity = .nan }
        XCTAssertEqual(store.settings.shakeSensitivity, 50)
    }

    func testMigratesLegacyKeysOnce() {
        defaults.set("comet", forKey: "highlightStyle")
        defaults.set(false, forKey: "clickRipples")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.highlightStyle, .comet)
        XCTAssertFalse(store.settings.clickRipples)
        XCTAssertNil(defaults.object(forKey: "highlightStyle"))
        XCTAssertNil(defaults.object(forKey: "clickRipples"))
        let again = SettingsStore(defaults: defaults)
        XCTAssertEqual(again.settings.highlightStyle, .comet)
    }

    func testCorruptDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: SettingsStore.storageKey)
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings, BeaconSettings.defaults)
    }

    func testNewerSchemaVersionIsKeptReadableWithMissingFields() throws {
        let json = #"{"version":1,"highlightStyle":"keyline"}"#
        defaults.set(Data(json.utf8), forKey: SettingsStore.storageKey)
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.highlightStyle, .keyline)
        XCTAssertTrue(store.settings.clickRipples)
    }

    func testLookSettingsPersistAndClamp() {
        let store = SettingsStore(defaults: defaults)
        store.update { $0.accent = .teal; $0.highlightSize = 5; $0.highlightIntensity = 0.6; $0.lensDim = 0.7 }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.accent, .teal)
        XCTAssertEqual(reloaded.settings.highlightSize, HighlightLook.sizeRange.upperBound, accuracy: 0.0001)
        XCTAssertEqual(reloaded.settings.look.intensity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(reloaded.settings.look.lensDim, 0.7, accuracy: 0.0001)
    }

    func testInkSettingsPersist() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.inkStyle, .marker)
        store.update { $0.inkStyle = .neon; $0.inkColor = .green; $0.inkCleanup = false }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.inkStyle, .neon)
        XCTAssertEqual(reloaded.settings.inkColor, .green)
        XCTAssertFalse(reloaded.settings.inkCleanup)
    }
}
