import AppKit
import QuartzCore
import XCTest

@testable import BeaconCore

/// Fixed displays for renderer tests.
@MainActor
final class TestScreens: ScreenProviding {
    let displayIDs: [CGDirectDisplayID]
    init(_ ids: [CGDirectDisplayID]) { displayIDs = ids }
    var changes: AsyncStream<Void> { AsyncStream { _ in } }
    func frame(for displayID: CGDirectDisplayID) -> CGRect? { CGRect(x: 0, y: 0, width: 800, height: 600) }
}

@MainActor
final class FixedKindDetector: CursorKindDetecting {
    var kind: CursorKind?
    init(_ kind: CursorKind? = .arrow) { self.kind = kind }
    func currentKind() -> CursorKind? { kind }
}

private func alpha(of image: CGImage, atPixel point: CGPoint) -> UInt8 {
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(
            data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    guard drawn else { return 0 }
    // The bitmap's first row is the top of the image.
    let x = min(max(Int(point.x), 0), image.width - 1)
    let y = min(max(Int(point.y), 0), image.height - 1)
    return pixels[(y * image.width + x) * 4 + 3]
}

@MainActor
final class SkinTests: XCTestCase {
    func testEverySkinHasAllCursorKinds() throws {
        let skins = BuiltInSkins.all
        XCTAssertTrue((5...6).contains(skins.count))
        XCTAssertEqual(Set(skins.map(\.id)).count, skins.count, "skin ids are unique")
        XCTAssertEqual(Set(skins.map(\.name)).count, skins.count, "skin names are unique")
        for skin in skins {
            for kind in CursorKind.allCases {
                let hotspot = try XCTUnwrap(skin.hotspot[kind], "\(skin.id) \(kind) hotspot")
                let size = skin.canvasSize(for: kind)
                XCTAssertGreaterThan(size.width, 0)
                XCTAssertTrue(CGRect(origin: .zero, size: size).contains(hotspot), "\(skin.id) \(kind) hotspot inside canvas")
                let one = try XCTUnwrap(skin.image(for: kind, scale: 1), "\(skin.id) \(kind) @1x")
                let two = try XCTUnwrap(skin.image(for: kind, scale: 2), "\(skin.id) \(kind) @2x")
                XCTAssertEqual(one.width, Int(size.width.rounded(.up)))
                XCTAssertEqual(two.width, one.width * 2, "\(skin.id) \(kind) renders crisply at 2x, not upscaled")
                XCTAssertEqual(two.height, one.height * 2)
            }
        }
    }

    func testArtworkCoversTheHotspot() throws {
        // The visible art must sit on the hotspot, otherwise clicks land somewhere the user is not pointing.
        for skin in BuiltInSkins.all {
            for kind in CursorKind.allCases {
                let scale: CGFloat = 2
                let image = try XCTUnwrap(skin.image(for: kind, scale: scale))
                let hotspot = try XCTUnwrap(skin.hotspot[kind])
                // Sample just inside the shape from the hotspot (arrow and hand tips point up-left / up).
                let nudge: CGPoint = kind == .ibeam ? .zero : CGPoint(x: 1, y: 2.5)
                let pixel = CGPoint(x: (hotspot.x + nudge.x) * scale, y: (hotspot.y + nudge.y) * scale)
                XCTAssertGreaterThan(alpha(of: image, atPixel: pixel), 200, "\(skin.id) \(kind) art at hotspot")
            }
        }
    }

    func testHotspotMapsToPointerPositionAtScale1And2() {
        // A secondary display placed left of and below the main one, to cover non-zero window origins.
        let origins = [CGPoint.zero, CGPoint(x: -1280, y: -200)]
        let hotspotPoints = CGPoint(x: 13, y: 12)
        let imagePoints = CGSize(width: 38, height: 44)
        for scale in [CGFloat(1), CGFloat(2)] {
            for origin in origins {
                for local in [CGPoint(x: 400, y: 300), CGPoint(x: 0, y: 0), CGPoint(x: 799.5, y: 0.5)] {
                    guard scale == 2 || local.x.rounded() == local.x else { continue }
                    let pointer = CGPoint(x: origin.x + local.x, y: origin.y + local.y)
                    let frame = SkinGeometry.layerFrame(
                        pointer: pointer,
                        windowOrigin: origin,
                        imagePixelSize: CGSize(width: imagePoints.width * scale, height: imagePoints.height * scale),
                        hotspotPixels: CGPoint(x: hotspotPoints.x * scale, y: hotspotPoints.y * scale),
                        backingScale: scale
                    )
                    // Layer space is bottom-left origin; the hotspot is measured from the image's top-left.
                    XCTAssertEqual(frame.minX + hotspotPoints.x, local.x, accuracy: 1e-9, "x at \(scale)x")
                    XCTAssertEqual(frame.maxY - hotspotPoints.y, local.y, accuracy: 1e-9, "y at \(scale)x")
                    XCTAssertEqual(frame.width, imagePoints.width, accuracy: 1e-9, "one image pixel per device pixel")
                    XCTAssertEqual(frame.minX * scale, (frame.minX * scale).rounded(), accuracy: 1e-9, "pixel aligned")
                    XCTAssertEqual(frame.minY * scale, (frame.minY * scale).rounded(), accuracy: 1e-9, "pixel aligned")
                }
            }
        }
    }

    func testOffGridPointerSnapsWithinHalfADevicePixel() {
        for scale in [CGFloat(1), CGFloat(2)] {
            let pointer = CGPoint(x: 100.3, y: 50.8)
            let frame = SkinGeometry.layerFrame(
                pointer: pointer, windowOrigin: .zero, imagePixelSize: CGSize(width: 40, height: 40),
                hotspotPixels: CGPoint(x: 10, y: 10), backingScale: scale
            )
            XCTAssertLessThanOrEqual(abs(frame.minX + 10 / scale - pointer.x), 0.5 / scale + 1e-9)
            XCTAssertLessThanOrEqual(abs(frame.maxY - 10 / scale - pointer.y), 0.5 / scale + 1e-9)
        }
    }

    func testSmoothingZeroDrawsAtExactPosition() throws {
        let hider = RecordingHider()
        let tracker = CursorTracker()
        let overlays = OverlayManager(screens: TestScreens([1]))
        overlays.start()
        defer { overlays.stop() }
        let renderer = SkinRenderer(hider: hider, tracker: tracker, overlays: overlays, detector: FixedKindDetector())
        defer { renderer.stop() }
        XCTAssertEqual(renderer.smoothing, 0, "smoothing defaults to 0")
        let skin = BuiltInSkins.all[0]
        renderer.apply(skin, sizeMultiplier: 1)

        let target = CGPoint(x: 300, y: 200)
        tracker.deliver(position: target, timestamp: 1)
        XCTAssertEqual(renderer.displayedPosition, target)

        let layer = try XCTUnwrap(renderer.skinLayer(for: 1))
        let hotspot = try XCTUnwrap(skin.hotspot[.arrow])
        XCTAssertFalse(layer.isHidden)
        XCTAssertEqual(layer.frame.minX + hotspot.x, target.x, accuracy: 1e-9)
        XCTAssertEqual(layer.frame.maxY - hotspot.y, target.y, accuracy: 1e-9)
    }

    func testSmoothingLagsThenSettles() async {
        let tracker = CursorTracker()
        let overlays = OverlayManager(screens: TestScreens([1]))
        overlays.start()
        defer { overlays.stop() }
        let renderer = SkinRenderer(hider: RecordingHider(), tracker: tracker, overlays: overlays, detector: FixedKindDetector())
        defer { renderer.stop() }
        renderer.apply(BuiltInSkins.all[0], sizeMultiplier: 1)
        tracker.deliver(position: CGPoint(x: 100, y: 100), timestamp: 1)
        renderer.smoothing = 0.5
        tracker.deliver(position: CGPoint(x: 300, y: 100), timestamp: 2)
        let first = renderer.displayedPosition?.x ?? 0
        XCTAssertGreaterThan(first, 100)
        XCTAssertLessThan(first, 300)
        for _ in 0..<100 where renderer.displayedPosition?.x != 300 {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(renderer.displayedPosition, CGPoint(x: 300, y: 100))
    }

    func testFallbackDrawsSkinBesideTheRealCursor() throws {
        let tracker = CursorTracker()
        let overlays = OverlayManager(screens: TestScreens([1]))
        overlays.start()
        defer { overlays.stop() }
        let renderer = SkinRenderer(hider: FallbackCursorHider(), tracker: tracker, overlays: overlays, detector: FixedKindDetector())
        defer { renderer.stop() }
        let skin = BuiltInSkins.all[0]
        renderer.apply(skin, sizeMultiplier: 1)
        tracker.deliver(position: CGPoint(x: 300, y: 200), timestamp: 1)
        let layer = try XCTUnwrap(renderer.skinLayer(for: 1))
        let hotspot = try XCTUnwrap(skin.hotspot[.arrow])
        let offset = SkinRenderer.fallbackOffset
        XCTAssertNotEqual(offset, .zero)
        XCTAssertEqual(layer.frame.minX + hotspot.x, 300 + offset.x, accuracy: 1e-9)
        XCTAssertEqual(layer.frame.maxY - hotspot.y, 200 + offset.y, accuracy: 1e-9)
    }

    func testSwitchesKindAndScalesWithSizeMultiplier() throws {
        let tracker = CursorTracker()
        let overlays = OverlayManager(screens: TestScreens([1]))
        overlays.start()
        defer { overlays.stop() }
        let detector = FixedKindDetector(.arrow)
        let renderer = SkinRenderer(hider: RecordingHider(), tracker: tracker, overlays: overlays, detector: detector)
        defer { renderer.stop() }
        let skin = BuiltInSkins.all[0]
        renderer.apply(skin, sizeMultiplier: 2)
        tracker.deliver(position: CGPoint(x: 300, y: 200), timestamp: 1)
        XCTAssertEqual(renderer.kind, .arrow)

        detector.kind = .ibeam
        tracker.deliver(position: CGPoint(x: 310, y: 200), timestamp: 2)
        XCTAssertEqual(renderer.kind, .ibeam)
        let layer = try XCTUnwrap(renderer.skinLayer(for: 1))
        let canvas = skin.canvasSize(for: .ibeam)
        XCTAssertEqual(layer.bounds.width, canvas.width * 2, accuracy: 1)
        let hotspot = try XCTUnwrap(skin.hotspot[.ibeam])
        XCTAssertEqual(layer.frame.minX + hotspot.x * 2, 310, accuracy: 0.5)

        // Unknown system cursors keep the last known kind instead of flickering.
        detector.kind = nil
        tracker.deliver(position: CGPoint(x: 320, y: 200), timestamp: 3)
        XCTAssertEqual(renderer.kind, .ibeam)
    }

    func testApplyNilStopsAndRemovesLayers() {
        let hider = RecordingHider()
        let tracker = CursorTracker()
        let overlays = OverlayManager(screens: TestScreens([1]))
        overlays.start()
        defer { overlays.stop() }
        let renderer = SkinRenderer(hider: hider, tracker: tracker, overlays: overlays, detector: FixedKindDetector())
        renderer.apply(BuiltInSkins.all[0], sizeMultiplier: 1)
        XCTAssertNotNil(renderer.skinLayer(for: 1))
        renderer.apply(nil, sizeMultiplier: 1)
        XCTAssertNil(renderer.skinLayer(for: 1))
        XCTAssertFalse(hider.isHidden)
        XCTAssertEqual(overlays.windows[1]?.rootLayer.sublayers?.count ?? 0, 0)
    }

    func testKindClassifierMatchesReferenceBytes() {
        let arrow = Data([1, 2, 3])
        let hand = Data([4, 5])
        let ibeam = Data([6, 7, 8, 9])
        let classifier = CursorKindClassifier(references: [.arrow: arrow, .hand: hand, .ibeam: ibeam])
        XCTAssertEqual(classifier.classify(arrow), .arrow)
        XCTAssertEqual(classifier.classify(hand), .hand)
        XCTAssertEqual(classifier.classify(ibeam), .ibeam)
        XCTAssertNil(classifier.classify(Data([1, 2, 4])), "same length but different bytes is not a match")
        XCTAssertNil(classifier.classify(nil))
    }
}
