#!/usr/bin/env node
// Rebuilds the generated image assets for website/: the AVIF and WebP sizes used by
// <picture> on features.html, the AVIF poster, the favicon set, and the app icons.
// Run it after you replace a source image or the app icon, then commit the output.
//
// Usage (from the repository root):
//   npm install --no-save sharp@0.33.5
//   node scripts/build-website-assets.mjs
//
// Sources: website/assets/launch/*.webp (originals) and website/assets/inlet-icon-light.svg.
// The demo video is encoded separately (see website/README.md, "Images and video").

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "website");
const launch = path.join(root, "assets", "launch");
const iconSvg = fs.readFileSync(path.join(root, "assets", "inlet-icon-light.svg"));

// Each screenshot: the widths made as small variants, plus the full-size original.
const shots = [
  { name: "grid", widths: [480, 720, 960] },
  { name: "search", widths: [480, 720, 960] },
  { name: "quick-panel", widths: [360, 540, 720] },
];

async function buildShots() {
  for (const { name, widths } of shots) {
    const src = path.join(launch, `${name}.webp`);
    for (const w of widths) {
      await sharp(src).resize({ width: w }).avif({ quality: 52, effort: 6 }).toFile(path.join(launch, `${name}-${w}.avif`));
      await sharp(src).resize({ width: w }).webp({ quality: 80, effort: 6 }).toFile(path.join(launch, `${name}-${w}.webp`));
    }
    await sharp(src).avif({ quality: 52, effort: 6 }).toFile(path.join(launch, `${name}.avif`));
  }
  await sharp(path.join(launch, "inlet-demo-poster.webp")).avif({ quality: 55, effort: 6 }).toFile(path.join(launch, "inlet-demo-poster.avif"));
}

function png(size) {
  return sharp(iconSvg, { density: 300 }).resize(size, size).png({ compressionLevel: 9 }).toBuffer();
}

// favicon.ico is an ICO container that holds PNG images (16, 32 and 48 px).
function ico(images) {
  const header = Buffer.alloc(6 + 16 * images.length);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(images.length, 4);
  let offset = header.length;
  images.forEach(({ size, data }, i) => {
    const e = 6 + 16 * i;
    header.writeUInt8(size, e);
    header.writeUInt8(size, e + 1);
    header.writeUInt16LE(1, e + 4);
    header.writeUInt16LE(32, e + 6);
    header.writeUInt32LE(data.length, e + 8);
    header.writeUInt32LE(offset, e + 12);
    offset += data.length;
  });
  return Buffer.concat([header, ...images.map((i) => i.data)]);
}

async function buildIcons() {
  fs.mkdirSync(path.join(root, "assets", "icons"), { recursive: true });
  const sizes = [16, 32, 48, 180, 192, 512];
  const out = Object.fromEntries(await Promise.all(sizes.map(async (s) => [s, await png(s)])));
  fs.writeFileSync(path.join(root, "assets", "icons", "favicon-16.png"), out[16]);
  fs.writeFileSync(path.join(root, "assets", "icons", "favicon-32.png"), out[32]);
  fs.writeFileSync(path.join(root, "assets", "icons", "icon-192.png"), out[192]);
  fs.writeFileSync(path.join(root, "assets", "icons", "icon-512.png"), out[512]);
  fs.writeFileSync(path.join(root, "apple-touch-icon.png"), out[180]);
  fs.writeFileSync(
    path.join(root, "favicon.ico"),
    ico([16, 32, 48].map((size) => ({ size, data: out[size] }))),
  );
}

await buildShots();
await buildIcons();
console.log("website assets rebuilt");
