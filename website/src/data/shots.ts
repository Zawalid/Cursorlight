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
  /** File name in docs/images, with the extension. The site is dark, so the dark variants are used. */
  file: string;
  alt: string;
  /** Used only for the placeholder frame, so the page does not shift when the real picture arrives. */
  ratio: [number, number];
  /** What the finished picture should show, printed inside the placeholder. */
  brief: string;
}

export const shots = {
  overview: {
    file: 'overview-dark.png',
    alt: 'The Cursorlight settings window showing the highlight style, color and size, with a live preview.',
    ratio: [16, 10],
    brief: 'Settings window, overview page, dark',
  },
  popover: {
    file: 'popover-dark.png',
    alt: 'The Cursorlight menu bar popover with the scenes, color, size and tool switches.',
    ratio: [4, 5],
    brief: 'Menu bar popover, dark',
  },
  welcome: {
    file: 'welcome.png',
    alt: 'The Cursorlight welcome guide asking you to try the shake, the laser and the ink.',
    ratio: [16, 10],
    brief: 'Welcome guide, shake step',
  },
  scenes: {
    file: 'scenes-dark.png',
    alt: 'The Scenes page listing Stream, Meeting and Recording with per-app rules.',
    ratio: [16, 10],
    brief: 'Scenes page with rules, dark',
  },
  skins: {
    file: 'pointer-skins-dark.png',
    alt: 'The pointer skins gallery: classic, dart, bolt, ring, target, star, heart and ghost.',
    ratio: [16, 10],
    brief: 'Pointer skins gallery, dark',
  },
} as const satisfies Record<string, Shot>;

export type ShotId = keyof typeof shots;

/** Resolved at build time: every image that exists in src/assets/shots, keyed by file name. */
const found = import.meta.glob<{ default: ImageMetadata }>('../assets/shots/*.{png,jpg,jpeg,webp,avif}', { eager: true });

export function shotImage(id: ShotId): ImageMetadata | undefined {
  const key = Object.keys(found).find((path) => path.endsWith(`/${shots[id].file}`));
  return key ? found[key]?.default : undefined;
}
