import Foundation

/// Which shapes a finished stroke may snap to. Persisted as its raw value.
public struct InkShapeSet: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let ellipse = InkShapeSet(rawValue: 1)
    public static let rectangle = InkShapeSet(rawValue: 2)
    public static let line = InkShapeSet(rawValue: 4)
    public static let underline = InkShapeSet(rawValue: 8)
    public static let arrow = InkShapeSet(rawValue: 16)
    public static let all: InkShapeSet = [.ellipse, .rectangle, .line, .underline, .arrow]

    public init(from decoder: Decoder) throws {
        let value = try? decoder.singleValueContainer().decode(Int.self)
        self = value.map { InkShapeSet(rawValue: $0).intersection(.all) } ?? .all
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
