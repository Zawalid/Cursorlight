// Copies the product screenshots from ../docs/images into src/assets/shots so Astro can optimise them.
// Only the files named in src/data/shots.ts matter; anything else in the folder is ignored by the site.
// A missing folder or file is not an error: the page then shows a clearly marked placeholder frame.
import { cpSync, existsSync, mkdirSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const here = (path) => fileURLToPath(new URL(path, import.meta.url));
const from = here('../../docs/images');
const to = here('../src/assets/shots');
mkdirSync(to, { recursive: true });

if (!existsSync(from)) {
  console.log('sync-shots: ../docs/images does not exist yet, the page will show placeholder frames.');
  process.exit(0);
}
const files = readdirSync(from, { withFileTypes: true }).filter((e) => e.isFile() && /\.(png|jpe?g|webp|avif)$/i.test(e.name)).map((e) => e.name);
for (const file of files) cpSync(`${from}/${file}`, `${to}/${file}`);
console.log(`sync-shots: copied ${files.length} image(s) from docs/images.`);
