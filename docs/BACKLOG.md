# Beacon feature backlog

Written 2026-11-12. Pick one item at a time. `docs/ROADMAP.md` stays the milestone plan; this file is the menu of what to build next, after the settings, floating bar and design work.

Each idea has a size (S a day or less, M a few days, L a week or more), whether it needs a new permission, and a one-line why.
Permission key: **none** keeps the "no Screen Recording, no Accessibility" promise. **Input** is optional Input Monitoring. **Screen** is Screen Recording, which breaks the promise, so those are parked on purpose.

## Done

- Highlight: five styles, color (presets and custom), size, intensity, one option per style, click ripples, fade when still, hide in full-screen apps and video players
- Laser, ink with eight colors, five pens, thickness, seven snapped shapes, fade switch, undo and clear
- Scenes: reorder, duplicate, rename in place, per-app rules, default scene, next-scene shortcut
- Triggers: shake, double-tap, hold, rebindable shortcuts with conflict checks
- Share-safe status with a manual declaration, call-app icons
- Display scope, real Mac preview with three scenes
- Floating bar: tools, quick colors, scene menu, drag, collapse, hide from screen sharing, hover chips
- Settings window: canvas and inspector, six pages

## Next

1. **Spotlight rectangle** (M, none). Drag a region, everything else dims, the region stays clickable. Details in the design notes at the end.

## Presenting tools (high value)

| Idea | Size | Permission | Why |
|---|---|---|---|
| Text labels: click, type, it stays or fades | M | none | The most asked-for annotation after arrows |
| Number stamps: 1, 2, 3 step markers, check, cross | S | none | Walkthroughs and bug reports |
| Whiteboard mode: blank white or black board to draw on | S | none | Explain without a slide |
| Redact box: an opaque cover over something | S | none | Hide a secret live; cosmetic, not a real blur |
| Filled translucent box (highlighter box) | S | none | Faster than a pen for emphasis |
| Eraser | S | none | Fix one stroke without clearing all |
| Straight lines with Shift | S | none | Common drawing habit |
| Persistent drawing mode and clear on a second press | S | none | Strokes that stay until you say so, with an obvious way out |
| Pointer arrows: curved arrow, double arrow, bracket | S | none | More ways to point |
| More snapped shapes: star, heart, check mark, cross, speech bubble | M | none | Needs careful recognition work |
| Countdown and presenter timer chip | S | none | Keeps a talk on time |
| Click-and-hold focus ring | S | none | Draws the eye to what you hold |
| Numbered pins that fade | S | none | Quick "look here, then here" |

## Cursor and effect designs

| Idea | Size | Permission | Why |
|---|---|---|---|
| Custom cursor skins: arrow variants, crosshair, ring, big colored cursor | L | none (private API behind a fallback) | The original "polished cursor skins" goal |
| More click effects: burst, double ring, pulse, optional sound | S | none | Variety, and sound helps recordings |
| Always-on subtle ring around the cursor | S | none | A calm "find my cursor" |
| More highlight styles: crosshair, spotlight follow, aurora, pixel, halo | M | none | Cheap to add once the style recipe is stable |
| Cursor locator pulse when the pointer jumps displays | S | none | Multi-display presenters lose it |
| Auto color that stays visible on light and dark | M | none | One look that always reads |
| Color-blind-safe palette check | S | none | Accessibility |
| Reduce motion mode | S | none | Honors the system setting |
| Hide the cursor when idle | S | none | Clean recordings |
| Pressure and speed based pen width | M | none | Nicer strokes with a tablet |

## Control and automation

| Idea | Size | Permission | Why |
|---|---|---|---|
| `beacon://` URL scheme and Shortcuts actions | M | none | Stream Deck, Raycast, Alfred, scripts |
| Presentation clicker support: map clicker buttons to laser and next scene | M | Input | Presenters already own clickers |
| Mouse side-button trigger | S | Input | Hands stay on the mouse |
| Per-scene shortcuts | S | none | Jump straight to a scene |
| Calendar-aware scene: switch to Meeting when an event starts | M | Calendar | Fully hands-off |
| Floating bar: choose the display, thickness and shape controls, second row | M | none | Finishes the bar |
| Floating bar quick-add for text and stamps | S | none | Comes with those tools |
| Menu bar popover redo | M | none | Planned after the features |
| Welcome guide redo | M | none | Planned last |

## Scenes and sharing

| Idea | Size | Permission | Why |
|---|---|---|---|
| Export and import scenes as files | S | none | Share a look with a team |
| Built-in scene presets: Meeting, Recording, Teaching, Dark app | S | none | Good defaults from minute one |
| Scene gallery with preview | M | none | Browse and pick visually |
| Per-display scenes | M | none | A different look on each screen |
| Auto scene by app category (video call, editor, browser) | S | none | Fewer rules to write |
| "Viewers see" preview: shows what an audience gets, including a window share hiding effects | M | none | Makes share-safe visible |
| Better share detection (private SkyLight calls, behind a fallback) | L | none | Replaces the manual declaration if it proves reliable |

## Needs Input Monitoring (optional)

| Idea | Size | Why |
|---|---|---|
| Keystroke display like KeyCastr | M | Tutorials and demos |
| Click and key sounds | S | Recordings |
| Type-to-hide: hide the highlight while typing | S | Less clutter |

## Parked (breaks "no Screen Recording")

- Magnifier or zoom following the cursor
- Live blur of part of the screen
- Screen recording or GIF capture
- Color picking from the screen beyond the eyedropper

## Business and polish

| Idea | Size | Why |
|---|---|---|
| Name, icon, domain, site | L | Owner decisions, see `docs/RELEASING.md` |
| Signing and notarization, Sparkle key | M | Needed to ship |
| Pro tier split (bar, stamps, scene sharing) | S | Decide once features settle |
| Localization (French first) | M | The owner writes in French |
| Accessibility pass: VoiceOver labels, full keyboard use | M | Quality bar for a paid app |
| Performance and battery pass on the overlay | M | Overlay work runs all day |
| Real-desktop checks: multi-display, Stage Manager, real call apps | M | Recorded as not verified so far |

## Design notes: Spotlight rectangle

**What it is.** A region you choose stays bright and everything else dims. It is the "look at this part" tool that Lens only does around the cursor.

**How you use it.** Press the shortcut or the bar button. The cursor becomes a crosshair. Drag a rectangle. The rest of the screen dims, and the lit region stays fully clickable: the overlay lets clicks through, so you can keep working inside it.

**Adjusting.** Press the shortcut again to edit: drag a handle to resize, drag inside to move, drag outside to draw a new one. Esc or a third press ends it.

**Options (Look page, per scene).** Shape: rectangle, rounded rectangle or ellipse. Dim strength. Soft edge. Corner radius.

**Extras worth having.** A "follow window" mode that snaps the region to the window under the cursor. Several regions at once. A brief entrance animation that closes in from the full screen.

**Built from what exists.**
- A pure `SpotlightModel` (region, shape, dim) with unit tests, like the ink model.
- A renderer that draws the dim as one layer with a hole, like Lens.
- The ink input window pattern to capture the drag, then switch to click-through.
- A shortcut action, a bar button, scene settings, and a share-safe note that viewers see the effect only on a whole-screen share.

**Open questions.** Multi-display (a region lives on one display), what Esc does while editing, whether the dim should also cover the floating bar (it should not).
