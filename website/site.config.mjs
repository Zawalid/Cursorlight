// The one place that names the domain and the repository. Everything else (Astro config, robots.txt, sitemap, canonical
// links, share images, the check scripts) reads it from here. Both values are UNCONFIRMED:
//   - the domain follows Lopper's pattern (lopper.zawalid.com);
//   - the repository is the name the release scripts assume.
// wrangler.jsonc cannot import this file, so its "routes" pattern must be changed by hand to the same host.
export const DOMAIN = 'cursorlight.zawalid.com';
export const REPO = 'Zawalid/Cursorlight';
