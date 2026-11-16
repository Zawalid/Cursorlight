// Checks the basics of every page of the built site: one h1, sensible title and description, a correct canonical, valid
// structured data, alt text, working internal links, a share image that loads, robots.txt, the sitemap, no em dashes,
// no emoji, no external requests, images with dimensions, fonts self-hosted, and layout shift. Placeholders are reported
// as a warning, not a failure.
//   npm run build && npx astro preview --port 4321 &   then   node scripts/check-seo.mjs [http://localhost:4321]
import { chromium } from 'playwright-core';
import { DOMAIN } from '../site.config.mjs';

const base = (process.argv[2] ?? 'http://localhost:4321').replace(/\/$/, '');
const origin = `https://${DOMAIN}`;
const problems = [];
const warnings = [];
const note = (page, message) => problems.push(`${page}: ${message}`);

const sitemap = await (await fetch(`${base}/sitemap.xml`)).text();
const robots = await (await fetch(`${base}/robots.txt`)).text();
if (!robots.includes(`Sitemap: ${origin}/sitemap.xml`)) note('robots.txt', 'does not point at the sitemap');
const pages = [...sitemap.matchAll(/<loc>https:\/\/[^/]+(\/[^<]*)<\/loc>/g)].map((m) => m[1]);
if (pages.length < 1) note('sitemap.xml', 'lists no pages');

const browser = await chromium.launch({ channel: 'chrome' });
const seenLinks = new Set();
for (const path of pages) {
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const errors = [];
  const external = [];
  const fonts = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text().slice(0, 120)); });
  page.on('pageerror', (e) => errors.push(String(e).slice(0, 120)));
  page.on('request', (r) => {
    const url = new URL(r.url());
    if (url.origin !== new URL(base).origin && !r.url().startsWith('data:') && url.hostname !== 'static.cloudflareinsights.com' && url.hostname !== 'cloudflareinsights.com') external.push(r.url());
    if (/\.(woff2?|ttf|otf)$/.test(url.pathname)) fonts.push(url.pathname);
  });
  await page.addInitScript(() => {
    window.__cls = 0;
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) if (!e.hadRecentInput) window.__cls += e.value;
    }).observe({ type: 'layout-shift', buffered: true });
  });
  const response = await page.goto(base + path, { waitUntil: 'networkidle' });
  if (response?.status() !== 200) note(path, `status ${response?.status()}`);
  await page.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 600) { window.scrollTo(0, y); await new Promise((r) => setTimeout(r, 40)); }
    window.scrollTo(0, 0);
  });
  await page.waitForTimeout(800);
  const info = await page.evaluate(() => ({
    title: document.title,
    description: document.querySelector('meta[name="description"]')?.content ?? '',
    canonical: document.querySelector('link[rel="canonical"]')?.href ?? '',
    h1: [...document.querySelectorAll('h1')].map((h) => h.textContent.trim()),
    og: document.querySelector('meta[property="og:image"]')?.content ?? '',
    robots: document.querySelector('meta[name="robots"]')?.content ?? '',
    noAlt: document.querySelectorAll('img:not([alt])').length,
    noSize: [...document.querySelectorAll('img')].filter((i) => !i.getAttribute('width') || !i.getAttribute('height')).length,
    jsonld: [...document.querySelectorAll('script[type="application/ld+json"]')].map((s) => s.textContent),
    links: [...document.querySelectorAll('a[href]')].map((a) => a.getAttribute('href')).filter((h) => h.startsWith('/') && !h.startsWith('//')),
    text: document.body.innerText,
    placeholders: document.querySelectorAll('[data-placeholder]').length,
    cls: window.__cls,
  }));
  const isNotFound = path === '/404/';
  if (info.title.length < 15 || info.title.length > 62) note(path, `title is ${info.title.length} characters: "${info.title}"`);
  if (info.description.length < 80 || info.description.length > 165) note(path, `description is ${info.description.length} characters`);
  if (info.canonical !== origin + path) note(path, `canonical is ${info.canonical}`);
  if (info.h1.length !== 1) note(path, `has ${info.h1.length} h1 elements`);
  if (!/index/.test(info.robots)) note(path, `robots meta is "${info.robots}"`);
  if (info.noAlt) note(path, `${info.noAlt} images without an alt attribute`);
  if (info.noSize) note(path, `${info.noSize} images without width and height`);
  for (const text of info.jsonld) { try { JSON.parse(text); } catch { note(path, 'structured data does not parse'); } }
  if (!info.jsonld.length) note(path, 'no structured data');
  if (/—/.test(info.text)) note(path, 'contains an em dash');
  if (/\p{Emoji_Presentation}/u.test(info.text)) note(path, 'contains an emoji');
  if (external.length) note(path, `requests other origins: ${external.slice(0, 3).join(', ')}`);
  if (info.cls > 0.02) note(path, `layout shift ${info.cls.toFixed(3)}`);
  if (info.placeholders) warnings.push(`${path}: ${info.placeholders} placeholder screenshot frame(s) still on the page`);
  const image = await fetch(info.og.replace(origin, base));
  if (!image.ok) note(path, `share image ${info.og} answers ${image.status}`);
  for (const link of info.links) seenLinks.add(link.split('#')[0] || '/');
  if (errors.length) note(path, `console errors: ${errors.join(' | ')}`);
  console.log(`${path}  title(${info.title.length}) description(${info.description.length}) h1="${info.h1[0]}" cls=${info.cls.toFixed(3)} fonts=${[...new Set(fonts)].length} self-hosted`);
  await page.close();
}
for (const link of seenLinks) {
  const response = await fetch(base + link, { redirect: 'follow' });
  if (!response.ok) note(link, `internal link answers ${response.status}`);
}
const missing = await fetch(`${base}/this-page-does-not-exist/`);
if (missing.status !== 404) note('404', `an unknown address answers ${missing.status}`);
await browser.close();

for (const w of warnings) console.log(`WARN  ${w}`);
if (problems.length) {
  console.log(`\n${problems.length} problem(s):`);
  for (const p of problems) console.log(' - ' + p);
  process.exit(1);
}
console.log(`\nOK: ${pages.length} page(s) and ${seenLinks.size} internal link(s) checked.`);
