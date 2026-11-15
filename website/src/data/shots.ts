import type { ImageMetadata } from 'astro';

/**
 * Every product screenshot on the page, in one place.
 *
 * The files live in `docs/images/` at the repository root (the main project captures them) and are copied into
 * `src/assets/shots/` by `scripts/sync-shots.mjs` before every build. To swap or add a picture: drop the file in
 * `docs/images/` with the name below and rebuild. A picture that does not exist yet renders as a marked placeholder
 * frame, never as a fake screenshot.
 */
export interface Shot {
  /** File name in docs/images, with the extension. The site is dark, so the dark variants are used (light ones exist too). */
  file: string;
  alt: string;
  /** Used only for the placeholder frame, so the page does not shift when the real picture arrives. */
  ratio: [number, number];
  /** What the finished picture should show, printed inside the placeholder. */
  brief: string;
}

export const shots = {
  overview: {
    file: 'overview-dark.webp',
    alt: 'The Cursorlight settings window on the Look page: the Aura highlight with its color, size and intensity, and a live preview over a code editor. The scene strip along the bottom shows Stream, Meeting and Recording.',
    ratio: [2360, 1480],
    brief: 'Settings window, Look page, dark',
  },
  styles: {
    file: 'styles-dark.webp',
    alt: 'The six highlight styles on the same slide: Aura, Lens, Comet, Keyline, Sonar and Crosshair.',
    ratio: [3323, 1610],
    brief: 'The six highlight styles side by side',
  },
  draw: {
    file: 'draw-dark.webp',
    alt: 'The Draw page of Cursorlight with the pen tools, and a rough hand-drawn loop around a line of code being cleaned into an ellipse.',
    ratio: [2360, 1480],
    brief: 'Draw page with a snapped shape',
  },
  popover: {
    file: 'popover-dark.webp',
    alt: 'The Cursorlight menu bar popover with the Highlight, Laser, Ink and Spotlight switches, the scenes, a color row, a size slider and the share-safe reminder.',
    ratio: [772, 1302],
    brief: 'Menu bar popover, dark',
  },
  welcome: {
    file: 'welcome.webp',
    alt: 'The Cursorlight welcome guide: an intro card, a note on picking the entire screen when sharing, and floating prompts that ask you to press the laser shortcut and to draw something.',
    ratio: [2520, 1024],
    brief: 'Welcome guide',
  },
  scenes: {
    file: 'apps-dark.webp',
    alt: 'The Apps page of Cursorlight: a scene for everywhere else, rules by app category such as video calls, code and terminals, browsers and slide decks, and the scene strip with Stream, Meeting and Recording.',
    ratio: [2360, 1480],
    brief: 'Apps page, per-app and per-category scene rules',
  },
  skins: {
    file: 'skins-dark.webp',
    alt: 'The pointer skins gallery: system, classic, dart, bolt, ring, target, star, heart and ghost, with color and size controls.',
    ratio: [1520, 424],
    brief: 'Pointer skins gallery',
  },
  keys: {
    file: 'keys-dark.webp',
    alt: 'The Keys page of Cursorlight: shake to find the pointer, double-tap a key, hold a key, and the global shortcuts for highlight and laser.',
    ratio: [2360, 1480],
    brief: 'Keys page, triggers and shortcuts',
  },
  screens: {
    file: 'screens-dark.webp',
    alt: 'The Screens page of Cursorlight: which display shows effects, the floating bar, hiding the bar from screen sharing, and the sharing reminder that says viewers can see your effects when you share the whole screen.',
    ratio: [2360, 1480],
    brief: 'Screens page with the sharing reminder',
  },
  about: {
    file: 'about-dark.webp',
    alt: 'The About page of Cursorlight stating no accounts and no analytics, Screen Recording not needed, Accessibility not used and Input Monitoring optional.',
    ratio: [2360, 1480],
    brief: 'About page, privacy statements',
  },
} as const satisfies Record<string, Shot>;

export type ShotId = keyof typeof shots;

/** Resolved at build time: every image that exists in src/assets/shots, keyed by file name. */
const found = import.meta.glob<{ default: ImageMetadata }>('../assets/shots/*.{png,jpg,jpeg,webp,avif}', { eager: true });

export function shotImage(id: ShotId): ImageMetadata | undefined {
  const key = Object.keys(found).find((path) => path.endsWith(`/${shots[id].file}`));
  return key ? found[key]?.default : undefined;
}
