// Cuts the macro crops the page uses out of the lossless captures in src/assets/shots (copied there by sync-shots).
// Definitions live in src/data/crop-defs.json so the page and this script agree. Output: src/assets/shots/crops/<id>.webp
import sharp from 'sharp';
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const here = (path) => fileURLToPath(new URL(path, import.meta.url));
const defs = JSON.parse(readFileSync(here('../src/data/crop-defs.json'), 'utf8'));
const outDir = here('../src/assets/shots/crops/');
mkdirSync(outDir, { recursive: true });
let made = 0;
for (const [id, def] of Object.entries(defs)) {
  const source = here(`../src/assets/shots/${def.from}`);
  if (!existsSync(source)) { console.log(`make-crops: ${def.from} missing, skipping ${id}`); continue; }
  const [left, top, width, height] = def.rect;
  await sharp(source).extract({ left, top, width, height }).webp({ quality: 90 }).toFile(`${outDir}${id}.webp`);
  made++;
}
console.log(`make-crops: wrote ${made} crop(s).`);
