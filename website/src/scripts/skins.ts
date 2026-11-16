import { all, one } from './dom';

/**
 * The page's own pointer, replaced by one of the app's skins. The real cursor is hidden with CSS and a small SVG follows the
 * mouse. Escape (or the System skin) puts the real one back. These are drawn for this page; the app's own skins are in the screenshot.
 */
interface Skin { svg: string; hot: [number, number] }

const W = '#ffffff';
const skins: Record<string, Skin> = {
  classic: { hot: [6, 4], svg: `<path d="M6 4v26l7-6 5 11 5-2-5-11 9-1z" fill="#8b6cf6" stroke="${W}" stroke-width="2.2" stroke-linejoin="round"/>` },
  dart: { hot: [5, 5], svg: `<path d="M5 5l30 12-14 5-5 13z" fill="#2fc6b0" stroke="${W}" stroke-width="2.2" stroke-linejoin="round"/>` },
  bolt: { hot: [20, 20], svg: `<path d="M23 3L8 22h10l-4 15 18-22H21z" fill="#f5b83d" stroke="${W}" stroke-width="2.2" stroke-linejoin="round"/>` },
  ring: { hot: [20, 20], svg: `<circle cx="20" cy="20" r="13" fill="none" stroke="${W}" stroke-width="9"/><circle cx="20" cy="20" r="13" fill="none" stroke="#f0733c" stroke-width="5.4"/><circle cx="20" cy="20" r="2.6" fill="#14121a"/>` },
  target: { hot: [20, 20], svg: `<circle cx="20" cy="20" r="10" fill="none" stroke="${W}" stroke-width="6.5"/><path d="M20 3v9M20 28v9M3 20h9M28 20h9" stroke="${W}" stroke-width="6.5" stroke-linecap="round"/><circle cx="20" cy="20" r="10" fill="none" stroke="#e5587b" stroke-width="3"/><path d="M20 3v9M20 28v9M3 20h9M28 20h9" stroke="#e5587b" stroke-width="3" stroke-linecap="round"/><circle cx="20" cy="20" r="2" fill="#14121a"/>` },
  star: { hot: [20, 20], svg: `<path d="M20 3l5 11.5 12.5 1.2-9.4 8.4 2.8 12.2L20 29.8 9.1 36.3l2.8-12.2L2.5 15.7 15 14.5z" fill="#f7c948" stroke="${W}" stroke-width="2.2" stroke-linejoin="round"/>` },
  heart: { hot: [20, 20], svg: `<path d="M20 35S4 25 4 14.5C4 8.8 8.2 5 13 5c3 0 5.6 1.6 7 4 1.4-2.4 4-4 7-4 4.800 0 9 3.800 9 9.500C36 25 20 35 20 35z" fill="#ef5f86" stroke="${W}" stroke-width="2.2" stroke-linejoin="round"/>` },
  ghost: { hot: [20, 20], svg: `<path d="M6 36V19C6 10.700 12 4.500 20 4.500S34 10.700 34 19v17l-5.600-4.600L23 36l-3-4.600L17 36l-5.400-4.600z" fill="#bfc3ff" stroke="${W}" stroke-width="2.2" stroke-linejoin="round"/><circle cx="15" cy="18" r="2.4" fill="#14121a"/><circle cx="25" cy="18" r="2.4" fill="#14121a"/>` },
};

export function initSkins(): void {
  const root = document.documentElement;
  const el = document.createElement('div');
  el.className = 'skin-cursor';
  el.setAttribute('aria-hidden', 'true');
  document.body.append(el);
  const buttons = all<HTMLButtonElement>('[data-skin-pick]');
  let hot: [number, number] = [0, 0];
  let seen = false;

  function set(id: string): void {
    const skin = skins[id];
    if (!skin) {
      delete root.dataset.skin;
    } else {
      root.dataset.skin = id;
      hot = skin.hot;
      el.innerHTML = `<svg viewBox="0 0 40 40">${skin.svg}</svg>`;
      el.style.opacity = seen ? '1' : '0';
    }
    for (const b of buttons) b.setAttribute('aria-pressed', String(b.dataset.skinPick === (skin ? id : 'system')));
    const status = one('[data-fx-status]');
    if (status) status.textContent = skin ? `Pointer skin: ${id}` : 'Pointer skin: system';
  }
  for (const b of buttons) b.addEventListener('click', (e) => {
    set(b.dataset.skinPick ?? 'system');
    // put the new skin under the pointer right away, since the click happened there
    if (e instanceof PointerEvent || e instanceof MouseEvent) { seen = true; place(e.clientX, e.clientY); el.style.opacity = '1'; }
  });
  function place(x: number, y: number): void { el.style.transform = `translate(${x - hot[0]}px, ${y - hot[1]}px)`; }
  window.addEventListener('pointermove', (e) => {
    if (e.pointerType === 'touch') return;
    seen = true;
    el.style.opacity = '1';
    place(e.clientX, e.clientY);
  }, { passive: true });
  document.documentElement.addEventListener('pointerleave', () => { el.style.opacity = '0'; });
  window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && root.dataset.skin) set('system'); });
  set('system');
}
