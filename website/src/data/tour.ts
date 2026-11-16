import { handLoop } from './ink';

export const IMG = { w: 2360, h: 1480 };

export interface Beat {
  id: string;
  /** Which capture is on screen. */
  image: 'overview' | 'draw' | 'apps';
  title: string;
  text: string;
  keys?: string[][];
  /** The point the camera looks at, as fractions of the picture, and how far it zooms in. */
  focus: { x: number; y: number; zoom: number };
  /** Which side the caption card sits on, so it never covers what the camera is looking at. */
  side?: 'left' | 'right';
  /** Ink drawn over the picture when the camera arrives, in picture pixels. */
  mark?: { d: string };
}

export const beats: Beat[] = [
  {
    id: 'whole',
    image: 'overview',
    title: 'Four tools. One shortcut each.',
    text: 'Cursorlight sits on top of every app. Press a shortcut and the tool is there, press it again and it is gone.',
    keys: [['Control', 'Option', 'H'], ['L'], ['I'], ['S']],
    focus: { x: 0.5, y: 0.5, zoom: 1 },
  },
  {
    id: 'find',
    image: 'overview',
    title: 'Shake to find it.',
    text: 'Lost your cursor in a busy window? Shake the mouse and a highlight swells around it, then settles.',
    focus: { x: 853 / IMG.w, y: 740 / IMG.h, zoom: 2.2 },
    mark: { d: handLoop(853, 740, 118, 96, 7) },
  },
  {
    id: 'styles',
    image: 'overview',
    title: 'Six styles, your colors.',
    text: 'Aura, Lens, Comet, Keyline, Sonar or Crosshair. Pick the color, the size and how strong it is.',
    focus: { x: 2030 / IMG.w, y: 300 / IMG.h, zoom: 1.7 },
    mark: { d: handLoop(2034, 292, 338, 90, 3) },
  },
  {
    id: 'draw',
    image: 'draw',
    title: 'Rough loops snap clean.',
    text: 'Draw with five pens, arrows, boxes, text and stamps. Rough shapes snap clean, and the ink fades by itself.',
    focus: { x: 728 / IMG.w, y: 668 / IMG.h, zoom: 2.2 },
    mark: { d: handLoop(728, 668, 238, 92, 11) },
  },
  {
    id: 'scenes',
    image: 'overview',
    title: 'One look per situation.',
    text: 'Save a whole look as a scene: Stream, Meeting, Recording or your own. Switch with a shortcut.',
    side: 'right',
    focus: { x: 420 / IMG.w, y: 1360 / IMG.h, zoom: 2.2 },
    mark: { d: handLoop(155, 1345, 152, 106, 5) },
  },
  {
    id: 'apps',
    image: 'apps',
    title: 'It switches by itself.',
    text: 'Give Zoom the Meeting scene, or turn Cursorlight off in a video player. It follows the app in front.',
    focus: { x: 2030 / IMG.w, y: 1010 / IMG.h, zoom: 1.75 },
    mark: { d: handLoop(2027, 836, 338, 54, 9) },
  },
];
