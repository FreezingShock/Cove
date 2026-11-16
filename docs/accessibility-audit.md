# v1 accessibility and QA audit

Date: 2026-11-16. Branch: `integration`, plus the PR that added this file.
Scope: the Inlet app (SwiftUI and AppKit code, read by hand) and the website (axe-core plus a read of the markup, CSS and JS).

This was a code audit. Nothing here was run on a Mac, so the items in the last section still need hands-on testing.

## Fixed in this PR

**App**

- **Category bar was unreadable in Light mode.** It used the v0.1 `Theme` colors: white labels and a white pill on light glass. Measured contrast of the white label on the Light base was 1.19:1. It now uses the `InletColor` and `InletText` tokens, and it uses the shared capsule glass, so Reduce Transparency applies. Deleted the unused `Theme.swift`.
- **Track token below 3:1.** Light `track` was `rgba(12,22,44,0.46)`, which measured 2.94:1 on the base (WCAG 1.4.11 asks for 3:1). It is now `0.50`, which measures 3.3:1. The same change is in `website/css/tokens.css`. **The design-system source `cove-tokens.css` (in project files) needs the same value.**
- **Reduce Motion ignored in three places.** The Edit toggle, the Hidden apps panel, and the Undo toast called `withAnimation` with spring curves directly. They now crossfade for 0.2 s. The Hidden panel and the Undo toast use an opacity-only transition under Reduce Motion. The category selection also crossfades now.
- **Reorder and hide had no keyboard or VoiceOver path.** In Edit mode, Option + arrow moves the focused icon. Delete hides it, and focus moves to the next icon. VoiceOver gets Move earlier and Move later actions on each icon.
- **Undo toast was silent for VoiceOver.** It now posts an announcement when an app is hidden.
- **Page dots were 22 pt.** They are 24 pt now, which meets the WCAG 2.2 target-size minimum (2.5.8).
- **Smaller fixes.** The search magnifier is hidden from VoiceOver because it is decorative. The Inlet wordmark is a heading. The category bar is a labeled group.

**Website**

- Added a skip link on all three pages, and an `id="main"` target on each `<main>`.
- The demo stages had `aria-label` on a plain `div`, which screen readers ignore. They are `role="region"` now. The chip row, the requirements row and the dock sample are groups.
- The dock toggle has `aria-controls="qpWrap"`.
- Fact headings went from h4 to h3, so the heading order no longer skips a level.

## Checked and passing

axe-core 4.10 with the WCAG 2.0 A/AA, 2.1 A/AA and 2.2 AA tags. Run on index, privacy and support, in Light and Dark. **0 violations before the fixes and 0 after.** axe does not catch the `aria-label` misuse or the heading order, which is why the fixes above were needed.

Contrast, computed from the tokens:

| Pair | Ratio | Result |
|---|---|---|
| Light text-2 on base | 5.32:1 | Pass |
| Light text-3 on base | 4.68:1 | Pass, thin margin. Hints only |
| Light accent-ink (white) on accent | 4.88:1 | Pass |
| Light accent focus ring on base | 4.10:1 | Pass (3:1 needed) |
| Light track on base, before | 2.94:1 | Fail, fixed to 3.30:1 |
| Dark text-3 on base | 5.80:1 | Pass |
| Dark text-2 on base | 10.70:1 | Pass |
| Dark accent on base | 11.50:1 | Pass |
| Dark track on base | 3.73:1 | Pass |

Also checked in the code: Reduce Motion and Reduce Transparency are read in the grid tiles, the icon cells, the quick panel, the search surface and the overlay. Increase Contrast switches the faint text roles to full text. The overlay closes on Escape (clearing the search first) and on an outside click.

## Open, not changed

1. **Overlay open time under 100 ms (T2.4, T1.3).** No Mac here, so this is unmeasured. The `Hotkey to visible` signpost is in place. Follow `PERFORMANCE.md` to measure it in Instruments. CI can't measure a real hotkey press.
2. **Drag reorder is in the code, but the v1 spec puts drag reorder in Later.** Keyboard and VoiceOver reorder now work. Decide whether drag stays in v1.
3. **Website Settings demo claims a "Category bar on or off" setting.** The v1 Settings list in the spec (Q9) leaves that out. The demo copy is still wrong for v1. Not changed here because it's a product decision.
4. **Onboarding was not audited in depth.** Its shortcut practice steps and recorder are a separate pass.
5. **Focus visibility under Full Keyboard Access.** The plain-style buttons (category bar, page dots) may not show a focus ring until someone tests it.

## Needs hands-on Mac testing

- VoiceOver on macOS 26: open the grid, search, arrow through results, Return to open, Edit mode, the Move earlier/later and Hide actions, and the Undo announcement.
- Keyboard only: Option Space, type, Down, arrows, Return, Escape (clears, then closes), Tab into Edit, Hidden and Undo, and reorder with Option + arrow.
- Light, Dark, Increase Contrast, Reduce Motion and Reduce Transparency, one at a time, screenshot at 2x. Check the category bar in Light mode in particular.
- Overlay open latency: 20 presses in Instruments, median under 100 ms (see `PERFORMANCE.md`).
- Website after deploy: rerun the axe check on the live URL, and check the skip link and focus order with the keyboard.
