#!/usr/bin/env node
// Renders the README feature cards in the Inlet brand (cream ground, ink type, one aqua highlight).
// Scenes come from scripts/launch-assets/capture.cjs frames (WORK_DIR). Run capture.cjs first.
// Usage (repo root): WORK_DIR=<dir with frames> node scripts/readme-art/build.cjs
const { chromium } = require('playwright');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..');
const WORK = process.env.WORK_DIR || path.join(os.tmpdir(), 'inlet-launch');
const OUT = path.join(ROOT, 'docs', 'readme');
const TEMPLATE = 'file://' + path.join(__dirname, 'card.html');

// Each card: the frame to show, the copy, and the output file.
const CARDS = [
  { out: 'feature-grid.png', frame: 'grid', eyebrow: 'Grid', title: 'Every app, <span class="hl">on one page.</span>',
    body: 'Every app on your Mac, in one full-screen grid. Click an icon to open it.' },
  { out: 'feature-search.png', frame: 'search', eyebrow: 'Search', title: 'Search for <span class="hl">anything.</span>',
    body: 'Start typing and the grid narrows down. Return opens the top match.' },
  { out: 'feature-quick.png', frame: 'quick', eyebrow: 'Quick panel', title: 'A quick panel from your <span class="hl">Dock.</span>',
    body: 'Recent apps and files, one click from the Dock.' },
];

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox', '--allow-file-access-from-files'] });
  const page = await (await browser.newContext({ viewport: { width: 2400, height: 1350 }, deviceScaleFactor: 1, colorScheme: 'light' })).newPage();
  for (const c of CARDS) {
    const frame = path.join(WORK, `${c.frame}.png`);
    if (!fs.existsSync(frame)) throw new Error('missing frame: ' + frame);
    await page.goto(TEMPLATE, { waitUntil: 'load' });
    await page.evaluate(({ c, frame }) => {
      document.getElementById('eyebrow').textContent = c.eyebrow;
      document.getElementById('title').innerHTML = c.title;
      document.getElementById('body').textContent = c.body;
      document.getElementById('shot').src = 'file://' + frame;
    }, { c, frame });
    await page.waitForFunction(() => document.getElementById('shot').complete);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, c.out), clip: { x: 0, y: 0, width: 2400, height: 1350 } });
    console.log('wrote', c.out);
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
