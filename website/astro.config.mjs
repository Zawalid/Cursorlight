// @ts-check
import { defineConfig } from 'astro/config';
import { DOMAIN } from './site.config.mjs';

export default defineConfig({
  site: `https://${DOMAIN}`,
  output: 'static',
  trailingSlash: 'ignore',
  build: { inlineStylesheets: 'auto' },
});
