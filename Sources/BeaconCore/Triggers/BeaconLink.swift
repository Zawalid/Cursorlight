import Foundation

/// What a `beacon://` link asks Beacon to do. Links are plain text, so anything can send them: every command here is
/// harmless (it only switches Beacon's own effects) and nothing reads data back.
public enum BeaconLinkCommand: Equatable, Sendable {
    public enum Switch: String, Sendable { case on, off, toggle }

    case highlight(Switch)
    case laser(Switch)
    case ink(Switch)
    case spotlight(Switch)
    case pause(Switch)
    case toolbar(Switch)
    case timerToggle
    case timerStart(minutes: Int?)
    case timerStop
    case whiteboard(InkBoard)
    case clearInk
    case undoInk
    case nextScene
    case scene(name: String)
    case penColor(InkColor)
    case penTool(InkTool)
}

public enum BeaconLink {
    public static let scheme = "beacon"

    /// The command in `url`, or nil when it is not a Beacon link or asks for something unknown.
    public static func parse(_ url: URL) -> BeaconLinkCommand? {
        guard url.scheme?.lowercased() == scheme, let host = url.host?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        let query = Dictionary(
            uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).compactMap { item in
                item.value.map { (item.name.lowercased(), $0) }
            }.reversed()
        )
        let argument = parts.first?.removingPercentEncoding?.lowercased()

        func toggle(_ make: (BeaconLinkCommand.Switch) -> BeaconLinkCommand) -> BeaconLinkCommand? {
            guard let word = argument else { return make(.toggle) }
            return BeaconLinkCommand.Switch(rawValue: word).map(make)
        }

        switch host {
        case "highlight": return toggle { .highlight($0) }
        case "laser": return toggle { .laser($0) }
        case "ink", "draw": return toggle { .ink($0) }
        case "spotlight": return toggle { .spotlight($0) }
        case "pause": return toggle { .pause($0) }
        case "bar", "toolbar": return toggle { .toolbar($0) }
        case "timer":
            switch argument {
            case nil, "toggle": return .timerToggle
            case "start": return .timerStart(minutes: query["minutes"].flatMap(Int.init).map { min(max($0, 1), 600) })
            case "stop": return .timerStop
            default: return nil
            }
        case "whiteboard":
            switch argument {
            case nil, "white": return .whiteboard(.white)
            case "black": return .whiteboard(.black)
            case "off", "none": return .whiteboard(.none)
            default: return nil
            }
        case "clear": return .clearInk
        case "undo": return .undoInk
        case "scene":
            if argument == "next" { return .nextScene }
            if let name = query["name"] ?? parts.first?.removingPercentEncoding, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                return .scene(name: name)
            }
            return nil
        case "color", "colour":
            guard let word = argument ?? query["name"]?.lowercased(), let color = InkColor(rawValue: word) else { return nil }
            return .penColor(color)
        case "tool":
            guard let word = argument ?? query["name"]?.lowercased(),
                  let tool = InkTool.allCases.first(where: { $0.rawValue.lowercased() == word || $0.displayName.lowercased() == word }) else { return nil }
            return .penTool(tool)
        default: return nil
        }
    }

    /// The finished list of links worth showing in settings, as (what it does, the link).
    public static let examples: [(title: String, link: String)] = [
        ("Toggle the highlight", "beacon://highlight/toggle"),
        ("Turn the laser on", "beacon://laser/on"),
        ("Start drawing", "beacon://ink/on"),
        ("Spotlight a region", "beacon://spotlight/toggle"),
        ("Whiteboard", "beacon://whiteboard/white"),
        ("Start a 10 minute timer", "beacon://timer/start?minutes=10"),
        ("Clear drawings", "beacon://clear"),
        ("Next scene", "beacon://scene/next"),
        ("Switch to a scene by name", "beacon://scene?name=Meeting"),
        ("Pen color blue", "beacon://color/blue"),
        ("Pause everything", "beacon://pause/toggle"),
        ("Show the floating bar", "beacon://bar/on"),
    ]
}
