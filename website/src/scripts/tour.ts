import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { DrawSVGPlugin } from 'gsap/DrawSVGPlugin';
import { all, one } from './dom';
import { beats, IMG } from '../data/tour';

/**
 * The pinned product tour. One real capture sits on a dark stage; as the page scrolls, a camera moves across it, the picture
 * swaps for the next capture, and an ink mark is drawn around what the caption is about. Built from data/tour.ts, so the
 * stacked version (phones, reduced motion) tells the same story from the same beats.
 */
export function initTour(): void {
  const section = one('[data-tour]');
  const pin = one('[data-tour-pin]');
  const stage = one('[data-tour-stage]');
  const cam = one('[data-tour-cam]');
  const win = one('[data-tour-win]');
  if (!section || !pin || !stage || !cam || !win) return;
  gsap.registerPlugin(ScrollTrigger, DrawSVGPlugin);

  const caps = all('[data-tour-cap]');
  const dots = all('[data-tour-dot]');
  const imgs = Object.fromEntries(all('[data-tour-img]').map((el) => [el.dataset.tourImg ?? '', el]));
  const marks = all<SVGPathElement>('[data-tour-mark]');
  const ia = IMG.h / IMG.w;
  let ctx: gsap.Context | null = null;

  function build(): void {
    ctx?.revert();
    if (getComputedStyle(pin!).display === 'none') return;
    ctx = gsap.context(() => {
      const sw = stage!.clientWidth;
      const sh = stage!.clientHeight;
      const ww = Math.min(sw * 0.8, 1480);
      const wh = ww * ia;
      (cam as HTMLElement).style.setProperty('--ww', `${ww}px`);

      const poseFor = (i: number) => {
        const b = beats[i];
        if (!b) return { x: 0, y: 0, scale: 1 };
        if (i === 0) return { scale: 1, x: (sw - ww) / 2, y: Math.max(sh - wh * 0.84, 262) };
        const s = b.focus.zoom;
        let x = sw * (b.side === 'right' ? 0.36 : 0.64) - b.focus.x * ww * s;
        let y = sh * 0.5 - b.focus.y * wh * s;
        // keep the picture covering the stage, so the camera never shows empty dark at an edge
        x = Math.min(0, Math.max(sw - ww * s, x));
        y = Math.min(0, Math.max(sh - wh * s, y));
        return { scale: s, x, y };
      };

      gsap.set(cam, { ...poseFor(0), transformOrigin: '0 0' });
      gsap.set(caps, { opacity: 0 });
      gsap.set(caps[0] ?? [], { opacity: 1, y: 0 });
      gsap.set(marks, { drawSVG: '0%', visibility: 'visible' });

      const tl = gsap.timeline({ defaults: { ease: 'power2.inOut' } });
      const STEP = 2;
      beats.forEach((b, i) => {
        if (i === 0) return;
        const t = (i - 1) * STEP + 0.6;
        const prev = beats[i - 1];
        if (!prev) return;
        tl.to(cam, { ...poseFor(i), duration: 1.1 }, t);
        tl.to(caps[i - 1] ?? [], { opacity: 0, y: -18, duration: 0.35, ease: 'power2.in' }, t);
        tl.fromTo(caps[i] ?? [], { opacity: 0, y: 26 }, { opacity: 1, y: 0, duration: 0.55, ease: 'power3.out' }, t + 0.7);
        if (prev.image !== b.image) {
          tl.to(imgs[prev.image] ?? [], { opacity: 0, duration: 0.5, ease: 'none' }, t + 0.3);
          tl.to(imgs[b.image] ?? [], { opacity: 1, duration: 0.5, ease: 'none' }, t + 0.3);
        }
        const prevMark = marks[i - 2];
        if (prevMark) tl.to(prevMark, { opacity: 0, duration: 0.3, ease: 'none' }, t);
        const mark = marks[i - 1];
        if (mark) tl.fromTo(mark, { drawSVG: '0%', opacity: 1 }, { drawSVG: '100%', duration: 0.8, ease: 'power1.inOut' }, t + 1.0);
      });
      tl.to({}, { duration: 1.2 });
      const total = tl.duration();

      ScrollTrigger.create({
        trigger: section,
        start: 'top top',
        end: () => `+=${Math.round(window.innerHeight * beats.length * 0.9)}`,
        pin,
        scrub: 0.5,
        animation: tl,
        anticipatePin: 1,
        onUpdate: (self) => {
          const at = self.progress * total;
          const idx = Math.max(0, Math.min(beats.length - 1, Math.round((at - 0.6) / STEP + (at > 0.6 ? 0.2 : -1)) + (at > 0.6 ? 0 : 0)));
          dots.forEach((d, i) => { d.dataset.on = String(i === idx); });
        },
      });
      dots.forEach((d, i) => { d.dataset.on = String(i === 0); });

      // the stage opens up as the section arrives
      gsap.fromTo(stage, { clipPath: 'inset(12vh 7vw round 44px)' }, {
        clipPath: 'inset(0vh 0vw round 26px)', ease: 'none',
        scrollTrigger: { trigger: section, start: 'top bottom', end: 'top top', scrub: true },
      });
    });
  }

  build();
  let timer = 0;
  let lastW = window.innerWidth;
  window.addEventListener('resize', () => {
    window.clearTimeout(timer);
    timer = window.setTimeout(() => {
      if (window.innerWidth === lastW) return;
      lastW = window.innerWidth;
      build();
      ScrollTrigger.refresh();
    }, 250);
  });
}
