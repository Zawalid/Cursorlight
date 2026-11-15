# Cursorlight website

The product site for Cursorlight. Astro (static output), GSAP and Lenis for motion, deployed to Cloudflare as a Worker with
static assets. Same tooling as the Lopper and Apropos sites; its own design.

## Design

- **The visitor's pointer is the hero.** On a desktop with a mouse, the hero is a small web sketch of the app: shake the
  mouse and a highlight finds the cursor (the headline lights up in ember inside it), press and hold for a laser trail, press
  and drag for ink that fades, and a rough loop snaps to a clean ellipse. Code: `src/scripts/hero.ts`.
- **Calm fallback.** Touch devices, `prefers-reduced-motion` and no-JS get no canvas: the last word of the headline is circled
  in ink (the static version of the same idea) and the three gestures are described in plain text.
- **Capture frames.** Screenshots sit in a frame with four ember corners, the way a screen-share selection looks.
- **Paper section.** The sharing section is the one light section, on purpose: it is the honest page. Its diagram (whole
  screen versus one window) is interactive and works without motion.
- Colors: ember `#FF5A36` on charcoal `#14121A`, warm off-white text. Fonts (self-hosted, `public/fonts/`): Bricolage
  Grotesque for display, Instrument Sans for text, Geist Mono for keys and code. No gradients, glows or emoji.

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
node scripts/check-ui.mjs http://localhost:4380     # the hero with real mouse events, sharing toggle, FAQ, keyboard focus, touch and reduced motion fallbacks
node scripts/shots.mjs http://localhost:4380        # one screenshot per section, desktop and phone, into .checks/
npm run og                                          # redraws public/og.png from scripts/og.html
```

`npm run build` is the gate; Astro strips types, there is no separate type check.

## Screenshots

Every product picture is named in `src/data/shots.ts`. The files live in `../docs/images/` (the main project captures them);
`scripts/sync-shots.mjs` copies them into `src/assets/shots/` before every build and Astro optimises them. A picture that
does not exist yet renders as a clearly marked placeholder frame. To swap one: drop the file in `docs/images/` with the name
in `shots.ts`, rebuild. `check-seo.mjs` prints a warning while any placeholder remains.

## Configuration in one place

`site.config.mjs` holds the domain and the repository. Everything else reads it: `astro.config.mjs`, `src/data/site.ts`
(links, download URL), `robots.txt`, the sitemap, canonical links, the check scripts. Both values are **unconfirmed**
(`cursorlight.zawalid.com`, `Zawalid/Cursorlight`). `wrangler.jsonc` cannot import it, so change its `routes` host too. The
version shown on the page is read from `../App/project.yml` (`MARKETING_VERSION`) at build time.

The download button points at `https://github.com/Zawalid/Cursorlight/releases/latest/download/Cursorlight.dmg`. It 404s
until a published release carries an asset with exactly that name.

## Deploy (prepared, not run)

`../.github/workflows/pages.yml` builds `website/` and runs `npx wrangler deploy` on every push to `main` that touches
`website/**`, or by hand. To go live:

1. Create the GitHub repository (confirm the name; change `REPO` in `site.config.mjs` if it is not `Zawalid/Cursorlight`) and push.
2. Confirm the domain. Change `DOMAIN` in `site.config.mjs` and the `routes` host in `wrangler.jsonc`, rerun `npm run og` only if the
   image text changes. The zone must be on the same Cloudflare account, so Cloudflare can create the DNS record and certificate.
3. Create a Cloudflare API token (Workers Scripts: Edit and DNS: Edit) and set two repository secrets, reading the values from
   stdin so they never print: `gh secret set CLOUDFLARE_API_TOKEN --repo OWNER/REPO` and
   `gh secret set CLOUDFLARE_ACCOUNT_ID --repo OWNER/REPO`.
4. Drop the real screenshots into `docs/images/` (see above) and rebuild locally to check there are no placeholder warnings.
5. Push to `main`, or run the Website workflow by hand. Then publish the first release so the download link stops 404ing.

## Not verified

The live deploy, the domain, the download link, the pointer playground on a trackpad (tested with synthetic mouse events in
headless Chrome only) and Safari/Firefox rendering (Chrome only here).
