import AppKit

/// Reports which kind of cursor the system currently shows, or nil when it is none of the three.
@MainActor
public protocol CursorKindDetecting: AnyObject {
    func currentKind() -> CursorKind?
}

/// Matches cursor image bytes against references for each kind.
public struct CursorKindClassifier: Sendable {
    private let references: [CursorKind: Data]

    public init(references: [CursorKind: Data]) {
        self.references = references
    }

    public func classify(_ bytes: Data?) -> CursorKind? {
        guard let bytes else { return nil }
        // Fixed order so the answer never depends on dictionary ordering.
        return CursorKind.allCases.first { references[$0] == bytes }
    }
}

/// Task 0 detection: compares `NSCursor.currentSystem`'s image bytes with `NSCursor.arrow`, `.pointingHand` and
/// `.iBeam`. Encoding a cursor image is not free, so results are cached by hotspot and image size; the three
/// kinds differ in both, and a later cursor that matches a cached key gets the cached answer.
@MainActor
public final class SystemCursorKindDetector: CursorKindDetecting {
    private struct Key: Hashable {
        let hotspotX: CGFloat, hotspotY: CGFloat, width: CGFloat, height: CGFloat
    }

    private lazy var classifier = CursorKindClassifier(references: [
        .arrow: Self.bytes(of: .arrow),
        .hand: Self.bytes(of: .pointingHand),
        .ibeam: Self.bytes(of: .iBeam),
    ].compactMapValues { $0 })
    private var cache: [Key: CursorKind?] = [:]

    public init() {}

    public func currentKind() -> CursorKind? {
        guard let cursor = NSCursor.currentSystem else { return nil }
        let size = cursor.image.size
        let key = Key(hotspotX: cursor.hotSpot.x, hotspotY: cursor.hotSpot.y, width: size.width, height: size.height)
        if let cached = cache[key] { return cached }
        // Bytes first; if the system hands back a re-encoded copy, fall back to the reference's hotspot and size.
        let kind = classifier.classify(Self.bytes(of: cursor)) ?? referenceKeys[key]
        cache[key] = kind
        return kind
    }

    private lazy var referenceKeys: [Key: CursorKind] = {
        let pairs: [(NSCursor, CursorKind)] = [(.arrow, .arrow), (.pointingHand, .hand), (.iBeam, .ibeam)]
        var keys: [Key: CursorKind] = [:]
        for (cursor, kind) in pairs {
            let size = cursor.image.size
            keys[Key(hotspotX: cursor.hotSpot.x, hotspotY: cursor.hotSpot.y, width: size.width, height: size.height)] = kind
        }
        return keys
    }()

    private static func bytes(of cursor: NSCursor) -> Data? {
        cursor.image.tiffRepresentation
    }
}
