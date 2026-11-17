#!/usr/bin/env node
// Renders the drawn README cards (install, groups, edit, keys, settings, privacy, supporter)
// from illustrations.html into docs/readme/. Usage (repo root): node scripts/readme-art/build-illustrations.cjs
const { chromium } = require('playwright');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'docs', 'readme');
const FILES = { install: 'feature-install.png', groups: 'feature-groups.png', edit: 'feature-edit.png', keys: 'feature-keys.png',
  settings: 'feature-settings.png', privacy: 'feature-privacy.png', supporter: 'supporter.png' };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox'] });
  const page = await (await browser.newContext({ viewport: { width: 2400, height: 1350 }, deviceScaleFactor: 1, colorScheme: 'light' })).newPage();
  await page.goto('file://' + path.join(__dirname, 'illustrations.html'), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  for (const [id, file] of Object.entries(FILES)) {
    await page.locator('#' + id).screenshot({ path: path.join(OUT, file) });
    console.log('wrote', file);
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
