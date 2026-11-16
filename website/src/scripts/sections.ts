import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { DrawSVGPlugin } from 'gsap/DrawSVGPlugin';
import { all, one } from './dom';
import type { Engine, StyleName } from './engine';

/** Current section in the menu bar, like the item you last opened. */
export function initSpy(): void {
  const links = all<HTMLAnchorElement>('[data-spy]');
  const targets = links.map((a) => ({ a, el: document.getElementById(a.dataset.spy ?? '') })).filter((t): t is { a: HTMLAnchorElement; el: HTMLElement } => Boolean(t.el));
  let ticking = false;
  const update = () => {
    ticking = false;
    const mid = window.innerHeight * 0.42;
    let current: HTMLAnchorElement | null = null;
    for (const t of targets) {
      const r = t.el.getBoundingClientRect();
      if (r.top <= mid && r.bottom > mid) current = t.a;
    }
    for (const t of targets) t.a.setAttribute('aria-current', String(t.a === current));
  };
  window.addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(update); } }, { passive: true });
  update();
}

/** Copy buttons for the Terminal command. Falls back to selecting the text when the clipboard is not available. */
export function initCopy(): void {
  for (const button of all<HTMLButtonElement>('[data-copy]')) {
    const target = one(button.dataset.copy ?? '');
    if (!target) continue;
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(target.textContent ?? '');
        button.dataset.copied = 'true';
        button.textContent = 'Copied';
        window.setTimeout(() => { button.dataset.copied = 'false'; button.textContent = 'Copy'; }, 1800);
      } catch {
        const range = document.createRange();
        range.selectNodeContents(target);
        const selection = window.getSelection();
        selection?.removeAllRanges();
        selection?.addRange(range);
      }
    });
  }
}

/** The sharing diagram: whole screen versus one window. Works without motion; with motion it flips once on its own. */
export function initSharing(motion: boolean): void {
  const stage = one('[data-share-stage]');
  const buttons = all<HTMLButtonElement>('[data-share-set]');
  const verdict = one('[data-share-verdict]');
  const caption = one('[data-share-cap]');
  const desc = one('[data-share-desc]');
  if (!stage || !buttons.length) return;
  const text = {
    screen: {
      verdict: '<strong>Whole screen:</strong> every effect reaches viewers.',
      caption: 'On their screen: everything you see.',
      desc: 'Viewers see the whole display, including the ring, the laser and the ink.',
    },
    window: {
      verdict: '<strong>One window:</strong> viewers see the window and nothing you draw on top of it. No ring, no laser, no ink.',
      caption: 'On their screen: the window only. Your effects are not in it.',
      desc: 'Viewers see only the shared window. The ring, the laser and the ink are not there.',
    },
  } as const;
  let touched = false;
  const set = (kind: 'screen' | 'window') => {
    stage.dataset.share = kind;
    for (const b of buttons) b.setAttribute('aria-pressed', String(b.dataset.shareSet === kind));
    if (verdict) verdict.innerHTML = text[kind].verdict;
    if (caption) caption.textContent = text[kind].caption;
    if (desc) desc.textContent = text[kind].desc;
  };
  for (const b of buttons) b.addEventListener('click', () => { touched = true; set(b.dataset.shareSet === 'window' ? 'window' : 'screen'); });
  if (motion) {
    ScrollTrigger.create({ trigger: stage, start: 'top 65%', once: true, onEnter: () => { window.setTimeout(() => { if (!touched) set('window'); }, 1800); } });
  }
}

/** Privacy statement: words light up as you read down. */
function initStatement(): void {
  const statement = one('[data-statement]');
  if (!statement) return;
  const words = (statement.textContent ?? '').trim().split(/\s+/);
  statement.setAttribute('aria-label', words.join(' '));
  statement.textContent = '';
  const spans = words.map((word, i) => {
    const span = document.createElement('span');
    span.className = 'sw';
    span.setAttribute('aria-hidden', 'true');
    span.textContent = word;
    statement.append(span, i < words.length - 1 ? ' ' : '');
    return span;
  });
  ScrollTrigger.create({
    trigger: statement, start: 'top 80%', end: 'bottom 50%', scrub: true,
    onUpdate: (self) => { const n = Math.round(self.progress * spans.length); spans.forEach((s, i) => s.classList.toggle('lit', i < n)); },
  });
}

/** Scroll-driven motion that is not the tour: reveals, ink marks drawing themselves, the iris openings between sections. */
export function initScrollMotion(): void {
  gsap.registerPlugin(ScrollTrigger, DrawSVGPlugin);
  initStatement();

  for (const el of all('[data-reveal]')) {
    gsap.fromTo(el, { opacity: 0, y: 28 }, { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out', scrollTrigger: { trigger: el, start: 'top 90%', once: true } });
  }
  for (const wrap of all('[data-mark]')) {
    const path = one<SVGPathElement>('.ink-path', wrap);
    if (!path) continue;
    gsap.set(path, { drawSVG: '0%', visibility: 'visible' });
    gsap.to(path, { drawSVG: '100%', duration: 0.9, ease: 'power2.inOut', scrollTrigger: { trigger: wrap, start: 'top 82%', once: true }, delay: 0.25 });
  }
  // The new section opens like an aura from its top edge, the way the highlight spreads from the pointer.
  for (const el of all('[data-iris]')) {
    gsap.fromTo(el, { '--r': '0%' }, { '--r': '165%', ease: 'none', scrollTrigger: { trigger: el, start: 'top 96%', end: 'top 30%', scrub: 0.3 } });
  }
}

/** The six-style picker. It swaps the picture, and on a real mouse it also changes the page's own pointer. */
export function initStylePicker(engine: Engine | null): void {
  const root = one('[data-styles]');
  if (!root) return;
  const buttons = all<HTMLButtonElement>('[data-style-pick]', root);
  const imgs = all('[data-style-img]', root);
  const show = (id: string) => {
    for (const b of buttons) b.setAttribute('aria-pressed', String(b.dataset.stylePick === id));
    for (const i of imgs) i.dataset.active = String(i.dataset.styleImg === id);
  };
  for (const b of buttons) b.addEventListener('click', () => {
    const id = (b.dataset.stylePick ?? 'aura') as StyleName;
    show(id);
    engine?.setStyle(id);
  });
  engine?.onChange(() => show(engine.style));
}

/** The links table: each row runs the same command on this page that the link would run in the app. */
export function initLinks(engine: Engine | null): void {
  if (!engine) return;
  for (const b of all<HTMLButtonElement>('[data-run]')) {
    b.addEventListener('click', () => {
      const [cmd, arg] = (b.dataset.run ?? '').split(':');
      const on = (t: 'highlight' | 'laser' | 'ink' | 'spotlight') => (arg === 'toggle' ? engine.toggleTool(t) : arg === 'off' ? engine.setTool('none') : engine.setTool(t));
      switch (cmd) {
        case 'highlight': on('highlight'); break;
        case 'laser': on('laser'); break;
        case 'ink': on('ink'); break;
        case 'spotlight': on('spotlight'); break;
        case 'scene': engine.cycleStyle(); break;
        case 'clear': engine.clearInk(); break;
        case 'pause': engine.togglePause(); break;
        default: break;
      }
    });
  }
}
