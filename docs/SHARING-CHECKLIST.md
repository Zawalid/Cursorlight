# Screen sharing checklist

Things only a real desktop can prove. Run each one, write what you saw next to it, and file anything wrong in
`docs/BACKLOG.md`. "Viewer" means a second device or account joined to the call, or the recorded file.

Set up once: install the current build, grant nothing optional first, then repeat the key rows after granting Input
Monitoring.

## For each app: Zoom, Google Meet (Chrome), Microsoft Teams, FaceTime, OBS display capture
Share a **whole screen**, then a **single window**, then a **single app window with other windows in front**.

| Check | Whole screen | One window |
|---|---|---|
| Highlight is visible to the viewer | | |
| Laser trail visible | | |
| Ink strokes visible, and they fade | | |
| Spotlight dim visible | | |
| Pointer skin visible (Ghost, Ring, Bolt) | | |
| Floating bar hidden from the viewer when "hide from sharing" is on | | |
| Timer chip and keystroke display visible or hidden as set | | |
| Share-safe status says the right thing for the share type | | |

Expected for a single window: Cursorlight overlays are not part of that window, so the viewer sees none of them. The
share-safe status must say so.

## Displays and spaces
- Two displays: highlight and ink follow the pointer across, spotlight stays on its display, "this display only" works.
- Display unplugged and replugged while ink is on screen: no crash, overlays come back.
- Mission Control, switching Spaces, and a full-screen app on one Space: overlays and the pointer skin stay correct.
- Stage Manager on: overlays are still on top, the bar is reachable.
- Clamshell with an external display.

## Pointer skin
- Skin shows over the Dock, menu bar, a text field, a link, and a window edge (resize cursor).
- No flicker while still, while dragging fast, or while moving between displays.
- Quit Cursorlight (menu bar, Quit): the normal pointer returns at once.
- Force quit Cursorlight: the normal pointer returns after the next mouse move into any window.
- Sleep and wake, and fast user switching: the skin is back or the normal pointer shows, never a stuck blank.
- Screenshot (Shift-Command-4) and screen recording show the skin as the viewer would see it.

## Presenting
- Keynote and PowerPoint in presenter mode: hide-in-full-screen works as set, ink and laser work over slides.
- A clicker mapped to next slide still works while ink is on.
- Presenter timer chip survives a Space change.
- Per-app rules: switching to the rule's app switches the scene, and the pointer skin follows.

## Permissions
- Fresh install: Cursorlight asks for nothing until a feature needs it.
- Input Monitoring granted: hold trigger, keystroke display, key sound, hide while typing.
- Input Monitoring denied: those items explain what is missing and everything else still works.
- Password field: the keystroke display shows nothing.

## Battery and CPU (Activity Monitor)
- Idle with a skin on: under 1% CPU.
- Ink on screen and moving the pointer: under 10% CPU.
- Leave it running for a workday: no growth in memory.
