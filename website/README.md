# Inlet landing page

A static, one-page site for Inlet. It has no build step and no dependencies. Open it locally to preview it before it is published.

## Run it on Windows

1. Install Node.js (LTS) from https://nodejs.org. Accept the defaults.
2. Open PowerShell in the repository folder and run:

   ```powershell
   cd website
   npx serve .
   ```

3. Open http://localhost:3000 in your browser. If port 3000 is taken, `serve` prints the port it picked.

You can also double-click `index.html` to open it straight from the folder. It works that way too, because the page uses no modules and no network requests.

## Files

- `index.html` is the page and its markup.
- `css/tokens.css` is generated. Edit `design/tokens.json` at the repo root, then run `python3 scripts/build-tokens.py`. Do not hand-edit the generated block. CI runs the script with `--check`.
- `css/type.css` loads the self-hosted Figtree face and sets the type roles. Its scale comes from `design/tokens.json` under `type`.
- `css/site.css` holds the page styles.
- `css/motion.css` holds the scroll and motion styles: the sticky header, reveal on scroll, parallax on stages, and the pinned demo. Each rule either works without JavaScript or is off under `prefers-reduced-motion`.
- `js/site.js` runs the demos: the grid, search, quick panel, settings, and spring motion. It has no dependencies.
- `js/scroll.js` runs the scroll behavior: header state, reveal, the section highlight in the nav, focus on anchor jumps, and the pinned demo, where the video scrubs with scroll. The pin turns on only when motion is allowed and the section fits in the window.
- `404.html` is the page for a missing address. GitHub Pages serves it for any unknown path. It is `noindex`.
- `changelog.html` has the roadmap and the release notes. The notes sit between the `release-notes:start` and `release-notes:end` markers. `scripts/release/render-changelog.py` fills them from the published GitHub Releases when the site is built, so the page never calls the API in a visitor's browser. With no release it shows the empty state. Styles are in `css/changelog.css`.
- `robots.txt`, `sitemap.xml` and `site.webmanifest` sit at the site root. The sitemap lists every indexable page. Keep it in step when you add a page.
- `favicon.ico` and `apple-touch-icon.png` are at the root. `assets/icons/` holds the 16, 32, 192 and 512 px PNGs for the browser tab and the web app manifest.
- `assets/` holds the Inlet app icon as SVG and PNG.
- `assets/launch/` holds the launch images: the demo video and its poster, stills of the grid, search and quick panel, and the 1200 x 630 link-preview card. They are drawn by `scripts/launch-assets/capture.cjs` from a macOS-style desktop scene (`scripts/launch-assets/mac-scene.html`): an original wallpaper, menu bar, Dock, glass panels and a cursor. They are not captured from the Mac app, and the scene uses no Apple wallpapers or app icons.

## Images and video

- The three app screenshots on `features.html` are `<picture>` elements. Each one offers AVIF, then WebP, then the original WebP, at several widths. The browser picks the smallest good file.
- Run `node scripts/build-website-assets.mjs` after you change a source image or the app icon. It rebuilds the variants, the favicon set and the icons. It needs `sharp` (see the comment at the top of the script).
- The demo video is H.264 with a keyframe every 10 frames, so the scroll-scrubbed demo can seek smoothly. It is 0.70 MB, 1280 x 800, 8.2 s at 30 fps. It is encoded with `ffmpeg -c:v libx264 -preset slow -crf 26 -tune animation -g 10 -keyint_min 10 -pix_fmt yuv420p -movflags +faststart -an`, run by `capture.cjs`. Keep the keyframe interval when you re-encode, or scrubbing will stutter.
- The video loads when the demo section gets close to the screen, not on page load.

## Checks

- `python3 scripts/check-website.py website` checks links, anchors, the no-external-requests promise, image attributes, the SEO tags and JSON-LD, the sitemap, robots.txt, the manifest and the icons.
- `lighthouserc.json` sets the Lighthouse budget. The Website workflow runs it on every page (desktop preset, median of three runs). Accessibility, best practices and SEO must score 100. Performance must score at least 97.

## Notes

- The site sets its type in Figtree, self-hosted from `fonts/figtree-latin-wght.woff2` (OFL). It looks the same on every system. The app itself keeps SF Pro.
- The site has no analytics, no tracking, and no external requests. The font and every other asset are local.
- The "Appearance" control on the page is for this demo only. It saves to the browser's local storage and does not change the app.
