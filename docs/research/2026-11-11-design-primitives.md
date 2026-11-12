# Cursor effect design primitives (research brief, 2026-11-11)

Purpose: learn what premium cursor effects do so the next Beacon design is not a tight, lagging 40 pt ring. Primitives only, nothing copied.

## Sources and honesty notes
- Numbers marked (S) are published or read from source. Marked (J) are my engineering judgment, to be tuned in the effect lab.
- Read via Playwright (headless Chromium): Screen Studio site plus guide (cursor, animations, smooth movement), Mouseposé, Presentify (home, highlight, spotlight, zoom guides), Cursorful (incl. live cursor-effects demo text), CleanShot X features, Kap, Raycast, Linear, PowerToys utilities docs, ZoomIt docs. Whole-page viewport sweeps taken for Screen Studio (30), Presentify (14), Cursorful (14), Raycast (16), Linear (13), Mouseposé (5). CleanShot X: first 10 of ~30 viewports looked at (rest is screenshots/OCR, irrelevant); its recording options came from page text.
- Not reachable: Cursor Pro (timeout), Mouzz (DNS). Kap page has one line about highlighting clicks, no parameters.
- Marketing videos were blocked for reliable screenshots, so live motion was not observed; motion numbers come from docs and source, not from watching clips. Screen Studio does not publish spring numbers (only presets Smooth / Medium / Rapid). The only hard spring and ripple numbers are from CapSoftware/Cap (open source, same post-processed-cursor model): crates/project/src/configuration.rs, rendering/src/shaders/click-ripple.wgsl.
- Taken per site: Screen Studio = cursor settings model (smoothing presets, motion blur, hide when idle, rotate while moving, stop at end). Cursorful = "gray raw cursor vs green smoothed cursor" framing, sway and blur on fast moves. Mouseposé = spotlight params (a product screenshot shows radius 112 px, blur 23 %, animate zoom 0.4 s, deactivate after 10 s). PowerToys = default radii, durations, ripple ranges, shake summon. Presentify = shape choices, toggles, auto-erase ink. CleanShot = click highlight options. Raycast and Linear = glow stacking, easing curves, spring-with-overshoot via CSS linear().

## 1. Premium versus cheap
What separates them (all consistent across sources):
1. Motion is a spring, never a fixed-duration tween chasing the target. Cap/Screen Studio presets are all near critically damped (zeta 0.77 to 0.99). Raycast uses easeOutQuint/Expo curves (.23,1,.32,1), (.16,1,.3,1), (.165,.84,.44,1) and a spring baked into linear() with about 3 % overshoot. Linear uses (.32,.72,0,1). Nobody uses plain ease-in-out or linear for entrances.
2. Soft light, not hard strokes. Raycast glow = 3 stacked shadows at 3 to 5 % alpha, 40 px blur, plus 16 px tight layer; blur filters 10/20/36 px. Many faint layers beat one strong one.
3. Asymmetric timing: in fast (200 to 400 ms, out-expo), out slower and softer (250 to 500 ms). Everything decays by alpha power curve, not linear.
4. Restraint: one effect per moment; idle state is nearly invisible; effects auto-end (Mouseposé "deactivate after 10 s", PowerToys fades after mouse stops, Screen Studio "hide cursor when idle" default 2 s).
5. Consistent physics: cursor, trail, ripple all share one spring family so they feel like one object.

Making 1 to 3 frames of lag look intentional (our overlay cannot lock to hardware cursor):
- Lag is only ugly when it is small, variable and visible against the arrow tip. At 2000 pt/s, 2 frames at 60 Hz (33 ms) is 66 pt; at 300 pt/s it is 10 pt. Frame-to-frame jitter is what reads as "broken", not the average delay.
- Rule 1: never place a tight shape on the tip. Use a big soft body (radius 40 pt and up, feathered) so a 10 to 15 pt offset is inside the glow. A thin ring (the rejected design) exposes every pixel of error.
- Rule 2: low-pass the follower with a critically damped spring (omega 16 to 22 rad/s, zeta 1.0). Time constant about 60 to 90 ms swallows 16 ms frame jitter, so the delay is constant and reads as weight. Cursorful's own demo frames this explicitly: raw cursor gray, smoothed cursor colored.
- Rule 3: converge to exactly zero offset at rest within about 250 ms (settle time 4/(zeta*omega) = 200 ms at omega 20). A halo that stops 6 pt off-center looks cheap; one that glides in and locks looks premium. Snap residual under 0.5 pt.
- Rule 4: let velocity shape the effect so lag becomes motion: stretch the halo along velocity (scale x 1 to 1.35, squash perpendicular 1 to 0.9), tilt (Screen Studio "rotate cursor while moving", Cap rotation_amount 0.15), or spawn a trail. The trailing is the design.
- Rule 5: sample latest position at draw time on the display-link tick (not per event), and add short velocity prediction (position + v * 8 to 16 ms, clamp 12 pt) only to shave the average delay, never to drive the spring target past the pointer.
- Rule 6: hide the real cursor offset by anchoring on the hotspot, glow centered on hotspot plus (0, 0), not on the arrow bitmap center.
- Offline apps (Screen Studio, Cursorful, Cap) look perfect because they re-render the cursor with lookahead (Cap uses 500 ms click lookahead). We do not have lookahead: do not copy their tension values blindly; pick a snappier spring (section 2).

Screen-share specific (the hidden constraint): shared video is typically 15 to 30 fps, heavily compressed, and a 5K or 4K display is downscaled to about 720p to 1080p (3 to 4 times smaller).
- Minimum feature size after downscale 3 px, so on retina keep ring strokes at least 4 pt and halo diameters at least 72 pt.
- Effects shorter than about 250 ms can fall between frames at 15 fps. Click ripples should last at least 450 ms.
- Large smooth gradients band in H.264. Keep dim at flat opacity with a feathered edge; add 1 to 2 % noise or avoid mid-alpha huge gradients if banding shows.
- Use luminance contrast, not hue: light core plus thin dark keyline so it reads on white and dark apps.

## 2. Numeric recipes
Spotlight (dim plus cutout)
- Radius: 90 to 140 pt, default 110 (S: Mouseposé 112 px, PowerToys 100 px default, Presentify has size shortcuts). Larger 180 to 260 for panels.
- Feather: 20 to 25 % of radius (S: Mouseposé blur 23 %). Use smoothstep from 0.78R to 1.0R.
- Dim: black at 0.45 to 0.60, default 0.50 (J; PowerToys default backdrop is black with user alpha, Mouseposé is a slider). Over 0.65 hurts readability on video.
- Entrance: 400 ms (S Mouseposé 0.4 s, PowerToys 500 ms default) radius from 2.2R to R plus dim 0 to target, ease out-expo (.16,1,.3,1). Exit 250 ms ease-in (.4,0,1,1)-ish. Follow with the 90 ms spring.
- Auto behavior: dismiss on click or keypress (S PowerToys), optional auto-off 10 s (S Mouseposé).

Glow halo (soft, always-on capable)
- 3 layers, radial gradients, center on hotspot: core r = 0.45R alpha 0.35; mid r = R alpha 0.16, blur 12 pt; outer r = 1.9R alpha 0.06, blur 32 pt (J, scaled from Raycast 5 % alpha layers with 16/40 px blur).
- R = 36 to 48 pt (diameter 72 to 96 pt). Optional 1 pt keyline ring at R alpha 0.25 dark or light to match contrast.
- Idle breathing: scale 1.0 to 1.04 over 2.4 s ease-in-out, alpha plus or minus 0.03 (J). Pause breathing while moving.

Follower spring (mass 1, tension = omega^2, friction = 2*zeta*omega)
- Reference (S, Cap presets, tension/mass/friction; omega, zeta, 2 % settle): Smooth 80/2.5/28 (5.7, 0.99, 0.70 s); Slow 200/2.25/40 (9.4, 0.94, 0.45 s); Mellow default 470/3/70 (12.5, 0.93, 0.34 s); Fast 380/1/30 (19.5, 0.77, 0.27 s); click spring 530/1/40 (23, 0.87). The default Cap preset settles in about 0.34 s.
- Beacon live halo: 400/1/40 (omega 20, zeta 1.0, 200 ms settle) default; "Silk" 196/1/28 (omega 14, 285 ms); "Snappy" 625/1/50 (omega 25, 160 ms). No overshoot for position. Allow zeta 0.75 only for scale or click pop.
- Idle hide (S Screen Studio): 2.0 s; hold halo alpha at 0.35 when idle if always-on.

Trail (laser)
- Time-stamped points, lifetime 350 to 450 ms, fade by age not by count (event time, so frame drops do not lengthen it). Up to about 48 points, resample at 4 to 6 pt spacing, Catmull-Rom smooth. (J)
- Width taper head 10 pt to tail 1 pt, power 1.6 (w = 10 * (1 - age/life)^1.6). Alpha head 0.95 to 0 with (1 - age/life)^1.5.
- Two passes: crisp core 3 pt near-white, plus glow pass 12 to 14 pt blur at alpha 0.45 in the accent color. Head dot 14 pt with a 28 pt halo.
- Dwell: when speed under 40 pt/s, shrink the tail in 150 ms so it does not smear.

Click ripple
- Reference (S): Cap ring radius = 1.0 - (1-t)^3 (ease-out cubic), ring width 10 % to 16 % of radius as t goes 0 to 1, inner fill 30 %, alpha = 0.7 * (1-t)^1.5, duration 0.6 s (range 0.2 to 1.5), radius 1.25 times cursor height, max 6 concurrent. PowerToys Ripple: size 60 px (10 to 300), intensity 0.7 (0.15 to 1.35), 480 ms (60 to 2000), follow-cursor while held, release pulse. Mouseposé: one circle per click count (double click = 2). CleanShot: color, size, outline or filled, animation toggle, separate left/right colors (S also PowerToys, Mouseposé).
- Beacon: 520 ms; ring radius 10 pt to 40 pt ease-out cubic; stroke 3 pt to 1.5 pt; fill 0.18 to 0 ; alpha 0.7 * (1-t)^1.5; mouse-down 120 ms shrink to 0.85 press ring, mouse-up fires the ripple. Left and right clicks differ by hue and by ring versus double ring.

Ink
- Pen 3 to 5 pt (default 4), marker/highlighter 20 to 28 pt at alpha 0.35 multiply, round caps (J; Presentify and ZoomIt offer pen and highlighter, ZoomIt resizes with Ctrl+wheel). Smoothing: Catmull-Rom plus 1 pt min distance, velocity widening 0.9 to 1.15 at most.
- Fade: hold 1.5 to 2.5 s after last stroke (S: Presentify auto-erase after a set delay), then erase tail-first along the stroke over 700 to 900 ms, ease-in (.4,0,1,1), final alpha fade last 200 ms. Optional glow 8 pt at 0.25 under the stroke.

## 3. Five style directions
1. Aura: soft frosted glow that blooms around the pointer; calm, expensive. Glow halo above (R 42 pt, three layers), spring 400/1/40, velocity stretch 1.3, idle breath, ripple fill 0.18, accent a single warm or cool hue at 0.35/0.16/0.06 alpha.
2. Lens: a lit circle in a dimmed room, theatrical and authoritative. Spotlight R 120 pt, feather 23 %, dim 0.5, in 400 ms out-expo, spring 196/1/28, shrinks to 0.8R on mouse down (120 ms) and returns; ripple is a white 2 pt ring only.
3. Comet: a bright head with a tapering tail, playful and energetic. Trail life 400 ms, width 10 to 1 pt power 1.6, core 3 pt plus 14 pt glow, head 14 pt, spring 625/1/50, tail color shifts hue 25 degrees head to tail.
4. Keyline: a thin precise two-tone ring that reads on any app, technical and sober. Ring R 28 pt, stroke 3 pt light plus 1 pt dark outer at 0.35, no glow, spring 400/1/40, ripple outline only (3 to 1.5 pt, 450 ms), press shrink to 0.85. Compensate lag with prediction 12 ms and a 4 pt inner dot so the tip is never exposed.
5. Sonar: hidden until summoned by shake, then concentric pulses lock onto a compact dot. Playful but useful. 3 rings, radius 140 to 20 pt over 600 ms staggered 80 ms, alpha 0.5 to 0, then the dot (R 18 pt, soft glow) rides the spring 400/1/40 for 2 s of idle and fades 400 ms. (Concept from PowerToys Find My Mouse spotlight closing in, S 500 ms.)

## 4. Behavior models in the wild
- Always-on halo, toggled by hotkey (Presentify Ctrl+S, PowerToys Highlighter Win+Shift+H, Crosshairs): constant orientation for viewers, risk of visual noise and dropping into recordings forever.
- Hold-key / hotkey spotlight (Mouseposé hotkey dims the screen with elegant start/stop, Presentify Ctrl+L): strong focus, but dimming for long periods is tiring and breaks other overlay apps.
- Summon on shake or double-tap (PowerToys Find My Mouse: double Ctrl or shake, dismisses on click/key or soon after mouse stops; macOS shake-to-find): great for "where is my cursor", zero interference when not needed.
- Click-only feedback (CleanShot, Kap, PowerToys Ripple, Mouseposé): cheapest way to help viewers follow actions; encode click events not position.
- Post-processed cursor (Screen Studio, Cursorful, Cap): not live; irrelevant to screen share, only a source of motion language.

Best for screen-sharing presenters: a hybrid, not a single mode.
(1) Click ripple always on (default on). (2) Light always-on halo optional, off by default, toggled by hotkey. (3) Hold a modifier (for example hold Right Option, or Caps tap) for temporary Lens spotlight, releases cleanly; shake to summon Sonar. (4) Laser/ink only while a key is held, then fade, so nothing lingers on screen. Everything ends itself. Hold-key plus click ripples gives the best focus per second of attention.

## 5. Things to avoid
- Tight thin ring on the pointer, anything where a few points of lag is visible (the rejected design). Small spring overshoot on position (wobble reads as laggy).
- Fixed-duration tweens toward a moving target (stutters on retarget), linear or default ease-in-out, effects shorter than 250 ms.
- Counting trail points instead of using event time (trail length varies with frame rate).
- Hue-only contrast, neon on white, dim over 0.65, hard-edged spotlight, banded giant gradients.
- Always-on motion that never rests, breathing while moving, rainbow cycles, sounds by default.
- Blurry sub-pixel strokes: snap rings to half-points on retina; do not rasterize glows every frame, cache the radial gradient.
- Hiding or replacing the real cursor (we cannot lock to it); effects must degrade gracefully when the app drops frames.
- Copying any app's look: keep the primitives above, choose our own palette and shapes.
