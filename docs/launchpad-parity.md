# Classic Launchpad parity

Inlet replaces Launchpad, which Apple removed in macOS 26 Tahoe. This page lists
what classic Launchpad did, what Inlet does today, and what still needs a check on
a real Mac. Build and unit tests run on CI. Nothing here has been run on a Mac yet, so
every "Added" row needs the test list at the bottom.

Status key:

- **Already** — in the app before this change.
- **Added** — built in this change (see the file in the last column).
- **Setting** — works, but the default or the behavior is a choice the user makes in Settings.
- **Different (on purpose)** — Inlet does something else, and why.
- **Owned elsewhere** — a parallel feature thread takes it (folders, groups, settings, indexing).
- **Check on Mac** — the behavior is built, but the macOS behavior is not confirmed.

## Opening and closing

| Classic Launchpad | Inlet | Status | Where |
|---|---|---|---|
| Open with the Launchpad key (F4) | F4 opens the grid. On by default. Turn it off in Settings > General. Option Space stays the main hotkey. | Added | `HotkeyManager.swift`, `InletSettings.swift` |
| Pinch in opens; spread out closes | Pinch in opens the grid, and spread out closes it. Pinch in only opens while Finder is the front app (you are on the desktop), so a pinch in Safari never opens Inlet. | Added, Check on Mac | `OpenTriggers.swift` |
| Hot corner opens it | Off by default. Set one corner in Settings > General. The pointer must rest there for 0.25 s. A hot corner only opens; it never closes. | Added, Check on Mac | `OpenTriggers.swift` |
| Blurred desktop behind the grid | `NSVisualEffectView` (`.fullScreenUI`, behind the window) under the scrim. It fades in with the open. Reduce Transparency removes the blur. | Added, Check on Mac | `OverlayController.swift` |
| Icons ripple in from the center on open | Now on the paged grid too (it was only on search and category results). Each page ripples from its own center. | Added | `GridTile.swift`, `EditableGridView.swift` |
| Click on empty space closes it | A tap on empty space closes the grid, outside Edit mode. In Edit mode it leaves Edit mode first. | Added | `AppGridView.swift`, `EditableGridView.swift` |
| Escape closes it | Escape leaves Edit mode, then clears the search (if the setting is on), then closes. | Already | `AppGridView.swift` |
| Opening an app closes the grid | On by default (Settings > General). | Already | `AppGridView.swift` |
| Dock icon opens Launchpad | Dock click opens the quick panel by default. Settings > Quick Panel sets it to the grid. | Setting | `AppDelegate.swift` |
| Opens over full-screen apps and every Space | `canJoinAllSpaces`, `fullScreenAuxiliary`. | Already | `OverlayController.swift` |
| Opens on the screen with the pointer | Covers the whole screen under the cursor, menu bar included. | Already | `OverlayController.swift` |

## Pages

| Classic Launchpad | Inlet | Status | Where |
|---|---|---|---|
| Paged grid with dots | Paged grid, with page dots. Tap a dot to jump to that page. | Already | `EditableGridView.swift` |
| Swipe between pages with the mouse | Drag sideways, with a rubber band at the ends. | Already | `EditableGridView.swift` |
| Swipe between pages with a trackpad (two fingers) | Horizontal two-finger swipes page the grid, and follow the fingers. Vertical swipes are ignored, and so is momentum after the fingers lift. | Added, Check on Mac | `TrackpadPaging.swift` |
| Drag an icon to the window edge to turn the page | Rests 0.52 s at either edge. | Already | `EditableGridView.swift` |
| Arrow keys move through icons | Left and Right cross from one page to the next. Up and Down move by a row. | Added | `AppGridView.swift` |
| Page count follows the apps | Pages come from the saved layout. | Already | `LayoutStore.swift`, `GridGeometry.swift` |

## Edit mode

| Classic Launchpad | Inlet | Status | Where |
|---|---|---|---|
| Press and hold an icon to jiggle | Hold 0.48 s without moving. | Already | `EditableGridView.swift` |
| Icons wobble in Edit mode | ±1.3° wobble. Still under Reduce Motion. | Already | `GridTile.swift` |
| Drag to reorder, across pages | Drop to reorder. Saved once, when the drag ends. | Already | `EditableGridView.swift` |
| Drop one icon on another to make a folder | Folders are a separate feature. | Owned elsewhere (folders thread) | — |
| Rename a folder | Same. | Owned elsewhere (folders thread) | — |
| Delete badge (×) on each app | Minus badge hides the app, with Undo for a few seconds. Restore from the Hidden apps list. | Different (on purpose) | `GridTile.swift`, `AppGridView.swift` |
| × deletes the app from the Mac | Not done. Inlet hides apps and never deletes them, so a misclick can't remove anything. | Different (on purpose) | — |
| Apple's own apps can have a badge | Apple's apps (`com.apple.*`) can't be hidden, so they have no badge. | Different (on purpose) | `GridTile.swift` (`isHideable`) |
| Leave Edit mode | Done button, Escape, or a tap on empty space. | Already | `AppGridView.swift` |
| Option + arrow in Edit mode moves an icon | Inlet's keyboard reorder. | Already | `AppGridView.swift` |

## Search and keyboard

| Classic Launchpad | Inlet | Status | Where |
|---|---|---|---|
| Type to search | The search field has focus when the grid opens. Typing filters apps, and files through Spotlight. | Already | `SearchPanel.swift`, `FileSearch.swift` |
| Return opens the top hit | Return opens the top hit, or the focused icon. | Already | `AppGridView.swift` |
| Arrow keys move focus, with a focus ring | Focus ring plus VoiceOver actions. | Already | `AppGridView.swift`, `GridTile.swift` |
| Option held while clicking | Not confirmed for classic Launchpad. Not built. | Check on Mac (behavior unknown) | — |

## Not in this change

- Folders (create, open, rename, nested apps): folders thread.
- New groups and categories: groups thread.
- Settings redesign: settings thread.
- Indexing and search speed: indexing thread.

## Mac test checklist

Run on a Mac with macOS 26 Tahoe, from a Debug build, with the app in `/Applications`
(so it is scanned). Tick each line, and note the macOS version and whether the
keyboard is a built-in or an external one.

**Opening**

- [ ] Option Space opens the grid and closes it on a second press.
- [ ] F4 opens the grid. Check the F4 key on a Mac keyboard with "Use F1, F2, etc. keys as standard function keys" off, and again with it on. Note which one works.
- [ ] Turn F4 off in Settings > General. F4 no longer opens the grid.
- [ ] Pinch in on the desktop (click the desktop, so Finder is front) opens the grid. Spread out closes it.
- [ ] Pinch in inside Safari (or any other app) does **not** open the grid.
- [ ] Turn pinch off. Pinch in on the desktop does nothing.
- [ ] System Settings did not show a new permission prompt (Input Monitoring, Accessibility, or Screen Recording) for pinch, hot corner or F4. Note any prompt you see.
- [ ] Set the hot corner to Top left. Rest the pointer in the top-left corner for about 0.25 s: the grid opens. Keep the pointer there: it does not close again.
- [ ] With the grid open, rest the pointer in the hot corner: nothing closes the grid.
- [ ] Each hot corner (all four) opens the grid only in its own corner.
- [ ] The desktop behind the grid is blurred. Turn on Reduce Transparency: the blur goes, and the scrim stays.
- [ ] Icons ripple in from the center on open, on the paged grid, and per page.

**Closing**

- [ ] Click empty space in the paged grid: the grid closes.
- [ ] Click empty space in the header or the search area: the grid closes.
- [ ] Escape closes the grid, after the search is cleared (if the setting is on).
- [ ] Tap empty space in Edit mode: leaves Edit mode, and the grid stays open.
- [ ] Opening an app closes the grid (if "Close after launching" is on).

**Pages**

- [ ] Two-finger horizontal swipe on the trackpad turns the page, and the icons follow the fingers.
- [ ] A short swipe springs back to the same page. A long or fast swipe turns the page.
- [ ] Two-finger vertical scroll does not turn pages.
- [ ] A swipe at the first or last page stretches a little, then springs back.
- [ ] Mouse drag still turns pages. Page dots still jump to a page.
- [ ] Right arrow on the last icon of a page moves focus to the first icon of the next page, and the page turns.

**Edit mode**

- [ ] Press and hold an icon for about half a second: all icons wobble, and minus badges show on third-party apps only.
- [ ] Drag an icon onto another page edge: the page turns after about half a second.
- [ ] Drag reorders across pages, and the order is kept after relaunch.
- [ ] Minus badge hides an app. The Undo toast works. Hidden apps → Restore brings it back.
- [ ] Apple's own apps have no minus badge.

**Settings**

- [ ] Settings > General, "Opening the grid" section: all three controls save and survive a relaunch.
- [ ] Hot corner picker: "Off" disables the corner.

**Build and tests**

- [ ] CI is green on `integration` for this PR (build, and the new `HotCornerTests`).
- [ ] `xcodebuild` on macOS 26 builds the app without new warnings from the files this PR touches.
