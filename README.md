# Cursorlight

A macOS menu bar app that helps people see where you are pointing while you share your screen or present. Find your
pointer, mark up the screen, spotlight a region, and give the pointer a look of its own.

"Cursorlight" is a working name.

## What it does
- **Highlight** the pointer in six styles (Aura, Lens, Comet, Keyline, Sonar, Crosshair), with color, size, click effects
  and fading when the pointer is still.
- **Laser** trail and **Ink**: draw on the screen with five pens, snapped shapes, arrows, boxes, text, stamps, a
  whiteboard and an eraser. Strokes fade or stay.
- **Spotlight**: light one region of the screen and dim the rest, while clicks still reach what is inside.
- **Pointer skins**: replace the real pointer with a design (Classic, Dart, Bolt, Ring, Target, Star, Heart, Ghost).
- **Scenes**: save a whole look as a scene, switch by shortcut, per-app rule or app category. Presets for teaching,
  webinars, tutorials and pairing, plus export and import.
- **Presenting extras**: floating tool bar, presenter timer, keystroke display, hide in full-screen and video apps.
- **Control from anywhere**: global shortcuts, shake, double-tap or hold a modifier, and `cursorlight://` links for Stream
  Deck, Raycast, Alfred and scripts.

## Privacy
No analytics, no accounts, no network calls except optional update checks. Cursorlight does not need Screen Recording.
Accessibility is not used. Input Monitoring is optional and only enables the keystroke display, hold triggers, key
sound and hide-while-typing. Password fields are never seen: the system withholds those keys.

Cursorlight draws on top of your screen, so people watching a shared window may not see its effects. The share-safe check in
the app tells you when that is the case.

## Requirements
macOS 14.6 or later. Apple silicon and Intel.

## Build from source
```bash
brew install xcodegen
cd App && xcodegen generate && open Cursorlight.xcodeproj
```
The core logic is a Swift package, so `swift test` runs the unit tests without Xcode.

## Notes for contributors
- Private macOS API is used in two places, both behind a protocol with a fallback, in `Sources/CursorlightCore/Private`:
  the system cursor size and the pointer skins.
- Research and design notes are in `docs/`. The feature menu is `docs/BACKLOG.md`.

## License
MIT, see `LICENSE`. The name, icon and artwork are not covered.
