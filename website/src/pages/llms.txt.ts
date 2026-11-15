import type { APIRoute } from 'astro';
import { links, site, version } from '../data/site';

// A short plain-text guide to the site for language models (the llms.txt convention).
export const GET: APIRoute = () => {
  const lines = [
    `# ${site.name}`,
    '',
    `> ${site.description} A native macOS menu bar app, open source, made by Walid Zakan.`,
    '',
    '## Key facts',
    '',
    `- Tagline: ${site.tagline}`,
    `- Version: ${version}, for macOS ${site.minimumMacOS} or later, Apple silicon and Intel.`,
    '- Price and licence: free, MIT. No account, no analytics.',
    '- Permissions: no Accessibility, no Screen Recording. Input Monitoring is optional, for the keystroke display and hold-a-key triggers only.',
    '- Honest limit: effects are drawn on the display, so viewers see them when you share the whole screen and not when you share a single window.',
    `- Source and downloads: ${links.repo}. Latest release: ${links.releases}.`,
    '',
    '## Pages',
    '',
    `- [Home](${site.url}/): what it does, scenes, what viewers see, install, privacy, FAQ`,
    '',
  ];
  return new Response(lines.join('\n'), { headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
};
