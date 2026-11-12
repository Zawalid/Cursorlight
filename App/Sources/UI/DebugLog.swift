import Foundation

/// Diagnostic file log, on only when BEACON_DEBUG_EVENTS=1. Used to see what the app received and did.
enum DebugLog {
    static let isOn = ProcessInfo.processInfo.environment["BEACON_DEBUG_EVENTS"] == "1"
    private static let path = "/tmp/beacon-events.log"

    static func write(_ text: String) {
        guard isOn, let data = (String(format: "%.3f ", ProcessInfo.processInfo.systemUptime) + text + "\n").data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}
