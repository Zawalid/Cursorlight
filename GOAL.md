# Goal: Cursorlight (working name), a cursor toolkit for screen sharing on macOS

## Why this exists
When you share your screen, the other person often cannot see where your cursor is. Zoom hides it when you share a single window, video compression washes it out, and the built-in pointer tools only work for the sharer and look plain. Existing Mac utilities (Mouseposé, Mouzz, Mouse Pro, FocusCursor, Presentify, Epic Pen) each cover one or two jobs and look like utilities. Screen Studio proves people pay for polished cursor motion, but it only records.

Cursorlight is one small, beautiful app that does three jobs: find the cursor, point with it, mark things up. It is meant to be good enough to publish and sell.

"Cursorlight" is a placeholder. Identity (name, icon, visual design) will be reshaped later, so keep all branding in one place.

## The three jobs
1. Find: halo, spotlight, dimming, shake to find.
2. Point: laser trail, click pulse, magnifier, numbered pins.
3. Mark up: freehand ink that fades on its own, shapes cleaned up into perfect circles, arrows and underlines, emphasis box.

Plus a polished replacement look for the cursor itself (cursor skins).

## App shape (decided 2026-11-08)
Menu bar agent (no Dock icon) plus a real settings window with a sidebar. Not a full document app, no tabs.
- Menu bar popover: switch profile (Stream, Meeting, Recording) or pause everything.
- Settings sidebar: Cursor, Effects, Triggers, Profiles and Apps, Displays, About.
- Cursor gallery: skins shown large with a live preview that follows the real cursor. This is the showpiece screen.
- First-run guide: permissions, and the shake gesture shown working.
- Permissions note (unverified): double-tap Option and hold-to-draw probably need Input Monitoring; shake alone needs none.

## How it is summoned
Shake the cursor, double-tap Option, or hold a hotkey. All three trigger the same overlay layer. Gestures and hotkeys are rebindable.

## Version 1 scope (agreed in conversation)
- A handful of beautiful cursor skins, with matching hand and I-beam variants.
- Cursorlight (halo and optional screen dim), Laser (comet trail), Ink (auto-fading strokes with shape cleanup), click pulse.
- Shake and double-tap Option summon, hold-to-draw hotkey.
- Per-app and per-display settings, presenter profiles (Stream, Meeting, Recording).
- Share-safe check: tell the user whether their effects are visible in the current share.

## Later (not v1)
- Viewer cursor: a link that lets the other person point back on your screen (needs a small server).
- Cursor replay, skin packs / marketplace, seasonal skins, key display, reactions.
- Accessibility mode (high contrast, color-blind-safe halos) may move into v1 if cheap.

## Anti-goals
- Not a screen recorder and not a whiteboard.
- No accounts, no analytics. Network only for the update check (and the viewer cursor, later, opt-in).
- No Accessibility or Screen Recording permission unless a specific feature truly needs it, and then optional.
- Must not look like a generic utility. Visual quality is the product.

## Spike result (2026-11-08)
Overlays reach viewers in full-screen share, but not in single-window share. Details and options: `docs/research/2026-11-08-capture-spike.md`. The section below is the original question, kept for context.

**Decision (2026-11-08):** v1 supports full-screen share. The Share-safe check warns the user when they share a single window, because effects will not be visible to viewers. Mirror mode (live copy of a window with effects drawn in) is deferred, not v1.

**Revision 2026-11-11:** the cursor-skin approach changed. See `docs/superpowers/specs/2026-11-08-cursorlight-v1-design.md` section 4.3: v1 uses the system cursor size plus effects around the real cursor; custom arrows are a later research task.

## Open technical risk (spike first)
Overlay windows are only captured by Zoom, Meet and Teams when the user shares the entire screen, not a single window. Replacing the system cursor is not supported by public API; the usual route is to hide the real cursor and draw an overlay. Before building features, run a throwaway spike to find out:
- what each conferencing app captures (full screen vs window share),
- whether a companion window makes effects visible in window share,
- how to hide and replace the cursor without private API, or with the narrowest private API behind a fallback.
Anything needing the real desktop (multi-display, Stage Manager, real calls) is reported as not verified unless it was.

## Stack (proposed, follows the author's other Mac apps; confirm before building)
- Swift 6, SwiftUI for settings, AppKit and Metal/Core Animation for overlay windows, macOS 14.6+, universal binary.
- Core logic in a Swift package, app target generated with XcodeGen, same layout as Veil and Perch.
- Direct distribution (DMG from GitHub Releases) with Sparkle updates, signing and notarization per the mac-app-shipping skill. No Homebrew.
- Reuse the shake recognizer approach from Veil (NSEvent global and local mouse monitors).

## Reference apps in ~/Personal/Projects
- Veil: menu bar agent plus settings window, shake gesture, overlay window per display, Sparkle, docs layout.
- Perch: menu bar app with global shortcut and live window copy.
- Apropos (folder "Cue"): hotkey-summoned panel.
- Lopper, Edgeline: full windowed apps.
