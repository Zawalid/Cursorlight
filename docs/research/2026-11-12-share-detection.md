# Can Beacon detect what the user is sharing? (2026-11-12)

## Verdict
Not reliably, with public API and no extra permission. v1 ships an honest manual check: the user says what they share, Beacon warns for "a window", and it never says "viewers can see effects" unless the user declared the whole screen. It also reminds when a known conferencing app is open.

## What was looked at
- **ScreenCaptureKit / SCContentSharingPicker:** the picker lets Beacon ask the user to pick content for Beacon's own capture. It does not report what other apps (Zoom, Meet, Teams) are capturing. Not usable.
- **CGDisplayIsCaptured:** public, but it documents a display captured for exclusive use (CGDisplayCapture), not screen recording or sharing. Not tested against a real call; not relied on.
- **CGWindowListCopyWindowInfo:** owner names and layers are available without permission, but window titles (where Zoom marks its share toolbar) need Screen Recording. Beacon should not require that permission.
- **Running app list (NSWorkspace):** public, no permission. Tells which conferencing app is open, not whether it is sharing, or what.
- **Private SkyLight ScreenWatcher family** (`SLSScreenWatcherNotificationForEach`, `...ItemGetPID`, `...ItemCopyWindowIDs`, `...ItemGetCaptureCount`, `SLSIsScreenWatcherPresent`): found with `dyld_info -exports`. By name these enumerate capture sessions with the capturing PID and the window IDs captured, which would answer "full screen or one window". **Not tried.** It is private, probably limited to the system's own screen-watcher connection, and would have to sit behind a protocol with a fallback. Worth a clean-room spike later.

## What shipped
- `ShareSafe` (pure) maps what the user declared plus the conferencing apps running to a status: idle, ok, warnSingleWindow, reminder(app), notSharing. `.ok` only comes from the user saying "whole screen".
- `ShareSafeMonitor` keeps the declaration in memory only and drops it when the last detected conferencing app quits.
- Known apps: Zoom, Microsoft Teams, Webex, FaceTime, Skype, GoToMeeting, BlueJeans. Browsers (Google Meet) and chat apps (Slack, Discord) are left out on purpose: always running, so they would only add noise.
- The popover, the Displays page and the sidebar show the status, and the menu bar icon turns amber while it needs attention.

## Not verified
- Behavior with real calls in Zoom, Meet and Teams.
- Whether the app list notifications fire for every conferencing app on macOS 26.
