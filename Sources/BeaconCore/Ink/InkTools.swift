import CoreGraphics
import Foundation

/// What a drag on the screen does while drawing.
public enum InkTool: String, CaseIterable, Codable, Sendable {
    case pen, eraser, box, redact, arrow, curvedArrow, doubleArrow, bracket, stamp, text

    public var displayName: String {
        switch self {
        case .pen: "Pen"
        case .eraser: "Eraser"
        case .box: "Box"
        case .redact: "Cover"
        case .arrow: "Arrow"
        case .curvedArrow: "Curved arrow"
        case .doubleArrow: "Double arrow"
        case .bracket: "Bracket"
        case .stamp: "Stamp"
        case .text: "Text"
        }
    }

    /// The key that picks this tool while drawing.
    public var key: String {
        switch self {
        case .pen: "p"
        case .eraser: "e"
        case .box: "b"
        case .redact: "r"
        case .arrow: "a"
        case .curvedArrow: "v"
        case .doubleArrow: "d"
        case .bracket: "k"
        case .stamp: "n"
        case .text: "t"
        }
    }

    /// The mark a drag with this tool makes, for the tools that drag out a shape.
    var dragKind: InkMarkKind? {
        switch self {
        case .box: .filledBox
        case .redact: .redact
        case .arrow: .arrow
        case .curvedArrow: .curvedArrow
        case .doubleArrow: .doubleArrow
        case .bracket: .bracket
        case .pen, .eraser, .stamp, .text: nil
        }
    }
}

/// The symbols a stamp can place. The number stamp counts up by itself.
public enum StampKind: String, CaseIterable, Codable, Sendable {
    case number, check, cross, star, heart, question, exclamation, bubble

    public var displayName: String {
        switch self {
        case .number: "Number"
        case .check: "Check"
        case .cross: "Cross"
        case .star: "Star"
        case .heart: "Heart"
        case .question: "Question"
        case .exclamation: "Exclamation"
        case .bubble: "Speech bubble"
        }
    }
}

/// What one mark on the screen is.
public enum InkMarkKind: Equatable, Sendable {
    case freehand
    case filledBox
    case redact
    case arrow
    case curvedArrow
    case doubleArrow
    case bracket
    case stamp(StampKind, Int)
    case text(String)

    /// Marks dragged out from two corners.
    var isDragShape: Bool {
        switch self {
        case .filledBox, .redact, .arrow, .curvedArrow, .doubleArrow, .bracket: true
        case .freehand, .stamp, .text: false
        }
    }
}

/// A backdrop for drawing on, instead of the screen.
public enum InkBoard: String, CaseIterable, Codable, Sendable {
    case none, white, black

    public var displayName: String {
        switch self {
        case .none: "Screen"
        case .white: "White board"
        case .black: "Black board"
        }
    }

    public var next: InkBoard {
        switch self {
        case .none: .white
        case .white: .black
        case .black: .none
        }
    }
}
