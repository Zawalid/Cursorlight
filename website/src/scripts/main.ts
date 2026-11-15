import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from 'lenis';
import 'lenis/dist/lenis.css';
import { all, one } from './dom';
import { initHero } from './hero';

declare global {
  interface Window { __cursorlightMotion?: boolean }
}

const root = document.documentElement;
const motion = root.classList.contains('motion');
const live = root.classList.contains('live');

/** The header gets a background once the page has moved. */
function initNav(): void {
  const nav = one('[data-nav]');
  if (!nav) return;
  const update = () => nav.classList.toggle('is-scrolled', window.scrollY > 24);
  update();
  window.addEventListener('scroll', update, { passive: true });
}

/** Copy buttons for the Terminal command. Falls back to selecting the text when the clipboard is not available. */
function initCopy(): void {
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
function initSharing(): void {
  const stage = one('[data-share-stage]');
  const buttons = all<HTMLButtonElement>('[data-share-set]');
  const verdict = one('[data-share-verdict]');
  const caption = one('[data-share-cap]');
  const desc = one('[data-share-desc]');
  if (!stage || !buttons.length) return;
  const text = {
    screen: {
      verdict: '<strong>Whole screen:</strong> every effect reaches viewers.',
      caption: 'Viewers see everything you see.',
      desc: 'Viewers see the whole display, including the ring, the laser and the ink.',
    },
    window: {
      verdict: '<strong>One window:</strong> viewers see the window and nothing you draw on top of it. No ring, no laser, no ink.',
      caption: 'Viewers see the window only. Your effects are not in it.',
      desc: 'Viewers see only the shared window. The ring, the laser and the ink are not there.',
    },
  } as const;
  let touched = false;
  function set(kind: 'screen' | 'window'): void {
    stage!.dataset.share = kind;
    for (const b of buttons) b.setAttribute('aria-pressed', String(b.dataset.shareSet === kind));
    if (verdict) verdict.innerHTML = text[kind].verdict;
    if (caption) caption.textContent = text[kind].caption;
    if (desc) desc.textContent = text[kind].desc;
  }
  for (const b of buttons) {
    b.addEventListener('click', () => { touched = true; set(b.dataset.shareSet === 'window' ? 'window' : 'screen'); });
  }
  if (motion) {
    ScrollTrigger.create({
      trigger: stage,
      start: 'top 70%',
      once: true,
      onEnter: () => { window.setTimeout(() => { if (!touched) set('window'); }, 1600); },
    });
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
    trigger: statement,
    start: 'top 80%',
    end: 'bottom 48%',
    scrub: true,
    onUpdate: (self) => {
      const n = Math.round(self.progress * spans.length);
      spans.forEach((s, i) => s.classList.toggle('lit', i < n));
    },
  });
}

function initReveals(): void {
  for (const el of all('[data-reveal]')) {
    gsap.fromTo(el, { opacity: 0, y: 26 }, {
      opacity: 1, y: 0, duration: 0.8, ease: 'power3.out',
      scrollTrigger: { trigger: el, start: 'top 90%', once: true },
    });
  }
  for (const row of all('[data-ledger-row]')) {
    gsap.fromTo(row.children, { opacity: 0, y: 22 }, {
      opacity: 1, y: 0, duration: 0.7, stagger: 0.09, ease: 'power3.out',
      scrollTrigger: { trigger: row, start: 'top 88%', once: true },
    });
  }
  const skins = all('[data-skin]');
  if (skins.length) {
    gsap.fromTo(skins, { opacity: 0, y: 30 }, {
      opacity: 1, y: 0, duration: 0.7, stagger: 0.07, ease: 'power3.out',
      scrollTrigger: { trigger: skins[0], start: 'top 88%', once: true },
    });
  }
}

initNav();
initCopy();

if (motion) {
  try {
    gsap.registerPlugin(ScrollTrigger);
    ScrollTrigger.config({ ignoreMobileResize: true });

    if (!window.matchMedia('(pointer: coarse)').matches) {
      const lenis = new Lenis({ lerp: 0.12, anchors: true, autoRaf: false });
      lenis.on('scroll', ScrollTrigger.update);
      gsap.ticker.add((time) => lenis.raf(time * 1000));
      gsap.ticker.lagSmoothing(0);
    }

    const lines = all('.h-base .h-line');
    if (lines.length) gsap.from(lines, { y: 44, duration: 0.9, stagger: 0.1, ease: 'power3.out', clearProps: 'transform' });

    initStatement();
    initReveals();
    initSharing();
    if (live) initHero();
    window.__cursorlightMotion = true;

    void document.fonts.ready.then(() => ScrollTrigger.refresh());
  } catch (error) {
    root.classList.remove('motion', 'live');
    console.warn('Motion disabled', error);
    initSharing();
  }
} else {
  initSharing();
}
