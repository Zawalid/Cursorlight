/**
 * The pointer engine behind the page: a small web version of the app's effects, drawn on one fixed canvas.
 *   Tools: highlight (six styles), laser, ink, spotlight. Shake the mouse anywhere and a highlight finds the cursor.
 *   In the hero (a gesture zone) with no tool chosen: press and hold for a laser, press and drag for ink.
 * It runs only for a real mouse with motion allowed (the page adds the `live` class then). Nothing here touches the network.
 */

export type Tool = 'none' | 'highlight' | 'laser' | 'ink' | 'spotlight';
export type StyleName = 'aura' | 'lens' | 'comet' | 'keyline' | 'sonar' | 'crosshair';
export type ColorName = 'ember' | 'amber' | 'mint' | 'white';
export type Surface = 'dark' | 'paper' | 'ember';
export type EngineEvent = 'shake' | 'hold' | 'draw';

export const STYLES: readonly StyleName[] = ['aura', 'lens', 'comet', 'keyline', 'sonar', 'crosshair'];
export const COLORS: readonly ColorName[] = ['ember', 'amber', 'mint', 'white'];

interface P { x: number; y: number }
interface TP extends P { t: number }
type Snap = { kind: 'ellipse'; cx: number; cy: number; rx: number; ry: number } | { kind: 'line'; a: P; b: P };
interface Stroke { pts: P[]; color: string; released: number | null; snap: Snap | null; snappedAt: number }

const PALETTE: Record<Surface, Record<ColorName, string>> = {
  dark: { ember: '#ff5a36', amber: '#ffb020', mint: '#3ddc97', white: '#f4efe8' },
  paper: { ember: '#c23a19', amber: '#b26a00', mint: '#0a8f5a', white: '#14121a' },
  ember: { ember: '#14121a', amber: '#14121a', mint: '#14121a', white: '#14121a' },
};
const HOT: Record<Surface, string> = { dark: '#ffe6dd', paper: '#ffffff', ember: '#ffffff' };
const DIM: Record<Surface, string> = { dark: '8, 6, 12', paper: '20, 18, 26', ember: '20, 18, 26' };

const SHAKE_WINDOW = 720;
const HOLD_MS = 200;
const DRAG_PX = 7;
const FIND_MS = 1700;
const INK_LIFE = 2400;
const INK_FADE = 900;
const LASER_LIFE = 520;
const COMET_LIFE = 420;

const easeOut = (t: number) => 1 - Math.pow(1 - Math.min(Math.max(t, 0), 1), 3);
const dist = (a: P, b: P) => Math.hypot(a.x - b.x, a.y - b.y);

/** A rough loop becomes an ellipse and a straight-ish stroke becomes a line, like the app's shape cleanup. */
export function cleanUp(pts: P[], forceLine = false): Snap | null {
  if (pts.length < 6) return null;
  const first = pts[0];
  const last = pts[pts.length - 1];
  if (!first || !last) return null;
  if (forceLine) return dist(first, last) > 30 ? { kind: 'line', a: first, b: last } : null;
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity, length = 0;
  pts.forEach((p, i) => {
    minX = Math.min(minX, p.x); minY = Math.min(minY, p.y); maxX = Math.max(maxX, p.x); maxY = Math.max(maxY, p.y);
    const prev = pts[i - 1];
    if (prev) length += dist(prev, p);
  });
  const w = maxX - minX;
  const h = maxY - minY;
  const chord = dist(first, last);
  if (length > 110 && Math.min(w, h) > 34 && chord < 0.3 * Math.max(w, h)) {
    return { kind: 'ellipse', cx: (minX + maxX) / 2, cy: (minY + maxY) / 2, rx: w / 2 + 4, ry: h / 2 + 4 };
  }
  if (length > 70 && length / Math.max(chord, 1) < 1.1) return { kind: 'line', a: first, b: last };
  return null;
}

type Listener = () => void;

export class Engine {
  readonly canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  tool: Tool = 'none';
  style: StyleName = 'aura';
  colorName: ColorName = 'ember';
  paused = false;

  /** Where the effects are centred (eased behind the pointer), read by the hero to light the headline. */
  readonly halo: P = { x: -999, y: -999 };
  readonly pointer: P = { x: -999, y: -999 };
  /** What the pointer is doing right now, for the hero's data attribute and the checks. */
  get mode(): string { return this.gesture !== 'none' ? this.gesture : this.tool === 'none' ? 'idle' : this.tool; }
  inside = false;
  /** Radius of the headline reveal circle, 0 when it should be hidden. */
  reveal = 0;

  private width = 0;
  private height = 0;
  private dpr = 1;
  private strokes: Stroke[] = [];
  private current: Stroke | null = null;
  private trail: TP[] = [];
  private moves: TP[] = [];
  private findStart = -1e9;
  private lastFind = -1e9;
  private sonarAt = 0;
  private raf = 0;
  private downPos: P = { x: 0, y: 0 };
  private activeId: number | null = null;
  private gesture: 'none' | 'pending' | 'laser' | 'ink' = 'none';
  private holdTimer = 0;
  private shift = false;
  private keepAlive = false;
  private ghost: { x: number; y: number; alpha: number } | null = null;
  private ghostDriven = false;
  private frameHooks: Array<(e: Engine, now: number) => void> = [];
  private changeHooks: Listener[] = [];
  private eventHooks: Record<EngineEvent, Array<() => void>> = { shake: [], hold: [], draw: [] };
  private takeover: Listener | null = null;

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('2d canvas not available');
    this.ctx = ctx;
    this.resize();
    window.addEventListener('resize', () => this.resize());
    window.addEventListener('pointermove', (e) => this.onMove(e), { passive: true });
    window.addEventListener('pointerdown', (e) => this.onDown(e));
    window.addEventListener('pointerup', (e) => this.onUp(e));
    window.addEventListener('pointercancel', (e) => this.onUp(e));
    document.documentElement.addEventListener('pointerleave', () => { this.inside = false; this.kick(); });
    document.documentElement.addEventListener('pointerenter', () => { this.inside = true; });
    window.addEventListener('keydown', (e) => this.onKey(e));
    window.addEventListener('keyup', (e) => { if (e.key === 'Shift') this.shift = false; });
    document.addEventListener('visibilitychange', () => { if (document.hidden) { cancelAnimationFrame(this.raf); this.raf = 0; } else this.kick(); });
    window.addEventListener('scroll', () => { if (this.tool !== 'none' || this.keepAlive) this.kick(); }, { passive: true });
    this.syncUi();
  }

  // ---- public API ------------------------------------------------------------------------------------------------

  on(event: EngineEvent, fn: () => void): void { this.eventHooks[event].push(fn); }
  onChange(fn: Listener): void { this.changeHooks.push(fn); }
  onFrame(fn: (e: Engine, now: number) => void): void { this.frameHooks.push(fn); }
  /** The hero asks for frames while it is on screen so the headline reveal follows the pointer. */
  setKeepAlive(on: boolean): void { this.keepAlive = on; this.kick(); }
  setTakeover(fn: Listener | null): void { this.takeover = fn; }

  setTool(tool: Tool): void {
    this.tool = tool;
    if (tool !== 'none') this.paused = false;
    this.gesture = 'none';
    this.syncUi();
    this.announce(tool === 'none' ? 'Tools off' : `${this.toolLabel(tool)} on`);
    this.kick();
  }
  toggleTool(tool: Tool): void { this.setTool(this.tool === tool ? 'none' : tool); }
  setStyle(style: StyleName, announce = true): void {
    this.style = style;
    if (this.tool === 'none') this.tool = 'highlight';
    this.paused = false;
    this.syncUi();
    if (announce) this.announce(`Highlight style: ${style}`);
    this.kick();
  }
  cycleStyle(): void { this.setStyle(STYLES[(STYLES.indexOf(this.style) + 1) % STYLES.length] ?? 'aura'); }
  cycleColor(): void {
    this.colorName = COLORS[(COLORS.indexOf(this.colorName) + 1) % COLORS.length] ?? 'ember';
    this.syncUi();
    this.announce(`Color: ${this.colorName}`);
    this.kick();
  }
  clearInk(announce = true): void { this.strokes = []; this.current = null; if (announce) this.announce('Ink cleared'); this.kick(); }
  togglePause(): void {
    this.paused = !this.paused;
    this.syncUi();
    this.announce(this.paused ? 'Paused' : 'Resumed');
    this.kick();
  }
  toolLabel(tool: Tool): string { return { none: 'Tools', highlight: 'Highlight', laser: 'Laser', ink: 'Ink', spotlight: 'Spotlight' }[tool]; }

  /** Used by the scripted demo: drive the pointer as if it were real. */
  setGhost(pos: P | null, alpha = 1): void {
    this.ghost = pos ? { x: pos.x, y: pos.y, alpha } : null;
    this.ghostDriven = Boolean(pos);
    if (pos) { this.movePointer(pos.x, pos.y, performance.now(), true); }
    this.kick();
  }
  beginStroke(at: P): void {
    this.current = { pts: [at], color: this.stroke(), released: null, snap: null, snappedAt: 0 };
    this.strokes.push(this.current);
  }
  addToStroke(at: P): void { this.current?.pts.push(at); this.kick(); }
  endStroke(forceLine = false): void {
    const s = this.current;
    if (!s) return;
    const now = performance.now();
    s.released = now;
    s.snap = cleanUp(s.pts, forceLine);
    if (s.snap) s.snappedAt = now;
    let length = 0;
    s.pts.forEach((p, i) => { const prev = s.pts[i - 1]; if (prev) length += dist(prev, p); });
    if (length > 60 && !this.ghostDriven) this.emit('draw');
    this.current = null;
    this.kick();
  }
  find(): void { this.findStart = performance.now(); this.lastFind = this.findStart; this.kick(); }

  // ---- internals -------------------------------------------------------------------------------------------------

  private emit(event: EngineEvent): void { for (const fn of this.eventHooks[event]) fn(); }
  private announce(text: string): void {
    const el = document.querySelector('[data-fx-status]');
    if (el) el.textContent = text;
  }
  private syncUi(): void {
    const root = document.documentElement;
    root.dataset.fx = this.paused ? 'paused' : this.tool === 'none' ? 'idle' : 'on';
    for (const fn of this.changeHooks) fn();
    const ink = this.tool === 'ink' && !this.paused;
    this.canvas.style.pointerEvents = ink ? 'auto' : 'none';
    this.canvas.style.cursor = ink ? 'crosshair' : '';
  }

  private resize(): void {
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.width = window.innerWidth;
    this.height = window.innerHeight;
    this.canvas.width = Math.round(this.width * this.dpr);
    this.canvas.height = Math.round(this.height * this.dpr);
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    this.kick();
  }

  private surfaceAt(y: number): Surface {
    for (const el of document.querySelectorAll<HTMLElement>('[data-surface]')) {
      const r = el.getBoundingClientRect();
      if (y >= r.top && y < r.bottom) {
        const s = el.dataset.surface;
        if (s === 'paper' || s === 'ember') return s;
        return 'dark';
      }
    }
    return 'dark';
  }
  private surface: Surface = 'dark';
  private col(): string { return PALETTE[this.surface][this.colorName]; }
  private stroke(): string { return this.col(); }

  private inGestureZone(y: number): boolean {
    for (const el of document.querySelectorAll('[data-gesture-zone]')) {
      const r = el.getBoundingClientRect();
      if (y >= r.top && y <= r.bottom) return true;
    }
    return false;
  }

  private detectShake(now: number): boolean {
    while (this.moves.length && now - (this.moves[0]?.t ?? now) > SHAKE_WINDOW) this.moves.shift();
    if (this.moves.length < 6) return false;
    let reversals = 0, dir = 0, travel = 0;
    let prev = this.moves[0];
    for (const m of this.moves) {
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

  private movePointer(x: number, y: number, now: number, synthetic: boolean): void {
    this.pointer.x = x; this.pointer.y = y;
    this.inside = true;
    if (this.halo.x < -900) { this.halo.x = x; this.halo.y = y; }
    this.surface = this.surfaceAt(y);
    if (this.gesture !== 'ink' && !this.current) {
      this.moves.push({ x, y, t: now });
      if (now - this.lastFind > 1000 && this.detectShake(now)) {
        this.moves.length = 0;
        this.find();
        if (!synthetic) this.emit('shake');
      }
    }
    if (this.tool === 'laser' && !this.paused) this.trail.push({ x, y, t: now });
    if (this.tool === 'highlight' && this.style === 'comet' && !this.paused) this.trail.push({ x, y, t: now });
    if (synthetic && this.gesture === 'laser') this.trail.push({ x, y, t: now });
  }

  private onMove(e: PointerEvent): void {
    if (e.pointerType === 'touch') return;
    if (this.ghostDriven) { this.ghostDriven = false; this.ghost = null; this.takeover?.(); }
    const now = performance.now();
    const p = { x: e.clientX, y: e.clientY };
    this.movePointer(p.x, p.y, now, false);

    if (this.tool === 'none') {
      if (this.gesture === 'pending' && dist(p, this.downPos) > DRAG_PX) {
        window.clearTimeout(this.holdTimer);
        this.gesture = 'ink';
        this.beginStroke(this.downPos);
        this.addToStroke(p);
      } else if (this.gesture === 'laser') {
        this.trail.push({ x: p.x, y: p.y, t: now });
      } else if (this.gesture === 'ink') {
        this.addToStroke(p);
      }
    } else if (this.tool === 'ink' && this.current && !this.paused) {
      const last = this.current.pts[this.current.pts.length - 1];
      if (!last || dist(last, p) > 1.5) this.addToStroke(p);
    }
    this.kick();
  }

  private onDown(e: PointerEvent): void {
    if (e.pointerType === 'touch' || e.button !== 0 || this.paused) return;
    const target = e.target;
    if (target instanceof Element && target.closest('a, button, summary, input, textarea, select, [data-no-draw], [data-fxbar]')) return;
    const p = { x: e.clientX, y: e.clientY };
    if (this.tool === 'ink') {
      e.preventDefault();
      this.activeId = e.pointerId;
      this.beginStroke(p);
      this.kick();
      return;
    }
    if (this.tool === 'none' && this.inGestureZone(p.y)) {
      e.preventDefault();
      this.activeId = e.pointerId;
      this.downPos = p;
      this.gesture = 'pending';
      window.clearTimeout(this.holdTimer);
      this.holdTimer = window.setTimeout(() => {
        if (this.gesture !== 'pending') return;
        this.gesture = 'laser';
        this.trail = [{ x: this.pointer.x, y: this.pointer.y, t: performance.now() }];
        this.emit('hold');
        this.kick();
      }, HOLD_MS);
    }
  }

  private onUp(e: PointerEvent): void {
    if (this.activeId !== null && e.pointerId !== this.activeId) return;
    window.clearTimeout(this.holdTimer);
    if (this.current) this.endStroke(this.shift);
    this.gesture = 'none';
    this.activeId = null;
    this.kick();
  }

  private onKey(e: KeyboardEvent): void {
    if (e.key === 'Shift') this.shift = true;
    if (this.ghostDriven) { this.ghostDriven = false; this.ghost = null; this.takeover?.(); }
    if (e.key === 'Escape' && this.tool !== 'none') { this.setTool('none'); return; }
    if (!(e.ctrlKey && e.altKey) || e.metaKey) return;
    const map: Record<string, () => void> = {
      KeyH: () => this.toggleTool('highlight'),
      KeyL: () => this.toggleTool('laser'),
      KeyI: () => this.toggleTool('ink'),
      KeyS: () => this.toggleTool('spotlight'),
      KeyP: () => this.togglePause(),
    };
    const action = map[e.code];
    if (action) { e.preventDefault(); action(); }
  }

  /** Ask for a frame, unless one is already coming. */
  kick(): void { if (!this.raf && !document.hidden) this.raf = requestAnimationFrame((t) => this.frame(t)); }

  private frame(now: number): void {
    this.raf = 0;
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.width, this.height);
    this.halo.x += (this.pointer.x - this.halo.x) * 0.3;
    this.halo.y += (this.pointer.y - this.halo.y) * 0.3;
    const live = !this.paused;
    const on = this.inside || this.ghost !== null;
    let busy = false;

    if (live && on) {
      if (this.tool === 'spotlight') { this.drawDim(190, 0.74); busy = true; }
      if (this.tool === 'highlight') { this.drawStyle(now); busy = true; }
    }
    for (let i = this.strokes.length - 1; i >= 0; i--) {
      const s = this.strokes[i];
      if (!s || !this.drawStroke(s, now)) this.strokes.splice(i, 1); else busy = true;
    }
    if (this.trail.length) { this.drawTrail(now); busy = true; }
    const finding = now - this.findStart < FIND_MS;
    if (finding) { this.drawFind(now); busy = true; }
    if (this.tool === 'none' && this.gesture === 'none' && on && this.keepAlive && !finding) this.drawRest();
    if (this.ghost) { this.drawGhost(this.ghost); busy = true; }

    // The headline reveal: a circle that follows the pointer, swelling during a find.
    const swell = finding ? 1 - Math.abs(((now - this.findStart) / FIND_MS) * 2 - 0.5) : 0;
    this.reveal = on && this.keepAlive ? 74 + 170 * Math.max(0, Math.min(swell, 1)) : 0;
    for (const hook of this.frameHooks) hook(this, now);

    const settling = Math.hypot(this.pointer.x - this.halo.x, this.pointer.y - this.halo.y) > 0.5;
    if (busy || settling || (on && this.keepAlive)) this.kick();
  }

  private drawDim(radius: number, alpha: number): void {
    const ctx = this.ctx;
    ctx.save();
    ctx.fillStyle = `rgba(${DIM[this.surface]}, ${alpha})`;
    ctx.fillRect(0, 0, this.width, this.height);
    ctx.globalCompositeOperation = 'destination-out';
    const g = ctx.createRadialGradient(this.halo.x, this.halo.y, radius * 0.72, this.halo.x, this.halo.y, radius);
    g.addColorStop(0, 'rgba(0,0,0,1)');
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g;
    ctx.fillRect(this.halo.x - radius, this.halo.y - radius, radius * 2, radius * 2);
    ctx.restore();
  }

  private drawStyle(now: number): void {
    const ctx = this.ctx;
    const { x, y } = this.halo;
    const c = this.col();
    ctx.save();
    switch (this.style) {
      case 'aura': {
        const r = 52 + Math.sin(now / 520) * 4;
        const g = ctx.createRadialGradient(x, y, 0, x, y, r);
        g.addColorStop(0, hexA(c, 0.55)); g.addColorStop(1, hexA(c, 0));
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
        break;
      }
      case 'lens': {
        this.drawDim(96, 0.5);
        ctx.strokeStyle = hexA(c, 0.85); ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(x, y, 66, 0, Math.PI * 2); ctx.stroke();
        break;
      }
      case 'comet': {
        ctx.fillStyle = c; ctx.beginPath(); ctx.arc(x, y, 6, 0, Math.PI * 2); ctx.fill();
        break;
      }
      case 'keyline': {
        ctx.strokeStyle = c; ctx.lineWidth = 2.5; ctx.globalAlpha = 0.95;
        ctx.beginPath(); ctx.arc(x, y, 22, 0, Math.PI * 2); ctx.stroke();
        break;
      }
      case 'sonar': {
        ctx.strokeStyle = c; ctx.lineWidth = 2; ctx.globalAlpha = 0.9;
        ctx.beginPath(); ctx.arc(x, y, 14, 0, Math.PI * 2); ctx.stroke();
        const phase = ((now - this.sonarAt) % 1500) / 1500;
        for (const o of [0, 0.5]) {
          const t = (phase + o) % 1;
          ctx.globalAlpha = 0.6 * (1 - t);
          ctx.beginPath(); ctx.arc(x, y, 16 + 120 * easeOut(t), 0, Math.PI * 2); ctx.stroke();
        }
        break;
      }
      case 'crosshair': {
        ctx.strokeStyle = c; ctx.lineWidth = 1.5; ctx.globalAlpha = 0.7;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(this.width, y); ctx.moveTo(x, 0); ctx.lineTo(x, this.height); ctx.stroke();
        ctx.globalAlpha = 1; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(x, y, 12, 0, Math.PI * 2); ctx.stroke();
        break;
      }
    }
    ctx.restore();
  }

  /** A quiet keyline ring that trails the pointer when no tool is on, so the hero feels awake. */
  private drawRest(): void {
    const ctx = this.ctx;
    ctx.save();
    ctx.strokeStyle = this.col(); ctx.globalAlpha = 0.6; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(this.halo.x, this.halo.y, 20, 0, Math.PI * 2); ctx.stroke();
    ctx.restore();
  }

  private drawStroke(s: Stroke, now: number): boolean {
    let alpha = 1;
    if (s.released !== null) {
      const age = now - s.released;
      if (age > INK_LIFE + INK_FADE) return false;
      if (age > INK_LIFE) alpha = 1 - (age - INK_LIFE) / INK_FADE;
    }
    const ctx = this.ctx;
    ctx.save();
    ctx.globalAlpha = alpha; ctx.strokeStyle = s.color; ctx.lineWidth = 5; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    ctx.beginPath();
    if (s.snap?.kind === 'ellipse') {
      const k = 1 + 0.05 * (1 - easeOut((now - s.snappedAt) / 260));
      ctx.ellipse(s.snap.cx, s.snap.cy, s.snap.rx * k, s.snap.ry * k, 0, 0, Math.PI * 2);
    } else if (s.snap?.kind === 'line') {
      ctx.moveTo(s.snap.a.x, s.snap.a.y); ctx.lineTo(s.snap.b.x, s.snap.b.y);
    } else {
      const [first, ...rest] = s.pts;
      if (first) {
        ctx.moveTo(first.x, first.y);
        rest.forEach((p, i) => {
          const prev = s.pts[i];
          if (prev) ctx.quadraticCurveTo(prev.x, prev.y, (prev.x + p.x) / 2, (prev.y + p.y) / 2);
        });
        const end = s.pts[s.pts.length - 1];
        if (end) ctx.lineTo(end.x, end.y);
        if (s.pts.length === 1) ctx.lineTo(first.x + 0.1, first.y);
      }
    }
    ctx.stroke();
    ctx.restore();
    return true;
  }

  private drawTrail(now: number): void {
    const comet = this.tool === 'highlight' && this.style === 'comet' && this.gesture !== 'laser';
    const life = comet ? COMET_LIFE : LASER_LIFE;
    while (this.trail.length && now - (this.trail[0]?.t ?? now) > life) this.trail.shift();
    const ctx = this.ctx;
    const c = this.col();
    ctx.save();
    ctx.lineCap = 'round';
    for (let i = 1; i < this.trail.length; i++) {
      const a = this.trail[i - 1];
      const b = this.trail[i];
      if (!a || !b) continue;
      const k = 1 - Math.min((now - b.t) / life, 1);
      ctx.globalAlpha = 0.9 * k; ctx.strokeStyle = c; ctx.lineWidth = (comet ? 2 : 3) + (comet ? 7 : 9) * k;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      if (!comet) {
        ctx.globalAlpha = k; ctx.strokeStyle = HOT[this.surface]; ctx.lineWidth = 1 + 3 * k;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      }
    }
    ctx.restore();
    const laserOn = (this.tool === 'laser' && !this.paused && (this.inside || this.ghost)) || this.gesture === 'laser';
    if (laserOn) {
      ctx.save();
      ctx.fillStyle = c; ctx.beginPath(); ctx.arc(this.pointer.x, this.pointer.y, 9, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = HOT[this.surface]; ctx.beginPath(); ctx.arc(this.pointer.x, this.pointer.y, 3.5, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  }

  private drawFind(now: number): void {
    const t = (now - this.findStart) / FIND_MS;
    if (t < 0 || t > 1) return;
    const { x, y } = this.halo;
    const c = this.col();
    const r = 58 + 150 * (1 - easeOut(t * 2.2));
    const fade = t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4;
    const ctx = this.ctx;
    ctx.save();
    ctx.globalAlpha = 0.2 * fade; ctx.fillStyle = c;
    ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = fade; ctx.strokeStyle = c; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.stroke();
    for (const delay of [0, 0.16]) {
      const s = (t - delay) / 0.55;
      if (s <= 0 || s >= 1) continue;
      ctx.globalAlpha = 0.55 * (1 - s); ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(x, y, 60 + 230 * easeOut(s), 0, Math.PI * 2); ctx.stroke();
    }
    ctx.restore();
  }

  /** The scripted demo's pointer: an arrow with a ring, so it reads as a presenter's cursor and not the visitor's own. */
  private drawGhost(g: { x: number; y: number; alpha: number }): void {
    const ctx = this.ctx;
    ctx.save();
    ctx.globalAlpha = g.alpha;
    ctx.translate(g.x, g.y);
    ctx.strokeStyle = this.col(); ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(0, 0, 18, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = '#14121a'; ctx.strokeStyle = '#f4efe8'; ctx.lineWidth = 1.6; ctx.lineJoin = 'round';
    ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, 17); ctx.lineTo(4.2, 13.2); ctx.lineTo(7.2, 19.6); ctx.lineTo(10, 18.4); ctx.lineTo(7.1, 12); ctx.lineTo(12.6, 11.6); ctx.closePath();
    ctx.fill(); ctx.stroke();
    ctx.restore();
  }
}

function hexA(hex: string, a: number): string {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
}
