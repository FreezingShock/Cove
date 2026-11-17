#!/usr/bin/env node
// Renders the Inlet launch assets from a macOS-style desktop scene.
//
// Outputs (written to website/assets/launch/):
//   inlet-demo.mp4, inlet-demo-poster.webp   8 s looping trailer (grid opens, "pho" typed, Return, Photos opens)
//   grid.webp, search.webp, quick-panel.webp stills of each state, 1280 x 800
//   og-image.png                             1200 x 630 link-preview card (see og.html)
//
// The scene is scripts/launch-assets/mac-scene.html. It is drawn in code: an original wallpaper,
// a menu bar, a Dock, glass materials, window shadows and a cursor. No Apple wallpapers or icons.
// Frames come from a timeline (renderAt(t)), not a screen recording, so every frame is exact.
//
// Requirements: Node 18+, the `playwright` package with a Chromium build, ffmpeg with libx264 and
// libwebp. The page uses the system font stack; on Linux that is Inter, not SF Pro.
//
// Usage (from the repository root):
//   node scripts/launch-assets/capture.cjs
//
// WORK_DIR holds the PNG frames and intermediate files. It defaults to a temp folder and is not published.

const { chromium } = require('playwright');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'website', 'assets', 'launch');
const WORK = process.env.WORK_DIR || path.join(os.tmpdir(), 'inlet-launch');
const SCENE_URL = 'file://' + path.join(__dirname, 'mac-scene.html');
const OG_URL = 'file://' + path.join(__dirname, 'og.html');

const W = 1280;
const H = 800;
const FPS = 30;
const DURATION = 8.2; // matches the timeline in mac-scene.html (last action ends at 7.6 s)
const FRAMES = Math.round(FPS * DURATION);
const DSF = 2; // render at 2x, then scale down with lanczos for crisp text

const seenExternal = new Set();

function ffmpeg(args) {
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'inherit' });
}

function pngToWebp(png, webp, quality = 84) {
  ffmpeg(['-i', png, '-vf', `scale=${W}:${H}:flags=lanczos`, '-c:v', 'libwebp', '-quality', String(quality),
    '-compression_level', '6', webp]);
}

async function openScene(browser, url) {
  const context = await browser.newContext({
    viewport: { width: W, height: H },
    deviceScaleFactor: DSF,
    colorScheme: 'dark',
    reducedMotion: 'reduce',
  });
  // The site promises no external requests, so fail loudly if the scene reaches the network.
  await context.route(/^https?:\/\//, (route) => {
    seenExternal.add(route.request().url());
    return route.abort();
  });
  const page = await context.newPage();
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForFunction('window.ready === true');
  return { context, page };
}

async function renderStills(browser) {
  const { context, page } = await openScene(browser, SCENE_URL);
  for (const name of ['grid', 'search', 'quick']) {
    await page.evaluate((n) => window.renderPreset(n), name);
    const png = path.join(WORK, `${name}.png`);
    await page.screenshot({ path: png });
    const target = name === 'quick' ? 'quick-panel' : name;
    pngToWebp(png, path.join(OUT, `${target}.webp`));
  }
  await context.close();
}

async function renderVideo(browser) {
  const dir = path.join(WORK, 'frames');
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  const { context, page } = await openScene(browser, SCENE_URL);
  for (let i = 0; i < FRAMES; i++) {
    const t = i / FPS;
    await page.evaluate((tt) => window.renderAt(tt), t);
    await page.screenshot({ path: path.join(dir, `f${String(i).padStart(4, '0')}.png`) });
  }
  await context.close();

  const demo = path.join(OUT, 'inlet-demo.mp4');
  ffmpeg(['-framerate', String(FPS), '-i', path.join(dir, 'f%04d.png'),
    '-vf', `scale=${W}:${H}:flags=lanczos,format=yuv420p`,
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '26', '-tune', 'animation',
    '-g', '10', '-keyint_min', '10', // short GOP so the pinned scroll-scrub can seek
    '-movflags', '+faststart', '-an', demo]);

  // Poster: the grid fully open, the same frame as the grid still.
  const posterPng = path.join(WORK, 'poster.png');
  ffmpeg(['-i', path.join(dir, 'f0030.png'), '-frames:v', '1', posterPng]);
  pngToWebp(posterPng, path.join(OUT, 'inlet-demo-poster.webp'));
}

async function renderOg(browser) {
  const ctx = await browser.newContext({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  await page.route(/^https?:\/\//, (route) => { seenExternal.add(route.request().url()); return route.abort(); });
  await page.goto(OG_URL, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts && document.fonts.ready);
  await page.screenshot({ path: path.join(OUT, 'og-image.png') });
  await ctx.close();
}

(async () => {
  fs.mkdirSync(WORK, { recursive: true });
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch();
  try {
    await renderStills(browser);
    await renderVideo(browser);
    await renderOg(browser);
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
