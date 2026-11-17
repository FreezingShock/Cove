# Appearance audit: dark mode and accent

Date: 2026-11-17. Scope: every macOS app surface (grid, search, groups, folders, quick panel, Settings, onboarding, feedback, menus) in Light and Dark, checked against `design/tokens.json`.

Code audit only. Nothing here was run on a Mac. CI builds and tests the app on macOS, but it can't see colors. The Mac checklist at the end still needs doing.

## What was wrong

- **Aqua used as a ring or state on cream.** Aqua on cream is 1.35:1. Focus rings, drop targets, the current page dot and onboarding progress were aqua, so they were nearly invisible in Light. They now use the `focus` token: ink in Light, aqua in Dark.
- **Aqua used as text.** The calculator row's `=` was aqua text on a soft aqua disc. It is ink now, and the aqua stays on the disc.
- **Two accents.** The system accent (`AccentColor` in the asset catalog) was teal `#0A7F74` / `#3FD9C9`. Toggles, sidebar selection and prominent buttons used it, while the app's own controls used aqua. `AccentColor` is now ink in Light and aqua in Dark.
- **Track below 3:1 in Light.** `track` was `rgba(23,21,15,0.45)` and measured 2.89:1 on the base. It is 0.50 now, which measures 3.34:1 (WCAG 1.4.11).
- **Quick panel ignored Light/Dark.** The Appearance setting only reached the grid and Settings. The quick panel now applies it.
- **Feedback forced Dark.** It follows the setting now.
- **Red was a fixed color.** The armed Delete chip used `Color.red`. It uses `systemRed`, which adapts.

## Contrast, computed from design/tokens.json

Run after the changes. Translucent colors are composited over the base first.

| Pair | Light | Dark | Need |
|---|---|---|---|
| text on base | 15.94 | 16.42 | 4.5 |
| text-2 on base | 7.81 | 10.18 | 4.5 |
| text-3 on base | 5.19 | 6.41 | 4.5 |
| text-2 on grouped | 8.16 | 9.41 | 4.5 |
| text-3 on grouped | 5.35 | 6.10 | 4.5 |
| focus on base | 15.94 | 12.13 | 3.0 |
| track on base | 3.34 | 3.49 | 3.0 |
| accent-ink on accent (label) | 11.78 | 12.13 | 4.5 |
| text on accent-soft | 14.63 | 11.65 | 4.5 |
| accent on base (fill only, never text) | 1.35 | 12.13 | n/a |

Light aqua is 1.35:1 on cream. That is expected for a fill. Nothing in Light uses aqua as a ring, a marker or text now.

## Left as is, on purpose

- **Settings category tiles and onboarding option tiles** keep their colored SF Symbol tiles, as in System Settings and the v1.2 design spec.
- **Group colors** are user data (`GroupColor`), so they are not touched.
- **The onboarding practice desktop** is a fixed dark stage that stands in for the user's desktop. It is not themed.
- **Supporter themes** still change the accent and background. The focus ring stays ink in Light and aqua in Dark.

## Mac test checklist

Run on macOS 26 with a build from this branch.

1. **Appearance setting.** Settings > Appearance: Light, Dark, Auto. Check the grid, the quick panel, Settings, onboarding and Feedback each follow it. Quit and reopen to confirm it persists.
2. **Focus ring.** Tab through the grid and the category bar in Light and in Dark. The ring must be ink in Light and aqua in Dark, and visible on every tile.
3. **Page dots and onboarding progress.** The current dot and the filled progress bars must be clearly darker or brighter than the track in Light.
4. **Calculator row.** Type `2+2` in search in both themes. The `=` must read clearly.
5. **Settings controls.** Light: toggles, the segmented Appearance picker and the sidebar selection should show ink. Dark: toggles and selection should show aqua.
6. **Sidebar and Feedback in Dark.** The Settings sidebar is now custom rows with an ink label on the glass lozenge, and the Feedback button is `InletAccentButtonStyle` (ink on aqua, about 12:1). Check that the selected row reads in both themes, and that clicking a row still switches the pane.
7. **Delete chip.** Armed delete should be red in both themes, with white text readable.
8. **Supporter themes.** Pick Ember and Harbor. Accent fills follow the theme, and the focus ring stays ink or aqua.
9. **Accessibility toggles.** Increase Contrast and Reduce Transparency, one at a time, in both themes.
10. **Screenshots.** Light and Dark, each at 2x, of the grid, the search results, Settings > Appearance, and the quick panel.
