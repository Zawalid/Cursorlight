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
- Spotlight region: drag a lit region, shape, dim, soft edge, click-through
- Presenting tools: text labels, number stamps (also fading pins), check, cross, star, heart, question and exclamation stamps, whiteboard (white or black), cover box, filled translucent box, eraser, arrow, double arrow, bracket, Shift for straight lines, persistent strokes (the fade switch), presenter timer chip

## Next

Nothing queued. Pick from the lists below. Left over from presenting tools: curved arrow, speech bubble stamp, a click-and-hold focus ring.

## Presenting tools (high value)

| Idea | Size | Permission | Why |
|---|---|---|---|
| Curved arrow | S | none | Straight, double and bracket arrows are done |
| Speech bubble stamp | S | none | Star, heart, check and cross stamps are done |
| Click-and-hold focus ring | S | none | Draws the eye to what you hold |

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
