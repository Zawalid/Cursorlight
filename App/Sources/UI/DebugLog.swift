import Foundation

/// Diagnostic file log, on only when CURSORLIGHT_DEBUG_EVENTS=1. Used to see what the app received and did.
enum DebugLog {
    static let isOn = ProcessInfo.processInfo.environment["CURSORLIGHT_DEBUG_EVENTS"] == "1"
    private static let path = "/tmp/cursorlight-events.log"

    static func write(_ text: String) {
        guard isOn, let data = (text + "\n").data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}
