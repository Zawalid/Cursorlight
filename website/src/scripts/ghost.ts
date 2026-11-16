import { gsap } from 'gsap';
import type { Engine } from './engine';
import { one } from './dom';

/**
 * The opening demo: a presenter's cursor (an arrow in a ring) shakes until the highlight finds it, then circles a word with a
 * rough loop that snaps clean. It hands over the moment the visitor moves their own mouse or presses a key.
 */
export function playGhostDemo(engine: Engine): void {
  const word = one('.h-point');
  const hero = one('[data-hero]');
  if (!word || !hero) return;
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const rect = word.getBoundingClientRect();
  if (rect.bottom < 0 || rect.top > vh) return;

  const cx = rect.left + rect.width / 2;
  const cy = rect.top + rect.height * 0.56;
  const rx = rect.width * 0.6;
  const ry = rect.height * 0.5;
  const spot = { x: vw * 0.55, y: vh * 0.62 };
  const g = { x: vw + 40, y: vh * 0.74, a: 1, angle: 0, drawing: 0 };

  const push = () => engine.setGhost({ x: g.x, y: g.y }, g.a);
  const tl = gsap.timeline({ delay: 0.9, onComplete: () => { engine.setGhost(null); engine.setTakeover(null); } });
  engine.setTakeover(() => { tl.kill(); if (g.drawing) engine.endStroke(); engine.setGhost(null); engine.setTakeover(null); });

  const stop = () => { if (window.scrollY < 80) return; window.removeEventListener('scroll', stop); tl.kill(); if (g.drawing) engine.endStroke(); engine.setGhost(null); engine.setTakeover(null); engine.clearInk(false); };
  window.addEventListener('scroll', stop, { passive: true });
  tl.to(g, { x: spot.x, y: spot.y, duration: 1, ease: 'power2.out', onUpdate: push });
  // the shake: five quick swings
  const swing = 120;
  for (const dir of [-1, 1, -1, 1, -1]) tl.to(g, { x: spot.x + dir * swing, duration: 0.13, ease: 'sine.inOut', onUpdate: push });
  tl.to(g, { x: spot.x, duration: 0.12, ease: 'sine.inOut', onUpdate: push });
  tl.to({}, { duration: 1.1 });
  // to the word, then a rough loop around it
  const startAngle = Math.PI;
  const at = (a: number) => {
    const wobble = 1 + 0.07 * Math.sin(a * 3.1) + 0.04 * Math.sin(a * 5.3 + 1);
    return { x: cx + Math.cos(a) * rx * wobble, y: cy + Math.sin(a) * ry * wobble };
  };
  const first = at(startAngle);
  tl.to(g, { x: first.x, y: first.y, duration: 0.7, ease: 'power2.inOut', onUpdate: push });
  tl.call(() => { g.drawing = 1; engine.beginStroke({ x: g.x, y: g.y }); });
  tl.to(g, {
    angle: Math.PI * 2.12, duration: 1.05, ease: 'power1.inOut',
    onUpdate: () => {
      const p = at(startAngle + g.angle);
      g.x = p.x; g.y = p.y;
      engine.addToStroke({ x: p.x, y: p.y });
      push();
    },
  });
  tl.call(() => { g.drawing = 0; engine.endStroke(); });
  tl.to({}, { duration: 1.3 });
  tl.to(g, { a: 0, duration: 0.4, onUpdate: push });
}
