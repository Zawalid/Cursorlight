import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from 'lenis';
import 'lenis/dist/lenis.css';
import { one } from './dom';
import { Engine } from './engine';
import { initToolbar } from './toolbar';
import { initHero } from './hero';
import { initSkins } from './skins';
import { initTour } from './tour';
import { initCopy, initLinks, initScrollMotion, initSharing, initSpy, initStylePicker } from './sections';

declare global {
  interface Window { __cursorlightMotion?: boolean; __cursorlightEngine?: Engine }
}

const root = document.documentElement;
const motion = root.classList.contains('motion');
const live = root.classList.contains('live');

let engine: Engine | null = null;
if (live) {
  const canvas = one<HTMLCanvasElement>('[data-fx-canvas]');
  if (canvas) {
    try {
      engine = new Engine(canvas);
      window.__cursorlightEngine = engine;
      initToolbar(engine);
      initHero(engine);
      initSkins();
    } catch (error) {
      root.classList.remove('live');
      console.warn('Pointer effects disabled', error);
    }
  }
}

initSpy();
initCopy();
initStylePicker(engine);
initLinks(engine);

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
    initScrollMotion();
    initTour();
    initSharing(true);
    window.__cursorlightMotion = true;
    void document.fonts.ready.then(() => ScrollTrigger.refresh());
  } catch (error) {
    root.classList.remove('motion', 'live');
    console.warn('Motion disabled', error);
    initSharing(false);
  }
} else {
  initSharing(false);
}
