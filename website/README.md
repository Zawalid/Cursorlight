# Cursorlight website

The product site for Cursorlight. Astro (static output), GSAP and Lenis for motion, deployed to Cloudflare as a Worker with
static assets. Same tooling as the Lopper and Apropos sites; its own design.

## The idea: the page is the product

The site presents itself with the app's own tools, and lets the visitor use them.

- **Opening demo.** A presenter's cursor (an arrow in a ring) shakes until the highlight finds it, then circles the headline
  with a rough loop that snaps clean. The visitor's first mouse move or key press hands the page over. `src/scripts/ghost.ts`.
- **A web version of the app, site wide.** One fixed canvas (`src/scripts/engine.ts`) draws highlight (six styles), laser, ink
  and spotlight over the whole page. Shake the mouse anywhere and a highlight finds the cursor. In the hero, press and hold for a
  laser, press and drag for ink. A floating bar (`Toolbar.astro`) and the app's own shortcuts work on the page:
  Control+Option+H, L, I, S, P, and Escape to stop. The menu bar icon at the top right shows idle, on or paused.
- **The header is a menu bar**, with the current section highlighted like an open menu, and the real menu bar popover hanging
  under the icon in the hero.
- **Pointer skins on the page.** Click a skin in the Scenes section and it replaces the visitor's pointer until Escape
  (`src/scripts/skins.ts`). The skins are drawn for the page; the app's own are in the screenshot.
- **Links that run.** In the links table, each `cursorlight://` row has a Run button that does the same thing on the page.
- **Pinned tour.** A scroll-driven camera moves across the real captures, swaps captures, and draws ink around what the caption
  is about (`Tour.astro`, `src/scripts/tour.ts`, beats in `src/data/tour.ts`). Real pixels only; nothing is mocked.
- **Ink marks** (loops and underlines, `Mark.astro`) are generated at build time with hand-like wobble, and drawn on scroll.
- **Iris openings.** The light sharing section and the ember finale open like an aura from their top edge as they arrive.
- **Calm fallback.** Touch devices, narrow windows, `prefers-reduced-motion` and no-JS get no canvas, no pin and no iris: the
  headline word is circled in static ink, the tour becomes a stacked list from the same beats, and everything is visible.
- Colors: ember `#FF5A36` on charcoal `#14121A`, warm paper for the sharing section, full ember for the finale. Fonts, self-hosted
  in `public/fonts/`: Mona Sans (one variable file, weight and width axes) and Geist Mono for keys and code.

## Run it

```bash
cd website
npm install --legacy-peer-deps
npm run dev          # http://localhost:4321
npm run build        # static site in dist/
npm run preview -- --port 4380
```

With the preview running, in another terminal (all use `playwright-core` with the system Chrome):

```bash
node scripts/check-seo.mjs http://localhost:4380    # titles, canonical, JSON-LD, share image, links, dashes, emoji, external requests, layout shift
node scripts/check-a11y.mjs http://localhost:4380   # axe at 1440 and 390, with and without motion, plus horizontal scroll
node scripts/check-ui.mjs http://localhost:4380     # the demo, hero gestures, shortcuts, toolbar, style picker, skins, links table, tour, sharing, FAQ, focus, fallbacks
node scripts/shots.mjs http://localhost:4380        # the hero, the tour at six scroll positions, every section, desktop and phone, into .checks/
npm run og                                          # redraws public/og.png from scripts/og.html
```

`npm run build` is the gate; Astro strips types, there is no separate type check.

## Screenshots

The files live in `../docs/images/` (the main project captures them). `npm run build` first copies them into `src/assets/shots/`
(`scripts/sync-shots.mjs`), then cuts the macro crops the page uses (`scripts/make-crops.mjs`, rectangles in
`src/data/crop-defs.json`) from the lossless originals. Full captures are named in `src/data/shots.ts`; a missing file renders
as a clearly marked placeholder frame, and `check-seo.mjs` warns while any remains. To swap a picture: drop the file in
`docs/images/` with the same name and rebuild. If a capture changes layout, re-check the crop rectangles and the ink coordinates
in `src/data/tour.ts` (picture pixels).

## Configuration in one place

`site.config.mjs` holds the domain and the repository. Everything else reads it: `astro.config.mjs`, `src/data/site.ts`
(links, download URL), `robots.txt`, the sitemap, canonical links, the check scripts. Both values are **unconfirmed**
(`cursorlight.zawalid.com`, `Zawalid/Cursorlight`). `wrangler.jsonc` cannot import it, so change its `routes` host too. The
version shown on the page is read from `../App/project.yml` (`MARKETING_VERSION`) at build time.

The download button points at `https://github.com/Zawalid/Cursorlight/releases/latest/download/Cursorlight.dmg`. It 404s
until a published release carries an asset with exactly that name (the install guide names it `Cursorlight-<version>.dmg`, so
the release workflow needs a fixed-name copy, or change `links.download` in `src/data/site.ts`).

## Deploy (prepared, not run)

`../.github/workflows/pages.yml` builds `website/` and runs `npx wrangler deploy` on every push to `main` that touches
`website/**`, or by hand. To go live:

1. Create the GitHub repository (confirm the name; change `REPO` in `site.config.mjs` if it is not `Zawalid/Cursorlight`) and push.
2. Confirm the domain. Change `DOMAIN` in `site.config.mjs` and the `routes` host in `wrangler.jsonc`, and rerun `npm run og`
   only if the image text changes. The zone must be on the same Cloudflare account, so Cloudflare can create the DNS record and certificate.
3. Create a Cloudflare API token (Workers Scripts: Edit and DNS: Edit) and set two repository secrets, reading the values from
   stdin so they never print: `gh secret set CLOUDFLARE_API_TOKEN --repo OWNER/REPO` and
   `gh secret set CLOUDFLARE_ACCOUNT_ID --repo OWNER/REPO`.
4. Rebuild locally with the final screenshots in `docs/images/` and run the checks above.
5. Push to `main`, or run the Website workflow by hand. Then publish the first release so the download link stops 404ing.

## Not verified

The live deploy, the domain, the download link, the pointer effects on a trackpad (tested with synthetic mouse events in
headless Chrome only), the tour's camera on high-DPI displays beyond what the 2360 px captures resolve, and Safari or Firefox
(Chrome only here; the FAQ height animation and `interpolate-size` fall back to instant open elsewhere).
