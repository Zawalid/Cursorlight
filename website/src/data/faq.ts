import { links, site } from './site';

export interface Faq { q: string; a: string; }

/** Plain text answers: the same strings feed the page and the FAQPage structured data, so they cannot disagree. */
export const faq: Faq[] = [
  {
    q: 'Why can viewers not see my highlight when I share one window?',
    a: 'Cursorlight draws on your display, on top of your apps. When you share the whole screen, the display is what viewers get, so they see it. When you share a single window, macOS sends only that window, and nothing drawn on top of it is included. In our own capture test, whole-display capture showed an overlay and single-window capture did not. We have not tested every conferencing app, so check yours with the share-safe reminder in the app.',
  },
  {
    q: 'Does it need Screen Recording or Accessibility?',
    a: 'No. Cursorlight does not use Accessibility and does not record your screen, so it never asks for either. The only permission it can ask for is Input Monitoring, and only if you turn on a feature that listens to the keyboard.',
  },
  {
    q: 'What is Input Monitoring for?',
    a: 'It is optional. It powers the keystroke display, triggers that need you to double-tap and hold a key, the key sound and hiding while you type. Shake, the shortcuts, the laser, ink and spotlight work without it. Password fields are never seen: the system withholds those keys.',
  },
  {
    q: 'Why does macOS say it cannot verify Cursorlight?',
    a: 'This build is not notarized yet, because there is no Apple Developer account behind the project. macOS blocks the first launch of any such app until you confirm it once. The install steps above show how, on macOS 15 and later and on macOS 14. The source is public, so you can read it or build it yourself.',
  },
  {
    q: 'Which Macs does it run on?',
    a: `macOS ${site.minimumMacOS} or later, on Apple silicon and Intel. It is a universal app.`,
  },
  {
    q: 'Does it replace my real cursor?',
    a: 'Only if you choose a pointer skin, and it goes back to normal when Cursorlight is paused or quits. By default the effects are drawn around your normal pointer. Cursorlight can also change the system cursor size, and it puts it back when you quit and after a crash.',
  },
  {
    q: 'Can I control it from a Stream Deck, Raycast or Shortcuts?',
    a: 'Yes. Turn on cursorlight:// links in settings, then use a link such as cursorlight://scene?name=Meeting from Stream Deck, Raycast, Alfred, the Shortcuts app (Open URLs) or Terminal. Links only switch Cursorlight\'s own effects, and nothing is read back.',
  },
  {
    q: 'Is it free? What is the catch?',
    a: `It is free and open source under the MIT licence, with no account, no licence key and no analytics. The name, icon and artwork are not covered by the licence. The code is at ${links.repo}.`,
  },
  {
    q: 'Does it phone home?',
    a: 'No. The only network call it can make is an update check, and that is optional. There is no analytics and no account. This website counts visits with Cloudflare Web Analytics, which sets no cookies and collects nothing from visitors in the EU.',
  },
];
