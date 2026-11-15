// One screenshot per section, at desktop (1440) and phone (390) width, into .checks/. Scrolls down the whole page first so
// every scroll-in animation has run, then captures each section as it settles.
//   npm run build && npx astro preview --port 4321 &   then   node scripts/shots.mjs [http://localhost:4321]
import { chromium } from 'playwright-core';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const base = (process.argv[2] ?? 'http://localhost:4321').replace(/\/$/, '');
const out = fileURLToPath(new URL('../.checks/', import.meta.url));
mkdirSync(out, { recursive: true });
const sections = ['top', 'features', 'scenes', 'sharing', 'automation', 'install', 'privacy', 'faq', 'open-source'];
const sizes = [
  ['desktop', { width: 1440, height: 900 }],
  ['mobile', { width: 390, height: 844 }],
];

const browser = await chromium.launch({ channel: 'chrome' });
for (const [label, viewport] of sizes) {
  const context = await browser.newContext({ viewport, deviceScaleFactor: 1, hasTouch: label === 'mobile', isMobile: label === 'mobile' });
  const page = await context.newPage();
  await page.goto(base, { waitUntil: 'networkidle' });
  await page.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 500) {
      window.scrollTo(0, y);
      await new Promise((r) => setTimeout(r, 60));
    }
    window.scrollTo(0, 0);
  });
  await page.waitForTimeout(2200);
  for (const id of sections) {
    const el = page.locator(id === 'top' ? '#top' : `#${id}`);
    await el.scrollIntoViewIfNeeded();
    await page.waitForTimeout(700);
    await el.screenshot({ path: `${out}${label}-${id}.png` });
  }
  const footer = page.locator('footer');
  await footer.scrollIntoViewIfNeeded();
  await page.waitForTimeout(500);
  await footer.screenshot({ path: `${out}${label}-footer.png` });
  await context.close();
  console.log(`${label}: ${sections.length + 1} screenshots`);
}
await browser.close();
