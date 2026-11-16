// Screenshots of the page for review, at desktop (1440x900) and phone (390x844) width, into .checks/: the hero, the pinned tour at
// several scroll positions, then each section. Scrolls the whole page first so every scroll-in animation has run.
//   npm run build && npx astro preview --port 4321 &   then   node scripts/shots.mjs [http://localhost:4321]
import { chromium } from 'playwright-core';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const base = (process.argv[2] ?? 'http://localhost:4321').replace(/\/$/, '');
const out = fileURLToPath(new URL('../.checks/', import.meta.url));
mkdirSync(out, { recursive: true });
const sections = ['styles', 'scenes', 'sharing', 'links', 'install', 'privacy', 'faq', 'download'];
const sizes = [
  ['desktop', { width: 1440, height: 900 }],
  ['mobile', { width: 390, height: 844 }],
];

const browser = await chromium.launch({ channel: 'chrome' });
for (const [label, viewport] of sizes) {
  const context = await browser.newContext({ viewport, deviceScaleFactor: 1, hasTouch: label === 'mobile', isMobile: label === 'mobile' });
  const page = await context.newPage();
  await page.goto(base, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1800);
  await page.screenshot({ path: `${out}${label}-hero.png` });
  const total = await page.evaluate(() => document.documentElement.scrollHeight);
  for (let y = 0; y < total; y += 400) { await page.evaluate((y) => window.scrollTo(0, y), y); await page.waitForTimeout(50); }
  if (label === 'desktop') {
    const top = await page.evaluate(() => document.querySelector('[data-tour]').getBoundingClientRect().top + window.scrollY);
    for (const [i, d] of [60, 1100, 1900, 2700, 3500, 4400].entries()) {
      await page.evaluate((y) => window.scrollTo(0, y), top + d);
      await page.waitForTimeout(1500);
      await page.screenshot({ path: `${out}${label}-tour-${i}.png` });
    }
  }
  for (const id of sections) {
    const heights = await page.evaluate((id) => { const r = document.getElementById(id).getBoundingClientRect(); return Math.round(r.height); }, id);
    const steps = label === 'desktop' ? Math.min(3, Math.ceil(heights / 800)) : Math.min(5, Math.ceil(heights / 760));
    for (let k = 0; k < steps; k++) {
      await page.evaluate(([id, off]) => { const el = document.getElementById(id); window.scrollTo(0, el.getBoundingClientRect().top + window.scrollY + off); }, [id, k * (viewport.height - 80)]);
      await page.waitForTimeout(1300);
      await page.screenshot({ path: `${out}${label}-${id}-${k}.png` });
    }
  }
  await context.close();
  console.log(`${label}: done`);
}
await browser.close();
