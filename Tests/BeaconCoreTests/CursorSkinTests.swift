import Foundation
import CoreGraphics
import Testing
@testable import BeaconCore

struct CursorSkinTests {
    @Test func systemDesignRendersNothing() {
        #expect(CursorSkinRenderer.render(CursorSkinSettings(design: .system)) == nil)
    }

    @Test func everyDesignRendersFourScales() throws {
        for design in CursorDesign.allCases where design != .system {
            let skin = try #require(CursorSkinRenderer.render(CursorSkinSettings(design: design)))
            #expect(skin.images.count == 4)
            #expect(skin.size == CGSize(width: 32, height: 32))
            #expect(skin.images.map(\.width) == [32, 64, 96, 128])
        }
    }

    @Test func tipDesignsClickAtTheTipAndOthersAtTheCenter() throws {
        let classic = try #require(CursorSkinRenderer.render(CursorSkinSettings(design: .classic)))
        #expect(classic.hotspot == CGPoint(x: 4, y: 3))
        let ring = try #require(CursorSkinRenderer.render(CursorSkinSettings(design: .ring)))
        #expect(ring.hotspot == CGPoint(x: 16, y: 16))
    }

    @Test func sizeScalesTheImageAndHotspot() throws {
        let skin = try #require(CursorSkinRenderer.render(CursorSkinSettings(design: .classic, size: 2)))
        #expect(skin.size == CGSize(width: 64, height: 64))
        #expect(skin.hotspot == CGPoint(x: 8, y: 6))
    }

    @Test func designsActuallyDrawPixels() throws {
        for design in CursorDesign.allCases where design != .system {
            let skin = try #require(CursorSkinRenderer.render(CursorSkinSettings(design: design)))
            let image = skin.images[1]
            let data = try #require(image.dataProvider?.data)
            let bytes = CFDataGetBytePtr(data)
            var opaque = 0
            for i in stride(from: 3, to: CFDataGetLength(data), by: 4) where bytes?[i] ?? 0 > 200 { opaque += 1 }
            #expect(opaque > 40, "\(design) drew too little")
        }
    }

    @Test func settingsDecodeToleratesBadValues() throws {
        let json = #"{"design":"nope","color":"zzz","size":99}"#.data(using: .utf8) ?? Data()
        let decoded = try JSONDecoder().decode(CursorSkinSettings.self, from: json)
        #expect(decoded.design == .system)
        #expect(decoded.color == nil)
        #expect(decoded.size == CursorSkinSettings.sizeRange.upperBound)
    }

    @Test func customColorWinsOverDefault() {
        let s = CursorSkinSettings(design: .bolt, color: "#112233")
        #expect(s.resolvedColor.hexString == "#112233")
        #expect(CursorSkinSettings(design: .bolt).resolvedColor == CursorDesign.bolt.defaultColor)
    }

    @Test func oldSettingsWithoutSkinDecode() throws {
        let decoded = try JSONDecoder().decode(BeaconSettings.self, from: Data("{}".utf8))
        #expect(decoded.cursorSkin == CursorSkinSettings())
    }
}

@MainActor
private final class FakeReplacer: CursorReplacing {
    var isAvailable = true
    var shown: [CursorSkinImage] = []
    var clears = 0
    var accept = true
    func show(_ skin: CursorSkinImage) -> Bool { shown.append(skin); return accept }
    func clear() { clears += 1 }
}

@MainActor
struct CursorSkinControllerTests {
    @Test func appliesAndClears() {
        let fake = FakeReplacer()
        let controller = CursorSkinController(replacer: fake)
        controller.apply(CursorSkinSettings(design: .star))
        #expect(fake.shown.count == 1)
        controller.apply(CursorSkinSettings(design: .system))
        #expect(fake.clears == 1)
        #expect(!controller.failed)
    }

    @Test func pausedGivesThePointerBack() {
        let fake = FakeReplacer()
        let controller = CursorSkinController(replacer: fake)
        controller.apply(CursorSkinSettings(design: .star), paused: true)
        #expect(fake.shown.isEmpty)
        #expect(fake.clears == 1)
    }

    @Test func refusalIsReported() {
        let fake = FakeReplacer()
        fake.accept = false
        let controller = CursorSkinController(replacer: fake)
        controller.apply(CursorSkinSettings(design: .heart))
        #expect(controller.failed)
    }
}

struct CursorSkinSceneTests {
    @Test func theSkinTravelsWithTheScene() {
        var settings = BeaconSettings.defaults
        settings.cursorSkin = CursorSkinSettings(design: .ghost, color: "#112233", size: 1.5)
        let snapshot = settings.snapshot
        #expect(snapshot.cursorSkin.design == .ghost)
        var other = BeaconSettings.defaults
        other.apply(snapshot)
        #expect(other.cursorSkin == settings.cursorSkin)
    }

    @Test func aSceneWithoutASkinGivesTheSystemPointerBack() {
        var settings = BeaconSettings.defaults
        settings.cursorSkin = CursorSkinSettings(design: .bolt)
        settings.apply(ProfileSnapshot())
        #expect(settings.cursorSkin.design == .system)
    }

    @Test func oldSceneFilesWithoutASkinStillDecode() throws {
        let snapshot = try JSONDecoder().decode(ProfileSnapshot.self, from: Data("{}".utf8))
        #expect(snapshot.cursorSkin == CursorSkinSettings())
    }
}
