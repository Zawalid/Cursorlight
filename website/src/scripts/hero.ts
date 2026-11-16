import { all, one } from './dom';
import type { Engine } from './engine';
import { playGhostDemo } from './ghost';

/** Hero wiring: the three gesture hints light up as the visitor tries them, the ember copy of the headline follows the pointer. */
export function initHero(engine: Engine): void {
  const hero = one('[data-hero]');
  const base = one('.h-base', hero ?? document);
  const status = one('[data-hero-status]');
  const doneLine = one('[data-try-done]');
  if (!hero || !base?.parentElement) return;

  // The ember copy of the headline is built here, not in the markup, so crawlers and screen readers only ever see one headline.
  const ember = document.createElement('span');
  ember.className = 'h-ember';
  ember.setAttribute('aria-hidden', 'true');
  for (const line of all('.h-line', base)) {
    const copy = document.createElement('span');
    copy.className = 'h-line';
    copy.textContent = (line.textContent ?? '').replace(/\s+/g, ' ').trim();
    ember.append(copy);
  }
  base.parentElement.append(ember);

  const done = new Set<string>();
  const names: Record<string, string> = { shake: 'Shake', hold: 'Hold', draw: 'Drag' };
  const say: Record<string, string> = { shake: 'Shake found your cursor.', hold: 'Laser trail on.', draw: 'Ink drawn.' };
  const mark = (id: 'shake' | 'hold' | 'draw') => {
    if (done.has(id)) return;
    done.add(id);
    const item = one(`[data-try="${id}"]`);
    if (item) {
      item.dataset.done = 'true';
      const state = one('[data-try-state]', item);
      if (state) state.textContent = ` ${names[id]} done.`;
    }
    if (status) status.textContent = say[id] ?? '';
    if (done.size === 3 && doneLine) doneLine.style.visibility = 'visible';
  };
  engine.on('shake', () => mark('shake'));
  engine.on('hold', () => mark('hold'));
  engine.on('draw', () => mark('draw'));

  let visible = true;
  new IntersectionObserver(([entry]) => {
    visible = Boolean(entry?.isIntersecting);
    engine.setKeepAlive(visible);
  }, { threshold: 0.05 }).observe(hero);
  engine.setKeepAlive(true);

  engine.onFrame((e) => {
    if (!visible) return;
    const r = ember.getBoundingClientRect();
    ember.style.setProperty('--mx', `${e.halo.x - r.left}px`);
    ember.style.setProperty('--my', `${e.halo.y - r.top}px`);
    ember.style.setProperty('--mr', `${e.reveal}px`);
    hero.dataset.mode = e.mode;
  });

  void document.fonts.ready.then(() => playGhostDemo(engine));
}
