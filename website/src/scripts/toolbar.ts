import { COLORS, STYLES, type Engine, type Tool } from './engine';
import { all, one } from './dom';

const COLOR_HEX: Record<string, string> = { ember: '#ff5a36', amber: '#ffb020', mint: '#3ddc97', white: '#f4efe8' };
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

/** Wires the floating bar to the engine and keeps every button's state in step with it. */
export function initToolbar(engine: Engine): void {
  const bar = one('[data-fxbar]');
  if (!bar) return;
  bar.hidden = false;
  const tools = all<HTMLButtonElement>('[data-tool]', bar);
  const styleBtn = one<HTMLButtonElement>('[data-style-cycle]', bar);
  const styleName = one('[data-style-name]', bar);
  const colorBtn = one<HTMLButtonElement>('[data-color-cycle]', bar);
  const dot = one('[data-color-dot]', bar);
  const clear = one<HTMLButtonElement>('[data-clear]', bar);

  for (const b of tools) b.addEventListener('click', () => engine.toggleTool((b.dataset.tool ?? 'none') as Tool));
  styleBtn?.addEventListener('click', () => engine.cycleStyle());
  colorBtn?.addEventListener('click', () => engine.cycleColor());
  clear?.addEventListener('click', () => engine.clearInk());

  const sync = () => {
    for (const b of tools) b.setAttribute('aria-pressed', String(engine.tool === b.dataset.tool && !engine.paused));
    if (styleName) styleName.textContent = cap(engine.style);
    if (dot) dot.style.background = COLOR_HEX[engine.colorName] ?? '#ff5a36';
    colorBtn?.setAttribute('aria-label', `Color: ${cap(engine.colorName)}. Change`);
    document.dispatchEvent(new CustomEvent('cl:fx'));
  };
  engine.onChange(sync);
  sync();
  void STYLES; void COLORS;
}
