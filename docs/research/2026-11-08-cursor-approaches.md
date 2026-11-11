# Cursor skin approaches (2026-11-08, after the hide-and-overlay attempt failed)

## What failed
Hiding the real cursor with the private `SetsCursorInBackground` property plus `CGDisplayHideCursor`, then drawing a skin in an overlay window. On the user's screen the real cursor was still visible on top of the skin. The spike that said otherwise only compared two ScreenCaptureKit screenshots, which does not prove what the screen shows.

## What others do
- Mousecape (github.com/alexzielenski/Mousecape): replaces the system cursor images themselves by calling the private CoreGraphics functions Apple uses to initialize system cursors, plus a login helper that re-applies them when they get unregistered. No overlay, no hiding. Supports several scales (1x to 10x) and animated cursors. LICENSE: the author asks that none of the information be used for commercial purposes, and the license text restricts use to personal, non-commercial purposes. Its code and research cannot be reused in a paid app.
- Raycast "mouse cursor toggle" extension: uses the same `SetsCursorInBackground` hide trick; known to be blocked over the Dock; undocumented and may change between macOS releases.
- Shipping highlighters (Mouseposé, Cursor Pro, Mouzz, Mouse Pro, ClickPulse, CursorHighlighter, ClickLight, LocateCursor): do not replace the cursor. They draw a ring, halo, spotlight or ripple around the real cursor in overlay windows. ClickPulse needs no permissions; ClickLight needs Accessibility.

## Options
A. Replace the real system cursor images (Mousecape technique): true cursor, no lag, no hiding, appears in captures. Private API; must be our own clean-room work because of the Mousecape license; fragile across macOS versions.
B. Keep the real cursor and style everything around it (halo, ring, glow, trail, ink): what the shipping apps do. Safe, no private API. "Skins" become halo/ring styles and a larger, outlined cursor ring, not a new arrow.
C. Both: B for v1, A as a spike later.

## Open question about the "recording" indicator
Beacon source contains no ScreenCaptureKit, CGWindowList or other capture code (grep). The menu bar indicator is therefore not coming from Beacon's code; check which app Control Center names.

## Spike 0b: replace the real arrow (2026-11-11)
Throwaway: `spike/cursor-replace.swift`. Function names came from listing SkyLight's exports on this Mac (`xcrun dyld_info -exports`): SLSRegisterCursorWithImages, SLSCopyRegisteredCursorImages, SLSCursorNameForSystemCursor, SLSSetCursorScale, and others. Signatures follow the public CGSInternal header layout (MIT). No Mousecape code or text was used.
- System cursor names (ids 0 to 8): Arrow, IBeam, IBeamXOR, Alias, Copy, Move, ArrowCtx, Wait, Empty. The pointing hand is not in this list and still has to be found.
- The original arrow reads back fine (rc 0, 28x40 points, hotspot 5,5, 4 images, so several scales).
- Registering a 48-point red ring as the Arrow returned rc 0, and re-registering the saved original on exit also returned rc 0.
- Whether the arrow VISIBLY changed on the screen is to be confirmed by the user's eyes, not by a screenshot.
