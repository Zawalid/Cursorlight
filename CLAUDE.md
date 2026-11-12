# Beacon (working name)

Native macOS menu bar app: find, point and mark up with the cursor while screen sharing, plus polished cursor skins. Goal and scope: `GOAL.md`. Specs: `docs/superpowers/specs/`. Research: `docs/research/`.

## Status
Building. Follow `docs/ROADMAP.md` (milestones M1 to M9); detailed task text for Ink, triggers, profiles, Share-safe and packaging is in `docs/superpowers/plans/`. Done: scaffold, overlays, shake, cursor size, five highlight styles, settings store, laser, ink, triggers, settings window/popover/first-run (M1 to M5), profiles, app rules, display scope (M6). Next: M7 Share-safe.

## App shape (decided)
Menu bar agent (LSUIElement) with a sidebar settings window and a menu bar popover. No Dock app, no tabs.

## Stack (proposed, not yet confirmed)
- Swift 6, SwiftUI plus AppKit, macOS 14.6+, universal binary
- Core logic in a Swift package, app target generated with XcodeGen (same layout as Veil and Perch)
- Direct distribution, Sparkle updates. No licensing, no analytics.

## Rules
- All branding (name, icon, colors, copy) lives in one Branding file and the asset catalog. The name is a placeholder.
- Private API only behind a protocol with a public fallback, in one isolated folder.
- No Accessibility or Screen Recording permission unless a feature truly needs it, and then optional.
- No emojis in code. No force casts, no `as any`-style escapes, no force unwraps in production code.
- Keep core logic in the package and unit-tested; keep views thin.
- Write French text with real UTF-8 characters, never escape sequences.
- Commit subjects are lowercase `feat:` / `fix:` / `chore:`, no attribution lines. Stay on the checked-out branch.
- Never launch, kill or reinstall the author's running copy. Visual checks use an agent-mode build.
- Anything needing the real desktop (multi-display, Stage Manager, real conferencing apps) is reported as not verified.
