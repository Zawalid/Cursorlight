import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { DOMAIN, REPO } from '../../site.config.mjs';

/**
 * The released version, read from the app's own project file so the site never disagrees with the app. The build runs
 * from the website folder, so the parent folder is tried first.
 */
function readVersion(): string {
  const candidates = [resolve(process.cwd(), '../App/project.yml'), resolve(process.cwd(), 'App/project.yml')];
  for (const file of candidates) {
    try {
      const match = readFileSync(file, 'utf8').match(/MARKETING_VERSION:\s*(\S+)/);
      if (match?.[1]) return match[1];
    } catch {
      // try the next place
    }
  }
  throw new Error('Could not read MARKETING_VERSION from App/project.yml: the site would show the wrong version.');
}

export const version = readVersion();

const repo = `https://github.com/${REPO}`;

export const links = {
  repo,
  releases: `${repo}/releases`,
  download: `${repo}/releases/latest/download/Cursorlight.dmg`,
  changelog: `${repo}/blob/main/CHANGELOG.md`,
  license: `${repo}/blob/main/LICENSE`,
  issues: `${repo}/issues`,
  install: `${repo}/blob/main/docs/install.md`,
  author: 'https://zawalid.com',
  github: 'https://github.com/Zawalid',
};

export const site = {
  name: 'Cursorlight',
  tagline: 'Be seen wherever you point.',
  domain: DOMAIN,
  url: `https://${DOMAIN}`,
  title: 'Cursorlight: find, point and draw with your Mac cursor',
  description:
    'Free, open source Mac menu bar app that makes your cursor easy to follow when you share your screen: shake to find it, laser pointer, fading ink, spotlight.',
  minimumMacOS: '14.6',
  /** The day the page last changed in a way worth telling a search engine about. */
  updated: '2026-11-15',
};
