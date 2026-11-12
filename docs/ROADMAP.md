# Beacon roadmap

Written 2026-11-12. Supersedes the task order in `docs/superpowers/plans/2026-11-08-beacon-v1.md` (that file stays as the detailed task text for Ink, triggers, profiles, Share-safe and packaging). Name and branding are placeholders.

Tiers: **V1** ships in the first paid release. **V1.1** is the first update. **LATER** is parked on purpose. **CUT** is rejected for now.
Status: done / next / open.

## 1. Product in one line
Find, point and mark up with your cursor while you share your screen, in a menu bar app that looks like a product and not a utility.

## 2. Feature inventory

### A. Find (cursor visibility)
| Feature | Tier | Status |
|---|---|---|
| Five highlight styles (Aura, Lens, Comet, Keyline, Sonar), spring follower | V1 | done |
| Shake to toggle highlight, stays on until next shake | V1 | done |
| Click ripples | V1 | done |
| System cursor size (0.5x to 4x) with crash restore | V1 | done |
| Highlight colour, size, intensity, dim amount settings | V1 | done (menu only; real UI in M5) |
| Screen dim around Lens (spotlight) as a separate switch | V1 | open |
| Auto colour that stays visible on light and dark backgrounds | V1.1 | open |
| High-contrast palette (yellow, full strength) | V1 | done; colour-blind-safe check open |
| Cursor locator on display switch (brief pulse when the cursor jumps displays) | V1.1 | open |
| Custom cursor arrows (SkyLight research, clean-room) | LATER | open |

### B. Point
| Feature | Tier | Status |
|---|---|---|
| Laser: comet trail that fades by event time | V1 | done as menu toggle; held-key trigger in M4 |
| Click pulse tuned per style | V1 | partly done |
| Magnifier lens following the cursor | V1.1 | open |
| Numbered pins (1, 2, 3 markers that fade) | V1.1 | open |
| Click-and-hold focus ring | V1.1 | open |
| Keystroke and click display | LATER | open |

### C. Mark up
| Feature | Tier | Status |
|---|---|---|
| Ink: draw, strokes fade on their own | V1 | done as menu mode (Escape ends); hold-key trigger in M4 |
| Shape cleanup: ellipse, rectangle, line, underline, arrow | V1 | done, unit-tested on synthetic strokes; real hand strokes untested |
| Ink styles: marker, highlighter, neon, chalk | V1 | open (marker, highlighter, neon first) |
| Ink colour quick switch (keys 1 to 5) | V1 | done in menu mode |
| Emphasis box | V1.1 | open |
| Undo last stroke, clear all | V1 | done (Cmd-Z, C in menu mode) |
| Persistent drawing mode (does not fade) | V1.1 | open |

### D. Summon and control
| Feature | Tier | Status |
|---|---|---|
| Shake gesture with sensitivity | V1 | done (no UI yet) |
| Hold-key trigger (default: hold Right Option draws ink) through optional Input Monitoring | V1 | done, untested on real desktop |
| Double-tap Option (default: Left Option toggles laser) | V1 | done, untested on real desktop |
| Toggle hotkeys without Input Monitoring (Carbon; defaults Ctrl+Option+H, L, I, P) | V1 | done, untested on real desktop |
| Rebindable triggers, each mapped to an effect | V1 | model and storage done; rebinding UI in M5 |
| Pause everything (menu bar + hotkey) | V1 | done |
| Auto-pause when a full-screen video app is frontmost | V1.1 | open |

### E. Profiles, apps, displays
| Feature | Tier | Status |
|---|---|---|
| Settings store, persisted, versioned | V1 | done |
| Profiles: Stream, Meeting, Recording, plus saved custom ones | V1 | done, untested on real desktop |
| Per-app rule: use profile X or turn off | V1 | done, untested on real desktop |
| Per-display: all displays or main only | V1 | done, multi-display untested |
| Import and export a profile as a file | V1.1 | open |

### F. Share safety
| Feature | Tier | Status |
|---|---|---|
| Menu bar status: effects visible to viewers or not | V1 | open |
| Manual "I am sharing" reminder, honest about what is unverified | V1 | open |
| Detection of window-share (needs a method that does not require Screen Recording) | V1 | open, research |
| Mirror mode so window-share works | LATER | open |

### G. App shell, UI and UX
| Feature | Tier | Status |
|---|---|---|
| Menu bar agent, no Dock icon | V1 | done (basic menu) |
| Menu bar popover: quick effect toggles, pause, share tip | V1 | done; profile switch waits for M6, share status for M7 |
| Settings window with sidebar: Highlight, Ink, Triggers, Profiles and Apps, Displays, About | V1 | done; Profiles and Displays are placeholders until M6 |
| Style gallery with animated preview | V1 | done as in-window preview; following the real cursor is not done |
| First-run guide: shake demo, optional permissions explained | V1 | done |
| Launch at login | V1 | done (About page), untested on real desktop |
| Sparkle update check | V1 | open |
| Keyboard shortcut cheat sheet in the popover | V1.1 | open |
| Localisation: English, French | V1.1 | open |
| Real icon, name and brand pass | V1 | open, needs user |

### H. Quality and trust (not features, but gates)
- Pure logic in the package with unit tests; renderer snapshot or layer-tree tests.
- Performance budget: under 2 percent CPU while idle, under 6 percent while a style animates, no dropped frames at 120 Hz on ProMotion. Measured with Instruments, not guessed.
- Robustness: sleep, wake, lock, display hot-plug, Spaces, full-screen apps, Stage Manager. Anything not tried on the real desktop is reported as not verified.
- Safety: cursor scale always restored on quit and after a crash. Effects never steal clicks.
- Privacy: no accounts, no analytics, network only for update check.

### I. Distribution and business
| Item | Tier |
|---|---|
| Signing, notarization, DMG, Sparkle appcast, Homebrew cask (mac-app-shipping skill) | V1 |
| Product site (Cloudflare Worker), demo video | V1 |
| Pricing: free tier (Aura + shake) and one-time paid unlock, around 15 to 25 dollars, licensing decided after V1 works | V1 decision |
| Viewer cursor (other person points back, needs a server) | LATER |
| Cursor replay, style packs, seasonal styles | LATER |

## 3. Design direction (to be locked in milestone 4)
- Dark, quiet, glassy settings window; one accent colour from `Branding`; the live preview is the hero of every screen.
- Motion language: critically damped springs, no overshoot on position, soft overshoot only on appear.
- Every setting shows its effect live on the real cursor while the settings window is open.
- Copy is short and concrete. No jargon (no "Input Monitoring" before the user needs it).
- Design pass uses mockups the user approves before any SwiftUI is written.

## 4. Milestones (in order)

**M1 Settings foundation.** Versioned `BeaconSettings` model, `SettingsStore` (UserDefaults, injectable), wire existing controllers (style, ripples, scale, shake sensitivity, dim) to it so choices survive relaunch. Exit: tests pass, relaunch keeps choices.

**M2 Laser and effect polish.** Laser trail on the existing trail buffer, colour/size/intensity/dim settings applied to all five styles, high-contrast palette. Exit: tests pass, user tries it on the real cursor.

**M3 Ink.** Stroke capture with overlay taking the mouse while held, fading strokes, shape recognizer (pure, heavily tested), marker/highlighter/neon, colour switch, undo, clear. Exit: recognizer tests on a table of strokes, user tries it.

**M4 Triggers and permissions.** Trigger model, Carbon hotkeys, Input Monitoring path for hold-keys and double-tap Option, graceful fallback, pause. Exit: each trigger works with and without the permission (permission path reported as not verified if it cannot be tried here).

**M5 App UI.** Design mockups approved by the user, then settings window, popover, style gallery with live preview, first-run guide, launch at login. Exit: user approves the look on screen.

**M6 Profiles, apps, displays.** Profile model on top of M1, frontmost-app rules, display scope. Exit: tests with fake workspace and screens.

**M7 Share-safe.** Status in popover and menu bar, manual reminder, detection research with a stated verdict. Exit: honest status shown, verdict documented.

**M8 Ship V1.** Icon and name decision, Sparkle, signing, notarization, DMG, cask, site, demo video, whole-branch review. Exit: installable build on a clean account.

**M9 V1.1.** Magnifier, pins, emphasis box, auto colour, localisation, auto-pause for full-screen video, profile import and export.

**Parallel research (no milestone):** custom cursor arrows via SkyLight, window-share mirror mode.

## 5. Order rationale
Settings first because every later feature reads from it. Effects before Ink because the trail and colour model are reused. Triggers before UI so the UI has real things to configure. UI before profiles because profiles are mostly UI. Share-safe and shipping last because they need the whole product to exist.

## 6. Decisions needed from the user (none block M1 to M4)
1. Name and icon (needed by M8).
2. Free tier shape and price (needed by M8).
3. Which of V1.1 magnifier, pins, emphasis box matters most (needed after V1).
