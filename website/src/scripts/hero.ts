import { all, one } from './dom';

/**
 * The pointer playground in the hero. It is a small web sketch of what the app does on a real screen:
 *   - shake the mouse: a highlight finds the cursor (aura, ring, sonar);
 *   - press, hold still, then move: a laser trail;
 *   - press and drag at once: ink that fades, and a rough loop or line snaps to a clean shape.
 * Everything is drawn on one canvas that covers the hero. It runs only when a real mouse is present and motion is
 * allowed (the page adds the `live` class then), and only while the hero is on screen.
 */

type Mode = 'idle' | 'pending' | 'laser' | 'ink';
type TryId = 'shake' | 'hold' | 'draw';
interface Point { x: number; y: number }
interface TimedPoint extends Point { t: number }
interface Stroke {
  pts: Point[];
  /** Set when the pen is lifted; the stroke then lives a little and fades. */
  released: number | null;
  snap: { kind: 'ellipse'; cx: number; cy: number; rx: number; ry: number } | { kind: 'line'; a: Point; b: Point } | null;
  snappedAt: number;
}

const EMBER = '#ff5a36';
const HOT = '#ffd9cf';
const SHAKE_WINDOW = 720;
const HOLD_MS = 200;
const DRAG_PX = 7;
const FIND_MS = 1700;
const INK_LIFE = 2200;
const INK_FADE = 900;
const LASER_LIFE = 520;

const easeOut = (t: number) => 1 - Math.pow(1 - Math.min(Math.max(t, 0), 1), 3);
const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);

/** A rough loop becomes an ellipse, a straight-ish stroke becomes a line, anything else is kept as drawn. */
function cleanUp(pts: Point[]): Stroke['snap'] {
  if (pts.length < 8) return null;
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity, length = 0;
  pts.forEach((p, i) => {
    minX = Math.min(minX, p.x); minY = Math.min(minY, p.y); maxX = Math.max(maxX, p.x); maxY = Math.max(maxY, p.y);
    const prev = pts[i - 1];
    if (prev) length += dist(prev, p);
  });
  const first = pts[0];
  const last = pts[pts.length - 1];
  if (!first || !last) return null;
  const w = maxX - minX;
  const h = maxY - minY;
  const chord = dist(first, last);
  if (length > 110 && Math.min(w, h) > 34 && chord < 0.3 * Math.max(w, h)) {
    return { kind: 'ellipse', cx: (minX + maxX) / 2, cy: (minY + maxY) / 2, rx: w / 2 + 4, ry: h / 2 + 4 };
  }
  if (length > 70 && length / Math.max(chord, 1) < 1.1) return { kind: 'line', a: first, b: last };
  return null;
}

export function initHero(): void {
  const hero = one('[data-hero]');
  const canvas = one<HTMLCanvasElement>('[data-hero-canvas]');
  const base = one('.h-base', hero ?? document);
  const status = one('[data-hero-status]');
  const doneLine = one('[data-try-done]');
  if (!hero || !canvas || !base?.parentElement) return;
  // The ember copy of the headline is built here, not in the markup, so crawlers and screen readers only ever see one headline.
  const emberCopy = document.createElement('span');
  emberCopy.className = 'h-ember';
  emberCopy.setAttribute('aria-hidden', 'true');
  for (const line of all('.h-line', base)) {
    const copy = document.createElement('span');
    copy.className = 'h-line';
    copy.textContent = (line.textContent ?? '').replace(/\s+/g, ' ').trim();
    emberCopy.append(copy);
  }
  base.parentElement.append(emberCopy);
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  const done = new Set<TryId>();
  const names: Record<TryId, string> = { shake: 'Shake', hold: 'Hold', draw: 'Drag' };
  const announce: Record<TryId, string> = {
    shake: 'Shake found your cursor.',
    hold: 'Laser trail on.',
    draw: 'Ink drawn.',
  };
  function markDone(id: TryId): void {
    if (done.has(id)) return;
    done.add(id);
    const item = one(`[data-try="${id}"]`);
    if (item) {
      item.dataset.done = 'true';
      const state = one('[data-try-state]', item);
      if (state) state.textContent = ` ${names[id]} done.`;
    }
    if (status) status.textContent = announce[id];
    hero!.dataset.done = [...done].join(' ');
    if (done.size === 3 && doneLine) doneLine.hidden = false;
  }

  let width = 0;
  let height = 0;
  let dpr = 1;
  function resize(): void {
    const rect = hero!.getBoundingClientRect();
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = rect.width;
    height = rect.height;
    canvas!.width = Math.round(width * dpr);
    canvas!.height = Math.round(height * dpr);
    ctx!.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  resize();
  new ResizeObserver(resize).observe(hero);

  // pointer state, in hero coordinates
  const pointer: Point = { x: -999, y: -999 };
  const halo: Point = { x: -999, y: -999 };
  let inside = false;
  let mode: Mode = 'idle';
  let downAt = 0;
  let downPos: Point = { x: 0, y: 0 };
  let activeId: number | null = null;
  let holdTimer = 0;
  let current: Stroke | null = null;
  const strokes: Stroke[] = [];
  const trail: TimedPoint[] = [];
  const moves: TimedPoint[] = [];
  let findStart = -1e9;
  let lastFind = -1e9;
  let visible = true;
  let raf = 0;

  function setMode(next: Mode): void {
    mode = next;
    hero!.dataset.mode = next;
  }

  function local(e: PointerEvent): Point {
    const rect = hero!.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  }

  function detectShake(now: number): boolean {
    while (moves.length && now - (moves[0]?.t ?? now) > SHAKE_WINDOW) moves.shift();
    if (moves.length < 6) return false;
    let reversals = 0;
    let dir = 0;
    let travel = 0;
    let prev = moves[0];
    for (const m of moves) {
      if (!prev) break;
      const dx = m.x - prev.x;
      if (Math.abs(dx) < 4) { prev = m; continue; }
      const sign = dx > 0 ? 1 : -1;
      if (dir !== 0 && sign !== dir && travel > 36) { reversals++; travel = 0; }
      if (dir === 0 || sign !== dir) dir = sign;
      travel += Math.abs(dx);
      prev = m;
    }
    return reversals >= 4;
  }

  function startLoop(): void {
    if (!raf && visible) raf = requestAnimationFrame(frame);
  }

  function onMove(e: PointerEvent): void {
    if (e.pointerType === 'touch') return;
    const p = local(e);
    const now = performance.now();
    pointer.x = p.x; pointer.y = p.y;
    inside = true;
    if (halo.x < -900) { halo.x = p.x; halo.y = p.y; }

    if (mode === 'idle') {
      moves.push({ x: p.x, y: p.y, t: now });
      if (now - lastFind > 1000 && detectShake(now)) {
        lastFind = now;
        findStart = now;
        moves.length = 0;
        markDone('shake');
      }
    } else if (mode === 'pending') {
      if (dist(p, downPos) > DRAG_PX) {
        window.clearTimeout(holdTimer);
        current = { pts: [downPos, p], released: null, snap: null, snappedAt: 0 };
        strokes.push(current);
        setMode('ink');
      }
    } else if (mode === 'laser') {
      trail.push({ x: p.x, y: p.y, t: now });
    } else if (mode === 'ink' && current) {
      const last = current.pts[current.pts.length - 1];
      if (!last || dist(last, p) > 1.5) current.pts.push(p);
    }
    startLoop();
  }

  function onDown(e: PointerEvent): void {
    if (e.pointerType === 'touch' || e.button !== 0) return;
    const target = e.target;
    if (target instanceof Element && target.closest('a, button, summary, input, [data-no-draw]')) return;
    e.preventDefault();
    const p = local(e);
    activeId = e.pointerId;
    try { hero!.setPointerCapture(e.pointerId); } catch { /* capture is a convenience */ }
    downAt = performance.now();
    downPos = p;
    pointer.x = p.x; pointer.y = p.y;
    setMode('pending');
    window.clearTimeout(holdTimer);
    holdTimer = window.setTimeout(() => {
      if (mode !== 'pending') return;
      setMode('laser');
      trail.length = 0;
      trail.push({ x: pointer.x, y: pointer.y, t: performance.now() });
      markDone('hold');
      startLoop();
    }, HOLD_MS);
    startLoop();
  }

  function onUp(e: PointerEvent): void {
    if (activeId !== null && e.pointerId !== activeId) return;
    window.clearTimeout(holdTimer);
    if (mode === 'ink' && current) {
      const now = performance.now();
      current.released = now;
      current.snap = cleanUp(current.pts);
      if (current.snap) current.snappedAt = now;
      let length = 0;
      current.pts.forEach((pt, i) => { const prev = current?.pts[i - 1]; if (prev) length += dist(prev, pt); });
      if (length > 60) markDone('draw');
      current = null;
    }
    try { if (activeId !== null) hero!.releasePointerCapture(activeId); } catch { /* already released */ }
    activeId = null;
    setMode('idle');
    startLoop();
  }

  function onLeave(): void {
    if (mode === 'idle') inside = false;
    startLoop();
  }

  hero.addEventListener('pointermove', onMove);
  hero.addEventListener('pointerdown', onDown);
  hero.addEventListener('pointerup', onUp);
  hero.addEventListener('pointercancel', onUp);
  hero.addEventListener('pointerleave', onLeave);
  hero.addEventListener('dragstart', (e) => e.preventDefault());

  new IntersectionObserver(([entry]) => {
    visible = Boolean(entry?.isIntersecting);
    if (!visible) { cancelAnimationFrame(raf); raf = 0; } else startLoop();
  }).observe(hero);

  function drawStroke(s: Stroke, now: number): boolean {
    let alpha = 1;
    if (s.released !== null) {
      const age = now - s.released;
      if (age > INK_LIFE + INK_FADE) return false;
      if (age > INK_LIFE) alpha = 1 - (age - INK_LIFE) / INK_FADE;
    }
    ctx!.save();
    ctx!.globalAlpha = alpha;
    ctx!.strokeStyle = EMBER;
    ctx!.lineWidth = 5;
    ctx!.lineCap = 'round';
    ctx!.lineJoin = 'round';
    ctx!.beginPath();
    if (s.snap?.kind === 'ellipse') {
      const k = 1 + 0.05 * (1 - easeOut((now - s.snappedAt) / 260));
      ctx!.ellipse(s.snap.cx, s.snap.cy, s.snap.rx * k, s.snap.ry * k, 0, 0, Math.PI * 2);
    } else if (s.snap?.kind === 'line') {
      ctx!.moveTo(s.snap.a.x, s.snap.a.y);
      ctx!.lineTo(s.snap.b.x, s.snap.b.y);
    } else {
      const [first, ...rest] = s.pts;
      if (first) {
        ctx!.moveTo(first.x, first.y);
        rest.forEach((p, i) => {
          const prev = s.pts[i];
          if (prev) ctx!.quadraticCurveTo(prev.x, prev.y, (prev.x + p.x) / 2, (prev.y + p.y) / 2);
        });
        const end = s.pts[s.pts.length - 1];
        if (end) ctx!.lineTo(end.x, end.y);
      }
    }
    if (s.pts.length === 1 || (s.pts.length === 2 && !s.snap)) ctx!.lineTo((s.pts[0]?.x ?? 0) + 0.1, s.pts[0]?.y ?? 0);
    ctx!.stroke();
    ctx!.restore();
    return true;
  }

  function drawLaser(now: number): void {
    while (trail.length && now - (trail[0]?.t ?? now) > LASER_LIFE) trail.shift();
    const n = trail.length;
    if (n > 1) {
      for (let i = 1; i < n; i++) {
        const a = trail[i - 1];
        const b = trail[i];
        if (!a || !b) continue;
        const age = Math.min((now - b.t) / LASER_LIFE, 1);
        const k = 1 - age;
        ctx!.lineCap = 'round';
        ctx!.globalAlpha = 0.9 * k;
        ctx!.strokeStyle = EMBER;
        ctx!.lineWidth = 3 + 9 * k;
        ctx!.beginPath(); ctx!.moveTo(a.x, a.y); ctx!.lineTo(b.x, b.y); ctx!.stroke();
        ctx!.globalAlpha = k;
        ctx!.strokeStyle = HOT;
        ctx!.lineWidth = 1 + 3 * k;
        ctx!.beginPath(); ctx!.moveTo(a.x, a.y); ctx!.lineTo(b.x, b.y); ctx!.stroke();
      }
      ctx!.globalAlpha = 1;
    }
    if (mode === 'laser') {
      ctx!.fillStyle = EMBER;
      ctx!.beginPath(); ctx!.arc(pointer.x, pointer.y, 9, 0, Math.PI * 2); ctx!.fill();
      ctx!.fillStyle = HOT;
      ctx!.beginPath(); ctx!.arc(pointer.x, pointer.y, 3.5, 0, Math.PI * 2); ctx!.fill();
    }
  }

  function drawFind(now: number): void {
    const t = (now - findStart) / FIND_MS;
    if (t < 0 || t > 1) return;
    const x = halo.x;
    const y = halo.y;
    const r = 58 + 150 * (1 - easeOut(t * 2.2));
    const fade = t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4;
    ctx!.save();
    ctx!.globalAlpha = 0.2 * fade;
    ctx!.fillStyle = EMBER;
    ctx!.beginPath(); ctx!.arc(x, y, r, 0, Math.PI * 2); ctx!.fill();
    ctx!.globalAlpha = fade;
    ctx!.strokeStyle = EMBER;
    ctx!.lineWidth = 3;
    ctx!.beginPath(); ctx!.arc(x, y, r, 0, Math.PI * 2); ctx!.stroke();
    // sonar rings
    for (const delay of [0, 0.16]) {
      const s = (t - delay) / 0.55;
      if (s <= 0 || s >= 1) continue;
      ctx!.globalAlpha = 0.55 * (1 - s);
      ctx!.lineWidth = 2;
      ctx!.beginPath(); ctx!.arc(x, y, 60 + 230 * easeOut(s), 0, Math.PI * 2); ctx!.stroke();
    }
    ctx!.restore();
  }

  function frame(now: number): void {
    raf = 0;
    ctx!.clearRect(0, 0, width, height);

    // The halo trails the pointer a little, like the app's keyline style.
    halo.x += (pointer.x - halo.x) * 0.28;
    halo.y += (pointer.y - halo.y) * 0.28;

    let busy = mode !== 'idle' || trail.length > 0;
    for (let i = strokes.length - 1; i >= 0; i--) {
      const s = strokes[i];
      if (!s || !drawStroke(s, now)) strokes.splice(i, 1);
      else busy = true;
    }
    drawLaser(now);
    drawFind(now);

    const finding = now - findStart < FIND_MS;
    if (inside && mode === 'idle') {
      ctx!.strokeStyle = EMBER;
      ctx!.globalAlpha = finding ? 0.0 : 0.6;
      ctx!.lineWidth = 2;
      ctx!.beginPath(); ctx!.arc(halo.x, halo.y, 20, 0, Math.PI * 2); ctx!.stroke();
      ctx!.globalAlpha = 1;
    }

    // The ember copy of the headline shows inside a circle at the pointer; a find makes it swell.
    const swell = finding ? 1 - Math.abs((now - findStart) / FIND_MS * 2 - 0.5) : 0;
    const radius = inside ? 74 + 170 * Math.max(0, Math.min(swell, 1)) : 0;
    const origin = emberOffset();
    emberCopy!.style.setProperty('--mx', `${halo.x - origin.x}px`);
    emberCopy!.style.setProperty('--my', `${halo.y - origin.y}px`);
    emberCopy!.style.setProperty('--mr', `${radius}px`);

    const settling = Math.hypot(pointer.x - halo.x, pointer.y - halo.y) > 0.5;
    if (visible && (busy || finding || settling || inside)) raf = requestAnimationFrame(frame);
  }

  /** The mask is positioned against the ember copy's own box, not the hero, so convert. */
  function emberOffset(): Point {
    const a = emberCopy!.getBoundingClientRect();
    const b = hero!.getBoundingClientRect();
    return { x: a.left - b.left, y: a.top - b.top };
  }
}
