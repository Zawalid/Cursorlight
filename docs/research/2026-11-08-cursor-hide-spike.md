> **INVALIDATED 2026-11-08 (same day).** The user ran the built app and still saw the real cursor on top of the skin. This spike measured what a ScreenCaptureKit screenshot draws, not what is on the physical screen, so its "hidden" result was a false positive. Do not rely on the verdict below. See `docs/research/2026-11-08-cursor-approaches.md`.

# Cursor-hide spike verdict (Task 0, 2026-11-08)

Throwaway code: `spike/cursor-hide.swift`, `cursor-hide2.swift`, `cursor-hide3.swift`. Run in the Terminal panel on macOS 26.7, one Retina display, Finder frontmost.
Method: warp the pointer to screen centre, capture the display with and without the cursor through ScreenCaptureKit, count differing pixels around the pointer. Diff above 0 means the real cursor is drawn.

## Results

| Test | Diff | Meaning |
|---|---|---|
| Baseline | 464 | Cursor drawn |
| `NSCursor.hide()` from a background app | 464 | Does NOT hide |
| `CGDisplayHideCursor` alone | 464 | Does NOT hide |
| Private `CGSSetConnectionProperty("SetsCursorInBackground", true)` then `CGDisplayHideCursor` | 0 | HIDDEN while another app is frontmost |
| After that, one `CGDisplayShowCursor` | 464 | Restored with a single show call |
| Another process hides the cursor, then `kill -9` | 464 | The system restores the cursor when the process dies |
| Mouse-move handler delay, 294 events | p50 2.9 ms, p95 7.9 ms, max 9.7 ms | Under one 60 Hz frame (16.7 ms) |
| `NSCursor.currentSystem` image size | arrow 583248, hand 20892, ibeam 263952 bytes | Current cursor is identifiable by image bytes; the sample matched arrow |

## Verdict: GO

Mechanism for Task 4: set `SetsCursorInBackground` on the main connection, then `CGDisplayHideCursor`; restore with exactly one `CGDisplayShowCursor` per hide. Keep the private call in `Sources/BeaconCore/Private/` behind `CursorHider`, with the fallback (draw the skin next to the real cursor) when the private symbols are missing.

## Rules learned
- Never call `CGDisplayHideCursor` without first setting the property. An earlier run did, and the unbalanced hide count left the cursor hidden after a single show.
- Pair every hide with exactly one show. Keep a hide counter in `CursorHider` and make `restore()` idempotent.
- The kill-9 recovery is done by the system, but the relaunch marker in the plan stays as a belt-and-braces check.

## Not verified
- Cursor kind detection while the pointer is over a real link and a real text field (only the arrow case was sampled).
- Behavior with Stage Manager, full-screen apps, multiple displays, and secure input fields.
- Latency of the full render path (the number above is the event handler delay only).
