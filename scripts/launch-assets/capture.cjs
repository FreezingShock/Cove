#!/usr/bin/env node
// Renders the Inlet launch assets from the website's own demo UI.
//
// Outputs (written to website/assets/launch/):
//   grid.webp, search.webp, quick-panel.webp   stills of each demo stage, 2x
//   inlet-demo.mp4, inlet-demo-poster.webp    short looping demo: grid opens, search, launch
//   og-image.png                              1200 x 630 link-preview card (see og.html)
//
// This is NOT a capture of the macOS app. It drives the demo on website/index.html,
// which uses the same tokens (website/css/tokens.css) as the app design, in headless
// Chromium on Linux. Swap these for real macOS screenshots once the app is tested on a Mac.
//
// Requirements: Node 18+, the `playwright` package with a Chromium build,
// ffmpeg with libx264 and libwebp, and ImageMagick's `convert` (used for og-image checks only).
//
// Usage:
//   WORK_DIR=/some/scratch/dir node scripts/launch-assets/capture.cjs
//
// WORK_DIR holds raw recordings and intermediate PNGs. It is not published.

const { chromium } = require('playwright');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..');
const SITE = path.join(ROOT, 'website');
const OUT = path.join(SITE, 'assets', 'launch');
const WORK = process.env.WORK_DIR || path.join(__dirname, 'work');
const PAGE_URL = 'file://' + path.join(SITE, 'index.html');
const OG_URL = 'file://' + path.join(__dirname, 'og.html');
const THEME = 'dark';

// Capture-only styling. Hides the sticky header and sets a font that is close to SF Pro
// (Inter is installed here; SF Pro is not available on Linux). The site itself is unchanged.
const CAPTURE_CSS = `
  .nav { display: none !important; }
  body, body * { font-family: Inter, -apple-system, "Helvetica Neue", Arial, sans-serif !important; }
`;

const seenExternal = new Set();

async function openPage(browser, { viewport, dsf, recordDir } = {}) {
  const context = await browser.newContext({
    viewport: viewport || { width: 1200, height: 900 },
    deviceScaleFactor: dsf || 2,
    colorScheme: 'dark',
    reducedMotion: 'no-preference',
    ...(recordDir ? { recordVideo: { dir: recordDir, size: { width: 1200, height: 900 } } } : {}),
  });
  await context.addInitScript((theme) => {
    try { localStorage.setItem('inlet-page-theme', theme); } catch (e) { /* storage blocked */ }
  }, THEME);
  // Fail loudly if the page ever reaches the network. The site promises no external requests.
  await context.route(/^https?:\/\//, (route) => {
    seenExternal.add(route.request().url());
    return route.abort();
  });
  const page = await context.newPage();
  await page.goto(PAGE_URL, { waitUntil: 'load' });
  await page.addStyleTag({ content: CAPTURE_CSS });
  return { context, page };
}

async function typeSlowly(locator, text, delay) {
  if (locator.pressSequentially) await locator.pressSequentially(text, { delay });
  else await locator.type(text, { delay });
}

async function stills(browser) {
  const { context, page } = await openPage(browser);

  const hero = page.locator('#heroStage');
  await hero.scrollIntoViewIfNeeded();
  await page.waitForTimeout(2400); // grid opens, springs settle
  await hero.screenshot({ path: path.join(WORK, 'grid.png') });

  const q = page.locator('#q');
  await q.click();
  await typeSlowly(q, 'note', 60);
  await q.blur();
  await page.waitForTimeout(1200);
  await page.locator('.search-stage').screenshot({ path: path.join(WORK, 'search.png') });

  const qp = page.locator('.qp-stage');
  await qp.scrollIntoViewIfNeeded();
  await page.waitForTimeout(900);
  await qp.screenshot({ path: path.join(WORK, 'quick-panel.png') });

  await context.close();
}

// Clip 1: the grid opens from the centre (replay button, so the open is always in the take).
async function heroClip(browser) {
  const dir = path.join(WORK, 'clip-hero');
  fs.mkdirSync(dir, { recursive: true });
  const { context, page } = await openPage(browser, { dsf: 1, recordDir: dir });
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(700);
  const box = await page.locator('#heroStage').boundingBox();
  await page.click('#replayBtn');
  await page.waitForTimeout(3000);
  const video = page.video();
  await context.close();
  return { file: await video.path(), box };
}

// Clip 2: type "note", then "pho", then Return launches the top hit.
async function searchClip(browser) {
  const dir = path.join(WORK, 'clip-search');
  fs.mkdirSync(dir, { recursive: true });
  const { context, page } = await openPage(browser, { dsf: 1, recordDir: dir });
  const stage = page.locator('.search-stage');
  await stage.evaluate((el) => el.scrollIntoView({ block: 'start', behavior: 'instant' }));
  await page.waitForTimeout(900);
  const box = await stage.boundingBox();

  const q = page.locator('#q');
  await q.click();
  await page.waitForTimeout(400);
  await typeSlowly(q, 'note', 170);
  await page.waitForTimeout(1500);
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.waitForTimeout(350);
  await typeSlowly(q, 'pho', 170);
  await page.waitForTimeout(1300);
  await page.keyboard.press('Enter'); // runs the top hit's press bounce
  await page.waitForTimeout(1300);
  const video = page.video();
  await context.close();
  return { file: await video.path(), box };
}

function ffprobeSize(file) {
  const out = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height', '-of', 'csv=p=0:s=x', file]).toString().trim();
  const [w, h] = out.split('x').map(Number);
  return { w, h };
}

function ffmpeg(args) {
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'inherit' });
}

// Turn a raw recording into a cropped, even-sized clip. The take is recorded at 1x, so
// boundingBox CSS pixels map straight onto it. The crop is then upscaled to 2x width with
// lanczos for retina. Trim is in seconds from the start of the take.
const OUT_WIDTH = 1040;
function cropClip(raw, box, { trim, dur }, outFile) {
  const x = Math.round(box.x) & ~1;
  const y = Math.round(box.y) & ~1;
  const w = Math.round(box.width) & ~1;
  const h = Math.round(box.height) & ~1;
  const outH = Math.round((h * OUT_WIDTH) / w) & ~1;
  ffmpeg(['-ss', String(trim), '-i', raw, '-t', String(dur),
    '-vf', `crop=${w}:${h}:${x}:${y},scale=${OUT_WIDTH}:${outH}:flags=lanczos,fps=30`,
    '-an', '-c:v', 'libx264', '-preset', 'slow', '-crf', '22', '-pix_fmt', 'yuv420p', outFile]);
  return { w: OUT_WIDTH, h: outH };
}

function toWebp(png, webp, quality = 86) {
  ffmpeg(['-i', png, '-c:v', 'libwebp', '-quality', String(quality), '-compression_level', '6', webp]);
}

(async () => {
  fs.mkdirSync(WORK, { recursive: true });
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch();
  try {
    await stills(browser);

    const hero = await heroClip(browser);
    const search = await searchClip(browser);

    // Clip files, then one size that fits both (the two stages are not the same shape).
    const heroMp4 = path.join(WORK, 'hero.mp4');
    const searchMp4 = path.join(WORK, 'search.mp4');
    const heroSize = cropClip(hero.file, hero.box, { trim: 0.6, dur: 3.1 }, heroMp4);
    const searchSize = cropClip(search.file, search.box, { trim: 0.6, dur: 6.9 }, searchMp4);

    const W = Math.max(heroSize.w, searchSize.w);
    const H = Math.max(heroSize.h, searchSize.h);
    const pad = `pad=${W}:${H}:(${W}-iw)/2:(${H}-ih)/2:color=0x05070C,setsar=1`;
    const demo = path.join(OUT, 'inlet-demo.mp4');
    ffmpeg(['-i', heroMp4, '-i', searchMp4, '-filter_complex',
      `[0:v]${pad}[a];[1:v]${pad}[b];[a][b]concat=n=2:v=1:a=0[v]`,
      '-map', '[v]', '-c:v', 'libx264', '-preset', 'slow', '-crf', '24',
      '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', demo]);

    // Poster: the grid fully open, taken from the finished demo.
    const posterPng = path.join(WORK, 'poster.png');
    ffmpeg(['-ss', '2.4', '-i', demo, '-frames:v', '1', posterPng]);
    toWebp(posterPng, path.join(OUT, 'inlet-demo-poster.webp'));

    // Stills.
    toWebp(path.join(WORK, 'grid.png'), path.join(OUT, 'grid.webp'));
    toWebp(path.join(WORK, 'search.png'), path.join(OUT, 'search.webp'));
    toWebp(path.join(WORK, 'quick-panel.png'), path.join(OUT, 'quick-panel.webp'));

    // Link-preview card. Renders og.html at 1200 x 630.
    const ogCtx = await browser.newContext({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
    const ogPage = await ogCtx.newPage();
    await ogPage.route(/^https?:\/\//, (route) => { seenExternal.add(route.request().url()); return route.abort(); });
    await ogPage.goto(OG_URL, { waitUntil: 'load' });
    await ogPage.evaluate(() => document.fonts && document.fonts.ready);
    await ogPage.screenshot({ path: path.join(OUT, 'og-image.png') });
    await ogCtx.close();
  } finally {
    await browser.close();
  }

  if (seenExternal.size) {
    console.error('External requests were attempted:\n' + [...seenExternal].join('\n'));
    process.exit(1);
  }
  console.log('Launch assets written to ' + OUT);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
