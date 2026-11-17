# Inlet brand

One cream, one ink, one aqua. Everything else is a shape, a word or a motion built from those three.

The model is the Grid icon. It is one aqua tile among ink tiles. The brand takes that single lit tile and repeats it as a divider, a highlight, and a band of moving words.

## Color

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| Cream (base) | `#F4EFE6` | `#101211` ink ground | Page ground. The only neutral. |
| Paper | `#FBF8F2` | cream at 5% | Raised surfaces, rarely needed |
| Ink (text) | `#17150F` | `#F4EFE6` | All text, all icons, the band |
| Aqua (accent) | `#46E6D6` | `#46E6D6` | The one accent. Fills only. |
| Ink tile | ink at 10% | cream at 12% | Unlit tiles, placeholders |
| Hairline | ink at 13% | cream at 12% | Borders and dividers |

Rules:
- Aqua is a fill, never text. Aqua on cream is a 1.3:1 contrast, so it can't carry a label.
- Ink sits on aqua for every label. Ink on aqua is about 12:1.
- Text stays at 4.5:1 or better on its surface. The check is in `scripts/check-website.py` and the token build.
- There are no secondary hues. The old lilac, citrus, sage and clay tints and the glow colors are gone. Glows are aqua at low alpha.
- Source of truth is `design/tokens.json`, the `color` section. `python3 scripts/build-tokens.py` writes the CSS and the Swift `InletColor` values.

## Type

- **Website:** Figtree, self-hosted (`website/fonts/figtree-latin-wght.woff2`, OFL). Display is bold, tight tracking (-0.035em). Labels are 600 in caps, tracked 0.06em.
- **App:** SF Pro through `Font.system`. The app keeps the Apple face so it matches the system.
- Type scale is in `design/tokens.json` under `type`. Use role names, not raw sizes.

## Motifs

1. **The lit tile.** One aqua square in a row of ink squares. It is the divider between sections (`.tile-rule`). On scroll it slides into place. Under reduced motion it sits at its final position.
2. **The highlight.** One word per headline gets an aqua underline block (`.hl`). Use one per headline, and only on the key phrase.
3. **The band.** A full-bleed ink strip with the product's verbs moving across it (`.lit-band`). It sits under the hero and at the top of the features page. It pauses on hover. Reduced motion stops it and hides the duplicate line.
4. **The eyebrow.** A small aqua square before a section label. It marks the label, not the heading.
5. **The closing panel.** The one full aqua block on the site, with ink type and an ink primary button. It appears once per page at most.

## Buttons

- **Primary:** aqua fill, ink label, pill. Hover moves to `accent-hover`, press to `accent-pressed`.
- **Secondary:** field fill with a hairline, ink label.
- **On the aqua panel:** the primary inverts to an ink pill with an aqua label.
- Minimum 44 px high on touch. Focus ring is 2 px ink with 3 px offset. Aqua is never the focus ring on cream, since it is too faint there.

## Motion

- Use the existing spring and duration tokens (`design/tokens.json`, `motion`). No new easing curves.
- Motifs animate only when `prefers-reduced-motion: no-preference`. Every motif has a static fallback: the lit tile sits in place, the band stops, the highlight is always shown.
- The lit-tile slide uses scroll-linked `animation-timeline: view()` only where supported. Other browsers show it in its final position.

## Imagery

- **App icon:** the Grid icon, unchanged. Its aqua tile is the brand's accent.
- **Social and link preview:** `website/assets/launch/og-image.png`, rendered from `scripts/launch-assets/og.html`. Cream ground, ink type, the band along the bottom.
- **Brand board:** `docs/brand/brand-board.png`, rendered from `docs/brand/brand-board.html`. It is the one-page reference.
- **Screenshots and feature art** show the real app. They are not recolored. The app's own accent is aqua now, so new captures will match.

## Do

- Use ink for every word. Use aqua for one fill per screen.
- Keep the lit tile to one per row. More than one stops reading as a signal.
- Let the band say what the product does, in short verbs.
- Check dark mode with the same aqua.

## Don't

- Don't add a second accent, gradient or tint. Don't use aqua text or aqua body copy.
- Don't put aqua behind ink text smaller than the headline size without checking it reads.
- Don't use the band for body copy, or animate it under reduced motion.
- Don't recolor the app icon.
- Don't use stock photography or app-store style device frames in brand imagery.

## Where it lives

| Piece | File |
| --- | --- |
| Color tokens | `design/tokens.json`, generated into `website/css/tokens.css` and `Inlet/InletTheme.swift` |
| Brand motifs | `website/css/brand.css` |
| Brand board | `docs/brand/brand-board.html` and `.png` |
| OG card | `scripts/launch-assets/og.html` and `website/assets/launch/og-image.png` |
| This guide | `docs/brand.md` |
