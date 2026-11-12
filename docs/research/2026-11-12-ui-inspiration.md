# UI inspiration for Beacon: onboarding, settings, popover

Date: 2026-11-12. Trigger: the first-run onboarding window was called "so vibe coded looking, bad look".
Method: Playwright (headless Chromium, 1440x900, ~850px scroll steps, 600ms waits), starting at macapp.supply, then each app's own site. Screenshots live in the session scratchpad under `inspo/<site>/` (not committed). Numbers below were read either from screenshots or from computed CSS on the live sites; they describe marketing sites, and where a site shows its real app window I say so.

## 0. Honest limits

- No site gave a full first-run onboarding video or permission-dialog walkthrough that headless screenshots could capture. The only real settings window seen at readable size was LookAway's (a screenshot inside its page). Onboarding and permission lessons therefore come from copy, product-window shots, and testimonials, not from a recorded flow. Treat those recommendations as design direction, not as copied specs.
- Long pages were capped at 14 viewports. Not fully scrolled to the footer: shotbase (about 20 viewports, stopped at pricing), hoy (about 19, stopped around the "Work with channel files" demo), raycast (about 19, stopped in the extension-API section), maccess (about 19), screen.movie (about 26, stopped mid features). Everything else was scrolled top to footer.
- Not studied (pages loaded but not scrolled past the grid): Notchi, Kiiwi, Glance, Panels, Superlist. Perch's own page is the maker "so & so" page, not the macapp.supply listing.
- Nothing here was tested on a real desktop; these are web pages, not the apps.

## 1. macapp.supply (the index)

Looked at: home (all 8 viewports of the inner scroller, the page is an app-shell with its own scrolling pane), Supply Picks (49 apps), Utility category (102 apps), Trending, individual listing pages (Perch, Alcove).

- The site itself is a lesson: a persistent 232px left sidebar (search with a cmd-K hint, grouped "Discover" and "Categories" lists with counts right-aligned in a lighter tone) beside one big rounded content panel (about 24px radius, 10px inset from the window edge). This is the macOS sidebar-plus-detail pattern, done on the web. It is the layout Beacon's settings window should feel like.
- Card grid: 3 columns, thumbnail first, then a 40px app icon with the name in semibold and a one-line description in secondary gray. Nothing else. No borders around the text, no badges besides a small verified check.
- Hero type is huge and tight (about 72px, heavy weight, negative tracking) with the second half of the sentence in mid-gray ("A curated shelf of beautifully designed macOS apps."). Two-tone headline instead of an accent color.
- Observed pattern across the thumbnails of 49 picked apps: almost all show a real product window or a single object (a dock, a keyboard, a turntable), not an illustration of features. Nearly all use one hero image with 3 to 6 words of text.

Apps chosen from it: Perch, Alcove, LookAway, Shotbase, Skud, Hoy, Maccess (as a counter-example), plus Raycast, CleanShot X, Bartender, Screen Movie from the Hot and Utility rows. 11 sites in total.

## 2. Per-app notes

### Perch (menu bar Reminders companion, madebysoandso.com/perch)
Sections viewed: hero, how it works, feature cards, "respects how you work", maker letter, FAQ (all 9 questions), final CTA, footer (9 viewports, full page).
- Computed type: system font stack (SF), h1 64px weight 600, tracking -2.88px (about -4.5%), line-height 67px; h2 48px/600; body 17px/26px. Background #F7F8FA, text #12151A, never pure black.
- Feature cards: 2-up grid, 24px-ish radius, fill one step darker than the page (no border, no shadow), small 13px gray eyebrow label ("Hotkeys", "Quick entry"), then a bold one-line promise ("In and out without losing focus."), then 2 to 3 lines of body.
- The product is shown as a menu bar panel over a calm landscape wallpaper, with a translucent material that picks up the wallpaper. This is the exact look a native popover has.
- Keys are rendered as real keycaps inline in body text (an option-space pair), not as a screenshot.
- Price line is blunt and small: "once: no subscription, no account. Requires macOS 14 or later."
- FAQ answers privacy as a flat fact: "No. Perch requires no account and makes no network connections." The permission FAQ ("Why does Perch need Reminders access?") exists as its own question, which is the right place to defend a permission.
- Footer ends with a letter from the maker with a photo. Personal, short.

### Alcove (Dynamic Island for the Mac, tryalcove.com)
Sections viewed: hero, interactive notch demo, feature icon grid, CTA, footer (3 viewports, short page).
- Warm cream background (#FFF0DF), h1 96px/700, tracking -2.4px, dark brown text. The accent is a single hand-drawn highlight (pink marker behind "Mac", a purple scribble circle on "native app").
- Feature icons are plain monochrome glyphs at about 32px with a two-line label, 4 columns, no cards. Restraint: no boxes at all.
- The demo is interactive ("Psst... it's interactive!"), so the first screen proves the product instead of describing it.

### LookAway (break reminder, lookaway.com)
Sections viewed: all 14 viewports, top to footer (hero, flow demo, testimonials, feature trio, "automatically pauses during", device sync, posture reminders, settings window, automations, "designed for the Mac", recent updates, guides, footer).
- Hero: h1 48px weight 500 (not bold), 14px sub copy. Near-black #070707 page, soft colored glows behind the icon. The nav is a floating pill with 24px radius.
- The settings window screenshot is the most useful single asset found (viewport 07). It shows: a sidebar about 210px wide with section headers in small gray semibold ("Focus & Wellbeing", "Behavior & Feedback", "Integrations"), each item a 22px rounded-square colored icon tile plus a 13px label, selected row a soft rounded highlight; a content pane with a 14px window-title row, section headings in semibold, and inset grouped rows (label left, control right) on a slightly lighter rounded card with 1px hairline separators. Value-with-chevron rows ("Every 3rd break is a 5 mins long break >") drill into sub-pages instead of piling controls on one screen. Choices with consequences (Casual, Balanced, Hardcore) are three preview cards with a one-line consequence under each, selected one outlined in system blue.
- Controls are native: pop-up buttons with up/down chevrons, steppers, real switches, a real slider with ticks and speaker icons at the ends. Nothing is a custom-drawn fake.
- Context rows: "Automatically pauses during" shows 5 chips, each with a colored icon tile and a plain label (Screen Recording, Meetings or Calls, Video Playback). Settings explained as situations, not as booleans.
- Takeaway for permissions: it states what it does around sensitive moments ("pauses during meetings or calls") rather than listing capabilities.

### Shotbase (capture and edit, shotbase.com)
Sections viewed: first 14 viewports (hero, video, logo strip, capture, editor, annotation, organize, local AI, share, wall of testimonials, start of pricing). Not seen: pricing details, FAQ, footer.
- Light page with a bright sky-blue accent and a black floating nav pill that includes a blue Download button.
- Product shots are real windows with a custom cursor and a labelled tooltip ("Tap to capture") placed on top, so the screenshot shows interaction, not just state.
- Section rhythm: pill eyebrow label (Capture, Editor, Organize, Share), 2-line heading at about 40px, one short paragraph, one big visual. About 25 words per section.
- Social proof is oddly specific and relevant: a wall of testimonials about the onboarding itself ("the best onboarding I've ever seen", "sickest onboarding experiences", "haptic feedback on the trackpads of the Switches"). The market notices onboarding craft, and the praise is for animation and haptics, not length.

### Skud (menu bar file delivery, skud.app)
Sections viewed: all 7 viewports.
- Very quiet: 2-line h1 at about 28px, a black Download button, and a blurred photographic hero. Feature list as 6 numbered cells ("01 - Drag, drop, done") with 12px labels. Pricing: two columns, $0 / forever and $8 / month, hairline-separated feature rows, no ribbons, giant faded wordmark in the footer.
- Menu bar popover is shown as a small white panel with a dashed drop zone ("Drag files here") and file rows with a "Copy link" pill. Minimal, one primary action.

### Hoy (drop anything to anyone, gethoy.app)
Sections viewed: first 14 viewports (hero with floating avatars, scroll-pinned demo scenes: hold to talk, drop a file on a face, show your screen, hand over a to-do, channel files in Finder). Not seen: last 5 viewports.
- The page is a sticky scroll tour: the tiny menu-bar strip stays at the top (icons, avatars, 18:08 clock) and the demo morphs below it while a 24px caption swaps ("Hold to talk." then "Drop a file on a face."). Each scene is 3 words.
- Neutral warm-white palette, system font, panels are translucent soft-gray with a large radius and a soft shadow, like real vibrancy.
- A progress checklist appears as a live demo of the tour itself (two items struck through, two open, "Reminder tomorrow, 9:00" below). First-run checklists can feel playful when each item is a verb.

### Raycast (raycast.com)
Sections viewed: 14 viewports (hero, clipboard history, extension carousel, AI chat, quicklinks and hotkeys, notes, community, extension API). Not seen: pricing and footer.
- Computed: Inter, h1 64px/600, h2 only 20px/500, body 18px, letter-spacing 0.2px, near-black #07080A, button 14px with 8px/12px padding and 8px radius, most panel radii 10 to 12px.
- The hero is one red graphic and one sentence ("Your shortcut to everything."). The product window is shown in context on a real desktop with menu bar.
- Hotkeys are shown as large keycaps (option + command + L) as a feature visual. Keycaps are treated as first-class UI.
- Copy pattern: a bold 1-line claim followed by a gray 1-line elaboration ("Take shortcuts, not detours. One interface, everything you need.").

### CleanShot X (cleanshot.com)
Sections viewed: all 14 viewports to the footer (hero, trust strip, recording features, markup, cloud, video editor, scrolling capture, background tool, OCR, built-for-Mac cards, testimonials, final CTA, footer).
- Computed: Google Sans Flex with SF Pro Display fallback, h1 60px/600, h2 40px/600, tracking -2%, body 18px/30px. Primary button blue, 14px radius, 15px type. Card radii mostly 20px, large feature tiles 48px.
- Directly relevant: its recording section has three small tiles, "Highlight every click", "Show keystrokes", "Add your camera", each shown as a real, tiny UI moment (a cursor ring on a button, a big keycap). This is Beacon's competitor feature set, shown with zero chrome.
- "Truly Mac-native / Make it yours / Designed exclusively for macOS" tiles: a native toggle is used as the "customize" illustration. Real controls double as decoration.
- Feature sections alternate: left text with 2 to 3 check bullets plus a secondary button, right a gradient-backed screenshot. Never more than 4 words per bullet.

### Bartender 7 (macbartender.com)
Sections viewed: all 9 viewports to the footer (hero, Golden Gate feature, feature grid, notch, themes carousel, pricing, FAQ, closing CTA).
- Computed: system font, h1 72px/800, h2 48px/800, tracking -2.88 and -1.44px, body 18px in #D4D4D4 on pure black. Buttons are fully pill-rounded, 13px.
- Feature grid of 4 dark cards where each shows one tiny diagram, not a screenshot (a toggle with lock, cloud and sun icons for "No Screen Recording Required"). This is the permission-reassurance pattern: the permission you do NOT need is a headline feature.
- Two-tone headline repeated three times ("Built for Golden Gate. Bridge, fog and all." / "Your menu bar, perfected. Now ready for what's next."). Consistent voice.
- Pricing: 3 cards, the middle one recommended with a thin white outline and a "Recommended" tag, one number at 28px.

### Screen Movie (screen.movie)
Sections viewed: first 14 viewports (hero, product window, problem statement, three options, three steps, features: pro results, speed, cursor motion, custom frames, light and depth). Not seen: pricing, FAQ, footer.
- Black page, a single animated gradient behind the icon, huge centered headline (about 44px, heavy, 2 lines).
- Feature rows: product window screenshot on one side with a rounded 24px dark card, heading about 22px bold plus gray 16px paragraph on the other, alternating. The app window is shown in full with its inspector panel, so settings are the marketing.
- Cursor settings are shown as a 3x3 grid of cursor style tiles with a size slider underneath ("Smooth cursor motion, so viewers never lose track"). The most relevant control layout for Beacon's Highlight and Ink and laser panes.

### Maccess (maccess.io), counter-example
Sections viewed: 14 viewports.
- Dark cards stacked on near-black, every feature in the same rounded card with a small icon tile top-left and an orange/pink glow phone mockup, a floating "Ask me anything" chat bubble that overlaps content. It reads as generic AI-landing-page: identical cards, decoration over product, gradient everywhere. Useful as the reference for what to avoid.

## 3. Synthesis: premium native versus generic vibe-coded

Blunt list drawn from the 11 sites. "Premium" items were present in at least 4 of the sites.

1. Materials. Premium apps show translucent, wallpaper-tinted panels (Perch, Hoy, LookAway's window). Vibe-coded SwiftUI uses opaque flat dark cards with a 1px border and a purple or blue gradient. If the onboarding window is a `.background(Color.black.opacity(...))` card inside a plain window, it will look like Maccess.
2. One accent, used rarely. Perch has one blue, Alcove one pink marker, Skud none (black button only). Beacon should not use the brand gradient on more than one element per screen.
3. Type is the system font, with a short scale. Observed: a hero at 48 to 72px, body at 17 to 18px, and almost nothing in between. In-window equivalents: 13px labels, 11px secondary captions, 22 to 28px for one title. Letter-spacing is tightened only on large sizes (about -2% to -4.5%). Mixed weights are rare: 600 for titles, 400 for body.
4. Headlines are sentences with a verb, in two tones (dark claim, gray elaboration), 3 to 8 words. Nobody writes "Welcome to X! Let's get you set up."
5. Real controls. LookAway's settings window uses real steppers, switches, pop-up menus and sliders, grouped rows with hairline separators. Vibe-coded apps fake these with custom capsules, custom checkboxes and card-per-setting layouts. A native Form with `.formStyle(.grouped)` already gives the correct look for free.
6. Settings organization: grouped sidebar (section headers like "Focus & Wellbeing"), colored icon tiles in the sidebar, drill-in rows for secondary options, and consequence previews for choices with side effects. Not tabs, not a long scroll of toggles.
7. Showing, not telling: Alcove's interactive notch, Hoy's scroll demo, CleanShot's keystroke and click tiles, Screen Movie's cursor-style grid. Each shows the real result in one frame with at most 3 words around it.
8. Restraint in density: 1 headline, 1 paragraph of at most 25 words, 1 visual per screen. Shotbase and Skud are around 20 to 25 words per section.
9. Keycaps rendered as keycaps (Perch, Raycast, CleanShot). A shortcuts screen made of rows of tiny gray pills reads as a table; large keycaps read as a feature.
10. Permissions: the winners either (a) make the absence a feature (Bartender: "No Screen Recording Required"), (b) answer it as a FAQ with a flat fact (Perch: "makes no network connections"), or (c) describe the behavior in context (LookAway: "pauses during meetings or calls"). None use a warning icon, a red lock, or a legalistic paragraph.
11. Onboarding praise in the wild is about craft (animation, haptics, speed), not about the number of steps (Shotbase testimonials).
12. A human voice somewhere: Perch's maker letter with a photo, Skud's plain pricing. The generic version has an emoji-free but identical-sounding "Welcome" screen.

## 4. Recommendations for Beacon

Format: change, then the source it comes from.

### 4.1 First-run onboarding (3 steps: shake demo, optional Input Monitoring, shortcuts)

General
- Use a normal titled window (no custom card), fixed about 560 x 420, with a translucent sidebar-less content area using `NSVisualEffectView` (sidebar or headerView material) behind a plain window background, so the wallpaper tints it. Source: Perch, Hoy panel materials.
- One idea per screen, structure: 1 headline (sentence with a verb, 28px semibold), 1 paragraph (max 25 words, 15px secondary), 1 visual, 1 primary button. Source: Shotbase, Skud, Perch.
- Two-tone headline: first clause in primary color, second clause in secondary label color. Source: macapp.supply, Bartender.
- Replace any step dots or "Step 1 of 3" chip with a thin native-looking progress (3 small dots, 6px, secondary color). Never a gradient progress bar. Source: Hoy, LookAway.
- Primary button is the standard macOS prominent button (system accent, 28px tall, 6 to 8px radius). Secondary "Skip for now" as a plain text button. Do not make a custom gradient pill. Source: Raycast button (8px radius), Skud (single black button).
- Accent: exactly one brand color across all three screens, on the primary button and on the demo cursor halo only. Source: Perch, Alcove.
- Keep to 3 screens, but make step 1 the product, not text.

Step 1, shake demo
- Make it live and tiny: a plain area where the real Beacon cursor effect fires when the user shakes, with caption "Shake your cursor." and the secondary line "That's all it takes to find it." Source: Alcove's interactive "Psst... it's interactive", Hoy's three-word captions.
- Show a tooltip chip near the cursor ("Shake to find") like Shotbase's "Tap to capture" annotation, then fade it once the first shake is detected. Source: Shotbase.
- On success, animate the checkmark with a short spring and enable the Continue button. Add a subtle haptic (`NSHapticFeedbackManager`, alignment pattern) when the highlight appears. Source: Shotbase testimonials (haptic feedback, animation).

Step 2, optional Input Monitoring
- Lead with what Beacon does not need: title "No Screen Recording. No Accessibility." Sub-line: "Input Monitoring only lets Beacon see global shortcuts. You can skip it." Source: Bartender ("No Screen Recording Required" as a feature).
- Show a small diagram (the system Privacy pane toggle in the off and on state) rather than a shield or lock icon. Source: Bartender's toggle illustration.
- Two buttons: "Open System Settings" (prominent) and "Skip" (plain). After returning, show a green check row "Input Monitoring: allowed" or a neutral "Skipped, you can enable it later in Triggers" with no red text. Source: LookAway (explains by situations), Perch (flat factual privacy copy).
- One factual line under the buttons, 12px secondary: "Beacon never records keystrokes or sends anything off your Mac." Source: Perch FAQ phrasing ("makes no network connections").

Step 3, shortcuts summary
- Render shortcuts as big keycaps (about 40px tall, 8px radius, 17px mono-ish symbols), 3 rows max, each with a 2-word label ("Highlight", "Laser", "Ink"). Source: Raycast option+command+L, Perch inline keycaps, CleanShot keystrokes tile.
- A native-looking "Change in Settings" text link; no extra explanation. Finish with "Start using Beacon" and a note that the app lives in the menu bar, optionally pointing an arrow at the real menu bar position. Source: Hoy's menu-bar strip, Perch.

### 4.2 Settings window (sidebar: Highlight, Ink and laser, Triggers, Profiles and apps, Displays, About)

- Use `NavigationSplitView` or an `NSSplitViewController` with a real sidebar list, width about 200 to 220px, items 13px with a 20 to 22px rounded-square icon tile (colored per section, white glyph), group headers in 11px semibold secondary ("Appearance", "Behavior", "System"). Source: LookAway settings window, macapp.supply sidebar.
- Suggested grouping: Appearance (Highlight, Ink and laser), Behavior (Triggers, Profiles and apps), System (Displays, About). Source: LookAway's "Focus & Wellbeing / Behavior & Feedback / Integrations".
- Each pane is a `Form` with `.formStyle(.grouped)`: section title in semibold, inset rows with label left and control right, hairline separators. No custom card-per-setting. Source: LookAway.
- Pane title row (about 14px semibold) with the section's icon tile at left, then content, never a giant in-pane H1. Source: LookAway ("Screen Breaks" bar).
- Highlight and Ink panes: add a live preview strip at the top of the pane (a small view that renders the current highlight or ink stroke), then controls below. For cursor look choices use a 3x3 grid of selectable tiles with an outline of system blue on selection and the size slider underneath with min and max glyphs at the ends. Source: Screen Movie cursor panel, LookAway's three consequence cards.
- Choices with side effects (for example laser fade time or ink persistence): three cards (Subtle, Balanced, Dramatic), each with a one-line consequence under it. Source: LookAway Casual/Balanced/Hardcore.
- Triggers pane: show the shortcut recorder as a real keycap-styled field, plus a drill-in row for advanced triggers ("Shake sensitivity, Normal >"). Source: LookAway drill-in rows, Raycast keycaps.
- Profiles and apps: a native table or list with app icons at 20px and an inline pop-up for the profile per app; empty state is one sentence and one "Add app" button. Source: LookAway "pauses during" chips (app-as-situation).
- Displays: show actual display rectangles as a small diagram (rounded rects, with the active one outlined in accent), not a text list. Source: Bartender's menu-bar diagrams as illustration.
- About: app icon at 96px, name 20px semibold, version in 12px secondary, a flat one-line privacy statement and 3 text links (Website, Changelog, Contact). Source: Perch footer and FAQ tone, Skud footer.
- Window: standard titlebar with hidden title but unified toolbar look, minimum size around 700 x 500, no extra gradient or glow. Source: macapp.supply content panel, LookAway.

### 4.3 Menu bar popover

- Use `NSPopover` or a `MenuBarExtra(.window)` with the system popover material (`.popover` / `hudWindow` vibrancy), width about 300 to 320px, corner radius supplied by the system, padding 12px. Source: Perch and Hoy panel materials.
- Content order: status row (one line: "Ready" or "Share-safe: on", with the single accent dot), 3 quick toggles (Highlight, Laser, Ink) as native switches or toggle buttons with their keycaps on the right in secondary color, then profile pop-up, then footer row ("Settings..." with cmd-comma, "Quit"). Source: Skud (single primary action), Perch (keys shown at right).
- No cards inside the popover; use plain rows and a hairline divider between groups. Source: LookAway grouped rows.
- Footer row 12px secondary text, no decorative icons. Source: Raycast restraint.
- Hover state is the standard row highlight in accent at 15% opacity, no custom glow.

### 4.4 Cross-cutting rules to adopt

- One typography scale: 28 title / 17 body / 13 label / 11 caption, SF only, tracking tightened only on the title. Source: Perch, Raycast, CleanShot.
- One corner radius family: 8 for controls, 12 for cards, 20 for large panels. Source: Raycast panel radii (10 to 12), CleanShot (12, 20).
- Copy: sentence with verb, under 8 words for headlines, one gray elaboration, no exclamation marks. Source: Bartender, Raycast.
- Use system colors (`Color.accentColor`, `.secondary`, `NSColor.windowBackgroundColor`) and let dark mode follow the system. Source: Perch ("Follows light and dark mode").
- Review gate before shipping onboarding: it fails if any screen has more than one gradient, more than 25 words, a custom-drawn switch, or a card inside a card.

## 5. Sources and what was taken from each

| Source | Taken |
| --- | --- |
| macapp.supply | sidebar plus detail layout, grouped list with counts, two-tone headline |
| Perch | materials, keycaps in text, flat privacy copy, card eyebrow labels |
| Alcove | interactive demo, restraint with icons, single accent |
| LookAway | settings window anatomy (grouped sidebar, icon tiles, grouped rows, consequence cards), "pauses during" |
| Shotbase | annotated cursor tooltips, onboarding craft as selling point, section rhythm |
| Skud | minimal popover, single primary action, quiet pricing |
| Hoy | sticky tour with 3-word captions, menu bar strip, checklist as demo |
| Raycast | keycaps as features, type scale, 8px controls |
| CleanShot X | click and keystroke highlight tiles, native toggle as illustration |
| Bartender | permission-absence as a feature, tiny diagrams |
| Screen Movie | cursor style grid and size slider, app window as the marketing |
| Maccess | counter-example: identical dark cards, glows, floating chat bubble |
