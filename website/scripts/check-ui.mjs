// Verifies the hero pointer playground with real mouse events, the sharing toggle, the copy button, the FAQ, and the
// calm fallbacks (touch device, reduced motion). Prints one compact line per check; exits 1 on any failure.
//   npx astro preview --port 4321 &   then   node scripts/check-ui.mjs [http://localhost:4321]
import { chromium } from 'playwright-core';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const base = (process.argv[2] ?? 'http://localhost:4321').replace(/\/$/, '');
const out = fileURLToPath(new URL('../.checks/', import.meta.url));
mkdirSync(out, { recursive: true });
let failed = 0;
const check = (name, ok, detail = '') => {
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  ' + detail : ''}`);
};

const browser = await chromium.launch({ channel: 'chrome' });

// canvas pixels that are ember-ish, a proof that something was drawn
const emberPixels = (page) => page.evaluate(() => {
  const c = document.querySelector('[data-hero-canvas]');
  const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
  let n = 0;
  for (let i = 0; i < d.length; i += 4) if (d[i] > 200 && d[i + 1] < 140 && d[i + 2] < 110 && d[i + 3] > 120) n++;
  return n;
});

{
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(base, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);
  check('live mode on for a mouse device', await page.evaluate(() => document.documentElement.classList.contains('live')));

  // shake: fast side to side
  await page.mouse.move(900, 300);
  for (let i = 0; i < 14; i++) { await page.mouse.move(i % 2 ? 700 : 1000, 300 + (i % 3) * 4, { steps: 3 }); await page.waitForTimeout(18); }
  await page.waitForTimeout(250);
  const shake = await emberPixels(page);
  check('shake draws the highlight', shake > 600, `${shake} ember pixels`);
  check('shake marks the first step done', await page.locator('[data-try="shake"][data-done="true"]').count() === 1);
  await page.screenshot({ path: `${out}hero-shake.png` });
  await page.waitForTimeout(2200);

  // hold: press, stay still, then move
  await page.mouse.move(300, 500);
  await page.mouse.down();
  await page.waitForTimeout(320);
  check('hold enters laser mode', await page.locator('[data-hero]').getAttribute('data-mode') === 'laser');
  for (let i = 1; i <= 14; i++) { await page.mouse.move(300 + i * 40, 500 - Math.sin(i / 2) * 60); await page.waitForTimeout(16); }
  const laser = await emberPixels(page);
  check('laser draws a trail', laser > 800, `${laser} ember pixels`);
  await page.screenshot({ path: `${out}hero-laser.png` });
  await page.mouse.up();
  check('hold marks the second step done', await page.locator('[data-try="hold"][data-done="true"]').count() === 1);
  await page.waitForTimeout(900);

  // drag: draw a rough loop immediately, it should become an ellipse
  await page.mouse.move(980, 560);
  await page.mouse.down();
  const cx = 1060, cy = 560;
  for (let a = 0; a <= 360; a += 12) {
    const r = 70 + (a % 36 === 0 ? 8 : 0);
    await page.mouse.move(cx + Math.cos(((a - 180) * Math.PI) / 180) * r, cy + Math.sin(((a - 180) * Math.PI) / 180) * (r * 0.55));
    await page.waitForTimeout(10);
  }
  check('drag enters ink mode', await page.locator('[data-hero]').getAttribute('data-mode') === 'ink');
  await page.mouse.up();
  await page.waitForTimeout(450);
  const ink = await emberPixels(page);
  check('ink stays after release', ink > 800, `${ink} ember pixels`);
  check('drag marks the third step done', await page.locator('[data-try="draw"][data-done="true"]').count() === 1);
  await page.screenshot({ path: `${out}hero-ink.png` });
  check('completion line shown', await page.locator('[data-try-done]').isVisible());
  await page.waitForTimeout(3600);
  const faded = await emberPixels(page);
  check('ink fades by itself', faded < ink * 0.15, `${faded} left`);

  // pressing on the download button must not start a stroke (release elsewhere so the link is not followed)
  const dl = await page.locator('[data-hero-download]').boundingBox();
  await page.mouse.move(dl.x + 20, dl.y + 20);
  await page.mouse.down();
  check('pressing the download button does not draw', await page.locator('[data-hero]').getAttribute('data-mode') === 'idle');
  await page.mouse.move(dl.x + 20, dl.y - 120);
  await page.mouse.up();
  check('no errors in the console', errors.length === 0, errors.join(' | ').slice(0, 160));

  // sharing toggle
  await page.locator('#sharing').scrollIntoViewIfNeeded();
  await page.locator('[data-share-set="window"]').click();
  check('sharing: one window flips the diagram', await page.locator('[data-share-stage]').getAttribute('data-share') === 'window');
  check('sharing: pressed state updates', await page.locator('[data-share-set="window"]').getAttribute('aria-pressed') === 'true');
  await page.locator('[data-share-set="screen"]').click();
  check('sharing: whole screen flips it back', await page.locator('[data-share-stage]').getAttribute('data-share') === 'screen');

  // FAQ
  const first = page.locator('details[data-faq]').first();
  await first.locator('summary').click();
  check('faq opens', await first.evaluate((d) => d.open));

  // keyboard focus is visible (a fresh load, so the first Tab starts at the top)
  await page.goto(base, { waitUntil: 'networkidle' });
  await page.keyboard.press('Tab');
  await page.waitForTimeout(400);
  const skipVisible = await page.evaluate(() => {
    const a = document.activeElement;
    const r = a?.getBoundingClientRect();
    return Boolean(a && a.classList.contains('skip') && r && r.top >= 0);
  });
  check('first Tab reaches the visible skip link', skipVisible);
  await page.keyboard.press('Tab');
  const outline = await page.evaluate(() => getComputedStyle(document.activeElement).outlineStyle);
  check('focused link has an outline', outline !== 'none', outline);
  await context.close();
}

{
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
  const page = await context.newPage();
  await page.goto(base, { waitUntil: 'networkidle' });
  check('touch: not live', !(await page.evaluate(() => document.documentElement.classList.contains('live'))));
  check('touch: static ring around the last word', await page.locator('.h-ring').isVisible());
  check('touch: no horizontal scroll', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
  await context.close();
}

{
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, reducedMotion: 'reduce' });
  const page = await context.newPage();
  await page.goto(base, { waitUntil: 'networkidle' });
  check('reduced motion: no motion, no live', await page.evaluate(() => !document.documentElement.classList.contains('motion') && !document.documentElement.classList.contains('live')));
  check('reduced motion: static ring shown', await page.locator('.h-ring').isVisible());
  const hidden = await page.evaluate(() => [...document.querySelectorAll('[data-reveal]')].filter((e) => getComputedStyle(e).opacity === '0').length);
  check('reduced motion: nothing hidden', hidden === 0, `${hidden} hidden`);
  await page.screenshot({ path: `${out}hero-reduced-motion.png` });
  await context.close();
}

await browser.close();
if (failed) { console.log(`\n${failed} check(s) failed`); process.exit(1); }
console.log('\nOK: every UI check passed.');
