# Beacon v1: design

Status: draft for approval (builder check done, both open questions answered by the user). "Beacon" is a placeholder name. Items marked **(my call)** are decisions I made without the user; everything else was said or agreed by the user in conversation.

## 1. Intent and why

The user streamed their screen and the other person could not see where the cursor was. Existing tools either hide the cursor (Zoom in window share), lose it to video compression, or are small single-purpose utilities that look dated. Nothing combines finding, pointing and marking up, and nothing treats the cursor as a design product.

Beacon is a native macOS menu bar app with three jobs, plus a polished cursor look:

1. **Find** the cursor: halo, optional screen dim, shake to find.
2. **Point** with it: laser trail, click pulse, magnifier, numbered pins.
3. **Mark up**: freehand ink that fades by itself, with shapes cleaned up into circles, arrows and underlines.
4. **Look**: replace the arrow with a beautiful, high-visibility cursor skin.

The user wants it good enough to publish and sell later. Visual quality is the product.

## 2. Goals, non-goals, anti-goals

Goals
- Anyone watching a full-screen share can always see where the presenter's cursor is and what they point at.
- Summoning an effect takes one gesture and no menu.
- It looks and feels premium: spring motion, crisp at any size, tasteful defaults.
- Publishable: signed, notarized, updated with Sparkle, installable by Homebrew cask.

Non-goals (v1)
- Not a screen recorder, not a whiteboard, not a presentation tool.
- No viewer cursor (the other person pointing on the presenter's screen). Later.
- No window-share support. Later (mirror mode).
- No skin marketplace, cursor replay, key display or reactions. Later.

Anti-goals (would be a failure even if it works)
- Looks like a generic utility or the existing apps.
- Demands Accessibility or Screen Recording permission for basic features.
- Accounts, analytics, or any network use other than the update check.
- Laggy or jittery cursor: the user's real pointing must never feel worse.

## 3. App shape (decided)

Menu bar agent (no Dock icon), a sidebar settings window, and a menu bar popover. No tabs, no document windows. Same layout family as Veil and Perch (Swift package for core logic, XcodeGen app target).

- **Menu bar popover:** switch profile (Stream, Meeting, Recording), pause everything, open settings, Share-safe status.
- **Settings sidebar:** Cursor, Effects, Triggers, Profiles and Apps, Displays, About.
- **Cursor gallery** (inside Cursor): skins shown large with a live preview that follows the real cursor. The showpiece screen.
- **First-run guide:** explains permissions and shows the shake gesture working.

## 4. Behavior

### 4.1 Summoning (decided: three triggers)
- Shake the cursor.
- Double-tap Option.
- Hold a hotkey (hold-to-draw for Ink).
All rebindable and individually switchable off. Each trigger can be mapped to an effect. **(my call):** defaults are shake = Beacon, double-tap Option = Laser, hold hotkey = Ink. Shake recognition reuses the approach in Veil (NSEvent global and local mouse monitors).

### 4.2 Effects (v1)
- **Beacon:** glowing halo with a spring bloom on summon; optional dim of the rest of the screen; fades when the cursor rests. Shake-to-find uses the user's skin, enlarged.
- **Laser:** glowing comet trail that fades after about a second.
- **Ink:** hold the hotkey and draw. Strokes fade on their own, nothing to clear. Circles, arrows and underlines are cleaned up into perfect shapes. Styles: marker, highlighter, chalk, neon.
- **Click pulse:** ripple on click.
- Looks: several themes **(my call: Neon, Ink, Spotlight, Minimal)**.

Magnifier, numbered pins and emphasis box were discussed in brainstorming but are **not in v1 (my call)** to keep scope small. They are first candidates for v1.1.

### 4.3 Cursor look (revised 2026-11-11)
The first approach (hide the real cursor and draw a skin in an overlay) failed on the user's screen: the real cursor stayed visible on top. Replacing the real arrow through the SkyLight registration calls was accepted but ignored on macOS 26.7 (see `docs/research/2026-11-08-cursor-approaches.md`). What works and was seen working by the user: the system cursor scale (`SLSSetCursorScale`, read back as set).
- **v1:** a system-wide cursor size setting (about 0.5x to 4x, presets 1x, 1.5x, 2x, 3x), applied through the private scale call behind a protocol in `Sources/BeaconCore/Private/`. The cursor stays the real one, so it shows up in screen shares. The scale is restored on quit, and a persisted marker of the original scale restores it on the next launch after a crash.
- **Around the cursor:** halo, glow, laser, click pulse and Ink styles (section 4.2) give the "polished look". Themes style those.
- **Later, research task (not v1):** custom cursor arrows by replacing the system cursor images. The SkyLight call is accepted but ignored today; needs our own disassembly of `SLSRegisterCursorWithImages2`. Prior art (Mousecape, MaCursor) is non-commercial or GPL-3 and must not be copied.
- **Decision note:** the earlier rule "skins are required for v1, block the release otherwise" is superseded by this section. This was the controller's ruling after the user confirmed that cursor size works; the user may overrule it.

### 4.4 Profiles, apps, displays
- Profiles: Stream, Meeting, Recording. Each stores skin, theme, effects on or off and trigger mapping. Switchable from the popover.
- Per-app rules: choose a profile or turn Beacon off for specific apps.
- Per-display: effects can follow the cursor across displays; option to show on one display only.

### 4.5 Share-safe check (decided: full-screen plus warning)
Spike result: overlays are visible in full-screen share and invisible in single-window share (`docs/research/2026-11-08-capture-spike.md`). v1 supports full-screen share and warns when the user is sharing a single window.
- The popover shows a Share-safe status.
- **Open for the builder:** how to detect that a window share is active. Candidates: ScreenCaptureKit's content-sharing picker or sharing notifications, or watching for known conferencing apps' sharing windows. Prefer the way that needs no extra permission. If detection cannot be done reliably, ship a manual "I am sharing" reminder tip instead and say so plainly. Do not claim detection that has not been verified.

## 5. Constraints

- Swift 6, SwiftUI for settings, AppKit and Core Animation (Metal where needed) for overlays, macOS 14.6+, universal binary. **(my call, matches the author's other apps; confirm.)**
- Overlay: one click-through window per display, all Spaces and full-screen auxiliary, rebuilt on display hot-plug, sleep, wake and lock. Same pattern as Veil.
- Permissions: shake needs none. Double-tap Option and hold-to-draw probably need Input Monitoring (unverified). No Accessibility or Screen Recording unless a feature truly needs it, and then optional.
- Direct distribution, Sparkle updates, Homebrew cask, signing and notarization (use the mac-app-shipping skill when the time comes). No licensing code in v1; pricing is decided later **(my call)**.
- Free tier idea (one theme, Beacon only) and a one-time paid price of roughly 15 to 25 dollars are the author's business direction, not a v1 build requirement.
- Rules: no emojis in code, no force casts or force unwraps in production code, lowercase `feat:`/`fix:`/`chore:` commits with no attribution lines, core logic in the package and unit-tested, all branding in one Branding file.

## 6. Not verified yet

- Real Zoom, Meet and Teams behavior (the spike used ScreenCaptureKit directly).
- Multi-display, Stage Manager, Spaces, sleep and wake, with the real desktop.
- Input Monitoring requirement for double-tap Option and hold-to-draw.
- That hiding and replacing the cursor feels right across apps.

## 6a. Permission decision (user, 2026-11-08)
Optional Input Monitoring is acceptable. Double-tap Option and hold-to-draw Ink need it (unverified) and are offered only after the user grants it. Without it, shake still works, and Ink is a toggle on a normal hotkey (registered the Carbon way). The first-run guide explains this plainly and never blocks on it.

## 6b. Calls made after the builder check (all my calls, marked for the user to check)

- **Reference code is readable:** Veil at `~/Personal/Projects/Veil` (overlay windows, shake recognizer, settings, Sparkle), Perch at `~/Personal/Projects/Perch`, Apropos at `~/Personal/Projects/Cue`. Plan is port and adapt, not rewrite.
- **Private API:** allowed only behind a protocol with a public fallback, in one isolated folder, as in Veil. Direct distribution only, so no Mac App Store constraint.
- **Ink and the mouse:** while the Ink key is held, the overlay takes the mouse so the app underneath does not receive the drag. Beacon halo, Laser and click pulse stay click-through.
- **Ink shapes:** a simple heuristic recognizer is enough for v1 (closed loop to ellipse, straight stroke with a head to arrow, near-horizontal stroke to underline). The cleaned shape animates out of the raw stroke and then fades. A setting turns cleanup off.
- **Profile precedence:** a manual profile choice wins until the frontmost app changes; then a matching per-app rule applies. Per-display settings only affect where effects show, not which profile is active.
- **Rendering:** Core Animation and CAShapeLayer for glow, trails and ink. Metal only if a look proves impossible without it.
- **Share-safe:** a manual "I am sharing" reminder is an acceptable v1 result if reliable detection fails. Testing against real Zoom, Meet and Teams is wanted before release but is not a build blocker; it is listed under "not verified".
- **Displays:** if the author's Mac has one display, test hot-plug with a virtual display and report multi-display behavior as not verified.
- **Platform:** macOS 14.6+, universal, Swift 6 stay as proposed (matches Veil).

## 7. Left to the builder

- Exact visual design of skins, themes and the settings window (user: "surprise me with some brilliant design"; take primitives from the best apps, never copy their look). Needs a design pass before UI work; use a design skill.
- Motion constants (spring tension, fade times), shape-recognition algorithm for Ink, hotkey defaults.
- Project and module layout, test strategy, spike order. Suggested order: cursor-hide mechanism, then overlay and Beacon, then triggers, then Laser and Ink, then settings and skins, then Share-safe, then packaging.
- App name, icon and website (placeholder branding until the user decides).
