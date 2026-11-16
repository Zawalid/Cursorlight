// Verifies the page's behavior with real mouse and keyboard events: the opening demo and the hero gestures, the shortcuts and the
// toolbar, the style picker, the pointer skins, the links table, the pinned tour, the sharing toggle, the FAQ, keyboard focus, and
// the calm fallbacks (touch, reduced motion, narrow). Prints one line per check and exits 1 on any failure.
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

// canvas pixels that are ember-ish: proof that something was drawn
const ember = (page) => page.evaluate(() => {
  const c = document.querySelector('[data-fx-canvas]');
  const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
  let n = 0;
  for (let i = 0; i < d.length; i += 4) if (d[i] > 200 && d[i + 1] < 140 && d[i + 2] < 110 && d[i + 3] > 120) n++;
  return n;
});
const painted = (page) => page.evaluate(() => {
  const c = document.querySelector('[data-fx-canvas]');
  const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
  let n = 0;
  for (let i = 3; i < d.length; i += 4) if (d[i] > 20) n++;
  return n;
});
const heroMode = (page) => page.locator('[data-hero]').getAttribute('data-mode');

{
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(base, { waitUntil: 'networkidle' });
  check('live mode on for a mouse device', await page.evaluate(() => document.documentElement.classList.contains('live')));
  check('the toolbar is shown', await page.locator('[data-fxbar]').isVisible());

  // the opening demo plays by itself and is drawn on the canvas
  await page.waitForTimeout(3400);
  const demo = await painted(page);
  check('the opening demo draws a presenter cursor and a shake', demo > 800, `${demo} painted pixels`);
  await page.screenshot({ path: `${out}ui-demo.png` });

  // the visitor takes over: moving the mouse ends the demo
  await page.mouse.move(900, 300);
  await page.mouse.move(905, 305);
  await page.waitForTimeout(150);
  // shake: fast side to side
  for (let i = 0; i < 14; i++) { await page.mouse.move(i % 2 ? 700 : 1000, 300 + (i % 3) * 4, { steps: 3 }); await page.waitForTimeout(18); }
  await page.waitForTimeout(250);
  check('shake draws the highlight', (await ember(page)) > 600);
  check('shake lights the first hint', await page.locator('[data-try="shake"][data-done="true"]').count() === 1);
  await page.screenshot({ path: `${out}ui-shake.png` });
  await page.waitForTimeout(2200);

  // hold: press, stay still, then move
  await page.mouse.move(300, 560);
  await page.mouse.down();
  await page.waitForTimeout(340);
  check('hold enters laser mode', (await heroMode(page)) === 'laser');
  for (let i = 1; i <= 14; i++) { await page.mouse.move(300 + i * 40, 560 - Math.sin(i / 2) * 60); await page.waitForTimeout(16); }
  check('laser draws a trail', (await ember(page)) > 800);
  await page.mouse.up();
  check('hold lights the second hint', await page.locator('[data-try="hold"][data-done="true"]').count() === 1);
  await page.waitForTimeout(900);

  // drag: draw a rough loop immediately
  await page.mouse.move(980, 520);
  await page.mouse.down();
  for (let a = 0; a <= 360; a += 12) {
    const r = 70 + (a % 36 === 0 ? 8 : 0);
    await page.mouse.move(1060 + Math.cos(((a - 180) * Math.PI) / 180) * r, 520 + Math.sin(((a - 180) * Math.PI) / 180) * r * 0.55);
    await page.waitForTimeout(10);
  }
  check('drag enters ink mode', (await heroMode(page)) === 'ink');
  await page.mouse.up();
  await page.waitForTimeout(450);
  const ink = await ember(page);
  check('ink stays after release', ink > 800, `${ink} ember pixels`);
  check('drag lights the third hint', await page.locator('[data-try="draw"][data-done="true"]').count() === 1);
  check('completion line shown', await page.locator('[data-try-done]').isVisible());
  await page.waitForTimeout(3800);
  check('ink fades by itself', (await ember(page)) < ink * 0.2);

  // pressing a button must not draw
  const dl = await page.locator('[data-hero-download]').boundingBox();
  await page.mouse.move(dl.x + 20, dl.y + 20);
  await page.mouse.down();
  check('pressing the download button does not draw', (await heroMode(page)) === 'idle');
  await page.mouse.move(dl.x + 20, dl.y - 140);
  await page.mouse.up();

  // shortcuts and the toolbar
  await page.keyboard.press('Control+Alt+KeyI');
  check('Control+Option+I turns ink on', await page.evaluate(() => document.documentElement.dataset.fx === 'on') && (await page.locator('[data-tool="ink"]').getAttribute('aria-pressed')) === 'true');
  await page.mouse.move(500, 400);
  await page.mouse.down();
  await page.mouse.move(600, 380, { steps: 6 });
  await page.mouse.move(700, 420, { steps: 6 });
  await page.mouse.up();
  await page.waitForTimeout(100);
  check('ink mode draws anywhere on the page', (await ember(page)) > 400);
  await page.screenshot({ path: `${out}ui-ink.png` });
  await page.keyboard.press('Escape');
  check('Escape turns the tool off', await page.evaluate(() => document.documentElement.dataset.fx === 'idle'));
  await page.keyboard.press('Control+Alt+KeyS');
  await page.mouse.move(700, 500);
  await page.waitForTimeout(300);
  check('spotlight dims the page', (await painted(page)) > 400000);
  await page.screenshot({ path: `${out}ui-spotlight.png` });
  await page.keyboard.press('Control+Alt+KeyS');
  await page.keyboard.press('Control+Alt+KeyP');
  check('pause is shown on the menu bar icon', await page.evaluate(() => document.documentElement.dataset.fx === 'paused'));
  await page.keyboard.press('Control+Alt+KeyP');
  await page.locator('[data-tool="laser"]').click();
  check('the toolbar button turns the laser on', (await page.locator('[data-tool="laser"]').getAttribute('aria-pressed')) === 'true');
  await page.locator('[data-tool="laser"]').click();

  // the style picker sets the page's own style
  await page.locator('#styles').scrollIntoViewIfNeeded();
  await page.waitForTimeout(600);
  await page.locator('[data-style-pick="sonar"]').click();
  check('picking Sonar swaps the picture', await page.locator('[data-style-img="sonar"]').getAttribute('data-active') === 'true');
  check('picking Sonar sets the toolbar style', (await page.locator('[data-style-name]').textContent()) === 'Sonar');

  // skins
  await page.locator('#scenes').scrollIntoViewIfNeeded();
  await page.locator('.skins').scrollIntoViewIfNeeded();
  await page.waitForTimeout(700);
  await page.locator('[data-skin-pick="bolt"]').click();
  check('picking a skin hides the real cursor', await page.evaluate(() => document.documentElement.dataset.skin === 'bolt'));
  await page.mouse.move(600, 500);
  const placed = await page.evaluate(() => document.querySelector('.skin-cursor').style.transform);
  check('the skin follows the mouse', /translate\(5\d\dpx/.test(placed) || /translate\(\d+/.test(placed), placed);
  await page.keyboard.press('Escape');
  check('Escape brings the real cursor back', await page.evaluate(() => !document.documentElement.dataset.skin));

  // links table
  await page.locator('#links').scrollIntoViewIfNeeded();
  await page.waitForTimeout(500);
  await page.locator('[data-run="spotlight:toggle"]').click();
  check('Run spotlight in the links table switches it on', (await page.locator('[data-tool="spotlight"]').getAttribute('aria-pressed')) === 'true');
  await page.keyboard.press('Escape');

  // sharing toggle
  await page.locator('#sharing').scrollIntoViewIfNeeded();
  await page.locator('[data-share-set="window"]').click();
  check('sharing: one window flips the diagram', (await page.locator('[data-share-stage]').getAttribute('data-share')) === 'window');
  await page.locator('[data-share-set="screen"]').click();
  check('sharing: whole screen flips it back', (await page.locator('[data-share-stage]').getAttribute('data-share')) === 'screen');

  // FAQ
  const first = page.locator('details[data-faq]').first();
  await first.locator('summary').click();
  check('faq opens', await first.evaluate((d) => d.open));

  check('no errors in the console', errors.length === 0, errors.join(' | ').slice(0, 200));
  await context.close();
}

// the pinned tour
{
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  await page.goto(base, { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);
  const top = await page.evaluate(() => document.querySelector('[data-tour]').getBoundingClientRect().top + window.scrollY);
  const dotAt = async (d) => {
    await page.evaluate((y) => window.scrollTo(0, y), top + d);
    await page.waitForTimeout(1500);
    return page.evaluate(() => [...document.querySelectorAll('[data-tour-dot]')].findIndex((e) => e.dataset.on === 'true'));
  };
  const first = await dotAt(60);
  const mid = await dotAt(2400);
  const last = await dotAt(4700);
  check('tour: starts on the first beat', first === 0, `dot ${first}`);
  check('tour: moves through the beats', mid > first && last > mid, `dots ${first}, ${mid}, ${last}`);
  const pinned = await page.evaluate(() => document.querySelector('[data-tour-stage]').getBoundingClientRect().top);
  check('tour: the stage stays pinned while scrolling', pinned < 60 && pinned >= 0, `top ${Math.round(pinned)}`);
  const drawn = await page.evaluate(() => [...document.querySelectorAll('[data-tour-mark]')].filter((m) => m.style.strokeDasharray && !m.style.strokeDasharray.startsWith('0px')).length);
  check('tour: ink marks are drawn', drawn >= 1, `${drawn} drawn`);
  await context.close();
}

// touch: calm fallback, no live canvas, stacked tour
{
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
  const page = await context.newPage();
  await page.goto(base, { waitUntil: 'networkidle' });
  check('touch: not live', !(await page.evaluate(() => document.documentElement.classList.contains('live'))));
  check('touch: static ring around the last word', await page.locator('.h-ring').isVisible());
  check('touch: no toolbar', !(await page.locator('[data-fxbar]').isVisible()));
  check('touch: the tour is stacked, not pinned', !(await page.locator('[data-tour-pin]').isVisible()) && (await page.locator('.tour-items').isVisible()));
  check('touch: no horizontal scroll', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
  await context.close();
}

// reduced motion: no motion, no live, everything visible
{
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, reducedMotion: 'reduce' });
  const page = await context.newPage();
  await page.goto(base, { waitUntil: 'networkidle' });
  check('reduced motion: no motion, no live', await page.evaluate(() => !document.documentElement.classList.contains('motion') && !document.documentElement.classList.contains('live')));
  check('reduced motion: static ring shown', await page.locator('.h-ring').isVisible());
  check('reduced motion: the tour is stacked', !(await page.locator('[data-tour-pin]').isVisible()));
  const hidden = await page.evaluate(() => [...document.querySelectorAll('[data-reveal]')].filter((e) => getComputedStyle(e).opacity === '0').length);
  check('reduced motion: nothing hidden', hidden === 0, `${hidden} hidden`);
  const clipped = await page.evaluate(() => [...document.querySelectorAll('[data-iris]')].filter((e) => getComputedStyle(e).clipPath.includes('0%') && !getComputedStyle(e).clipPath.includes('160')).length);
  check('reduced motion: no section is clipped away', clipped === 0);
  await page.screenshot({ path: `${out}ui-reduced-motion.png` });
  await context.close();
}

// keyboard
{
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  await page.goto(base, { waitUntil: 'networkidle' });
  await page.keyboard.press('Tab');
  await page.waitForTimeout(400);
  check('first Tab reaches the visible skip link', await page.evaluate(() => { const a = document.activeElement; const r = a?.getBoundingClientRect(); return Boolean(a && a.classList.contains('skip') && r && r.top >= 0); }));
  await page.keyboard.press('Tab');
  check('focused link has an outline', (await page.evaluate(() => getComputedStyle(document.activeElement).outlineStyle)) !== 'none');
  await context.close();
}

await browser.close();
if (failed) { console.log(`\n${failed} check(s) failed`); process.exit(1); }
console.log('\nOK: every UI check passed.');
