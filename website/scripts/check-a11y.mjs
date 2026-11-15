// Runs axe on every page at 1440 and 390 wide, with and without motion, after scrolling the whole page so every
// scroll-in animation has settled, and fails on any violation or any horizontal scroll.
//   npx astro preview --port 4321 &   then   node scripts/check-a11y.mjs [http://localhost:4321]
import { chromium } from 'playwright-core';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const axe = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');
const base = (process.argv[2] ?? 'http://localhost:4321').replace(/\/$/, '');
const sitemap = await (await fetch(`${base}/sitemap.xml`)).text();
const pages = [...sitemap.matchAll(/<loc>https?:\/\/[^/]+(\/[^<]*)<\/loc>/g)].map((m) => m[1]).concat('/404/');
const browser = await chromium.launch({ channel: 'chrome' });
let failures = 0;
let runs = 0;
for (const reducedMotion of ['no-preference', 'reduce']) {
  for (const width of [1440, 390]) {
    const context = await browser.newContext({ viewport: { width, height: 900 }, reducedMotion });
    const page = await context.newPage();
    for (const path of pages) {
      await page.goto(base + path, { waitUntil: 'networkidle' });
      await page.evaluate(async () => {
        for (let y = 0; y < document.body.scrollHeight; y += 600) {
          window.scrollTo(0, y);
          await new Promise((r) => setTimeout(r, 50));
        }
        window.scrollTo(0, 0);
      });
      await page.waitForTimeout(1800);
      // reveal every collapsed answer so its text is measured too
      await page.evaluate(() => document.querySelectorAll('details').forEach((d) => { d.open = true; }));
      await page.addScriptTag({ content: axe });
      const result = await page.evaluate(async () => {
        const r = await window.axe.run(document, { resultTypes: ['violations'] });
        return r.violations.map((v) => `${v.id} (${v.impact}): ${v.nodes.slice(0, 3).map((n) => n.target.join(' ')).join(', ')}`);
      });
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      runs++;
      if (result.length || overflow > 0) {
        failures += result.length + (overflow > 0 ? 1 : 0);
        console.log(`${path} ${width}${reducedMotion === 'reduce' ? ' reduced motion' : ''}:`);
        for (const line of result) console.log('  ' + line);
        if (overflow > 0) console.log(`  horizontal scroll: ${overflow}px`);
      }
    }
    await context.close();
  }
}
await browser.close();
if (failures) { console.log(`\n${failures} problem(s)`); process.exit(1); }
console.log(`OK: axe found nothing and nothing scrolls sideways (${runs} runs: ${pages.length} pages, 1440 and 390, with and without motion).`);
