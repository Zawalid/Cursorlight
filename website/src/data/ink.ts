/** Hand-made looking marks, computed at build time: the same loop-and-underline vocabulary the app draws with. */

function rand(seed: number): () => number {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

const f = (n: number) => Math.round(n * 10) / 10;

/** A rough loop around an ellipse, drawn a little more than one turn, so it overshoots the way a pen does. */
export function handLoop(cx: number, cy: number, rx: number, ry: number, seed = 1): string {
  const r = rand(seed);
  const a0 = -Math.PI * (0.55 + r() * 0.5);
  const turns = 1.06 + r() * 0.07;
  const steps = 64;
  const p1 = r() * 6;
  const p2 = r() * 6;
  const pts: string[] = [];
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const a = a0 + t * Math.PI * 2 * turns;
    const drift = 1 + 0.06 * Math.sin(a * 2 + p1) + 0.035 * Math.sin(a * 3 + p2) + t * 0.05;
    pts.push(`${i === 0 ? 'M' : 'L'}${f(cx + Math.cos(a) * rx * drift)} ${f(cy + Math.sin(a) * ry * drift)}`);
  }
  return pts.join('');
}

/** A quick underline stroke with a slight lift at the end. */
export function handLine(x1: number, y1: number, x2: number, y2: number, seed = 1): string {
  const r = rand(seed);
  const steps = 24;
  const pts: string[] = [];
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const wob = Math.sin(t * Math.PI * 2 + r() * 0.4) * 1.6 + (r() - 0.5) * 0.8;
    pts.push(`${i === 0 ? 'M' : 'L'}${f(x1 + (x2 - x1) * t)} ${f(y1 + (y2 - y1) * t + wob - t * 3)}`);
  }
  return pts.join('');
}
