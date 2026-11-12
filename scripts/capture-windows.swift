// Captures every on-screen window of the running Beacon app (and only those), for design audits. It never captures the
// whole screen, which can show private content. Pass --screen to include one deliberately.
// Run it from a Terminal that has Screen Recording permission:  swift scripts/capture-windows.swift docs/audit/<folder>
import AppKit

let out = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") } ?? "docs/audit/latest"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func run(_ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = args
    try? p.run()
    p.waitUntilExit()
}

if CommandLine.arguments.contains("--screen") { run(["-x", "\(out)/screen.png"]) }
let info = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
var report: [String] = []
for w in info where (w[kCGWindowOwnerName as String] as? String) == "Beacon" {
    guard let id = w[kCGWindowNumber as String] as? Int else { continue }
    let layer = w[kCGWindowLayer as String] as? Int ?? 0
    let b = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    let w1 = Int(b["Width"] ?? 0), h1 = Int(b["Height"] ?? 0)
    report.append("window \(id) layer \(layer) size \(w1)x\(h1) name \(w[kCGWindowName as String] as? String ?? "")")
    // Skip full-display overlay windows; capture real content windows only.
    let isBar = (w[kCGWindowName as String] as? String) == "Beacon bar"
    // CAPTURE_OVERLAY=1 also captures Beacon's own full-display effect layer (only its own pixels, never the screen).
    let wantsOverlay = ProcessInfo.processInfo.environment["CAPTURE_OVERLAY"] == "1" && layer == 1000
    if isBar || wantsOverlay || (layer <= 200 && w1 > 100 && h1 > 100) { run(["-x", "-o", "-l", "\(id)", "\(out)/window-\(id).png"]) }
}
try? report.joined(separator: "\n").write(toFile: "\(out)/windows.txt", atomically: true, encoding: .utf8)
print(report.joined(separator: "\n"))
