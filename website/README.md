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
- `css/tokens.css` is a copy of the Inlet design tokens (v1.2) from `design-system/inlet-tokens.css`. Edit the source, then copy it here again.
- `css/site.css` holds the page styles.
- `js/site.js` runs the demos: the grid, search, quick panel, settings, and spring motion. It has no dependencies.
- `assets/` holds the Inlet app icon as SVG and PNG.
- `assets/launch/` holds the launch images: the demo video and its poster, stills of the grid, search and quick panel, and the 1200 x 630 link-preview card. They are rendered from this page's demo UI by `scripts/launch-assets/capture.cjs`, not captured from the Mac app.

## Notes

- The page uses the SF Pro system stack. On Windows it falls back to Segoe UI, so it still looks native there.
- The page has no analytics, no tracking, and no external requests. Fonts are system fonts, and every asset is local.
- The "Appearance" control on the page is for this demo only. It saves to the browser's local storage and does not change the app.
