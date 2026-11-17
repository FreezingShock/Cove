# Native macOS controls audit

Scope: every custom control in `Inlet/`, read by hand against the native control that
does the same job on macOS 26. Nothing here was run on a Mac from this environment. CI
compiles the app and runs the unit tests. The items in [mac-test-checklist.md](mac-test-checklist.md)
need a person on a Mac.

## Swapped to the system control

| Where | Before | Now |
|---|---|---|
| Groups panel, Add button | Capsule drawn by hand | `.buttonStyle(.glassProminent)`, small, brand accent tint |
| Groups panel, color | Row of nine hand-drawn dots | Pop-up menu (`Picker`, `.menu` style) with a color dot beside it |
| Groups panel, icon | Symbol grid expanded inline under the row | Symbol grid in a `.popover` anchored to the group's icon |
| Groups panel, delete | Two taps: a red capsule appeared inline | Destructive `Button` that opens a standard `.alert` with Cancel |
| Groups panel, move and delete icons | Custom plain buttons with a manual dim | `.buttonStyle(.borderless)` with `.disabled`, so the system draws hover, press and disabled states |
| Groups and Hidden panels | Floating overlays in the grid's top corner, closed by a blank-area tap | `.popover`s anchored to their header buttons, closed by an outside click or Escape |
| Header buttons (Hidden, Groups, Edit/Done) | Plain buttons with a hand-drawn capsule | `.buttonStyle(.glass)` |
| Hidden apps, Restore | Capsule drawn by hand | `.buttonStyle(.glassProminent)`, small |
| Undo toast | Capsule drawn by hand | `.buttonStyle(.glass)`, small |
| Onboarding footer, Back, Skip | `OnboardingButtonStyle` (custom) | `.buttonStyle(.borderless)`, large |
| Onboarding footer, Continue | `OnboardingButtonStyle` (custom ink pill) | `.buttonStyle(.glassProminent)` with the ink tint, large |
| Onboarding, modifier keys | Custom toggle chips | `Toggle` with `.toggleStyle(.button)`, so the selected state and keyboard focus are the system ones |

`OnboardingButtonStyle` was deleted. Nothing used it after the swap.

## Already native, left alone

- **Settings window.** `NavigationSplitView` with a sidebar `List`, `Form` with `.formStyle(.grouped)` in every pane, `LabeledContent`, `Toggle`, `Stepper`, `Picker` and `confirmationDialog`. Each pane sets `.navigationTitle`.
- **Context menus.** The grid and the Quick Panel use `.contextMenu`, with the Move to Group submenu as a native `Menu`.
- **Menu bar item.** `NSMenu` through `MenuBarController`.
- **Segmented pickers in onboarding.** Three to four options each, so segmented is the right control.
- **Hot corner, Dock click, Recent apps, Theme.** Already `Picker`s in Settings.
- **Colors.** Group colors are the nine `NSColor` system colors (`GroupStyle.swift`), so they follow Light, Dark and Increase Contrast.

## Kept custom on purpose

- **Hotkey recorder** (`HotkeyRecorderRow.swift`). SwiftUI and AppKit have no shortcut-recording control, so the row records the key itself and says so in its footer.
- **Group bar** (`GroupBar.swift`). Each group has its own color and symbol, the bar scrolls when it's too wide, it accepts drag-and-drop of apps, and it sits on the brand glass capsule. `Picker` with `.segmented` can't show per-group colors, can't drop, and doesn't scroll. The bar keeps its custom segments and gets the brand tokens.
- **Page dots** (`EditableGridView.swift`). `TabView`'s page indicator isn't available outside a `TabView`, and the grid pages with trackpad swipes. The dots stay custom, with `accessibilityLabel` for each page.
- **Search field** (`SearchPanel.swift`). It sits in a glass capsule that morphs into the results. The system search field has no way to do that.
- **Floating tile press effect** (`AppIconCell.swift`). A press scale is the Launchpad feel. The button is still a real `Button`, so VoiceOver and keyboard focus work.

## Color decisions

- **Brand tokens** (`InletColor`, `InletText`) stay on the brand surfaces: the grid backdrop, the glass panels, the group bar and the onboarding window.
- **System colors** cover content that follows the user: group colors, the Delete alert's destructive role, and the Toggle and Stepper tint in Settings.
- **Accent** on prominent buttons is the brand accent, set with `.tint`, so it matches the website.

## Keyboard focus

- Every `Button` in the Groups and Hidden panels, and in the header, is now a stock control, so it joins the Tab order and shows the system focus ring.
- Escape closes the Groups popover first, as before. Clicking outside a popover closes it.
- Before this change, the custom capsule buttons were `.buttonStyle(.plain)` and did not show a focus ring in Full Keyboard Access. This is the main keyboard fix.

## Open after this PR

- A `ColorPicker` is not used for group colors. The model stores one of nine `GroupColor` cases, and a free color would need a model change first. The menu covers the palette, and it's a one-line change if nate wants free colors.
- `Feedback/FeedbackView.swift` still uses a hand-drawn background for its list. It's small, and it wasn't on the list of the screens that matter for this pass.
- The Settings window is still a fixed 700 × 520 from `InletSize.settingsWindow`. Native Settings windows can resize. Changing that is a one-line decision.
