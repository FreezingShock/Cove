# Mac test checklist: native controls

Run this on a Mac with macOS 26 after the build from this PR. CI compiles and runs the
unit tests, but it can't see a popover, a focus ring or a menu. Tick each line, and note
the macOS version and the appearance (Light, Dark) you tested in.

Setup: a Mac with at least five apps in `/Applications`, one app hidden, and two groups
beyond the presets. Test in Light and Dark, with Increase Contrast on once, and with Reduce
Transparency on once.

## Groups popover

- [ ] Click **Groups** in the grid header. A popover opens under the button, not a panel in the corner.
- [ ] Click outside the popover. It closes. Note whether the click also closes the whole grid (it should not).
- [ ] Press Escape with the popover open. It closes, and the grid stays open.
- [ ] **Add Group** creates "New Group" with a star icon and a color not yet used.
- [ ] The group name is editable in place. Return saves it. Clicking away saves it. An empty name reverts.
- [ ] The color **pop-up menu** lists the nine colors by name. Choosing one recolors the icon and the dot next to the menu, and the group bar shows the new color.
- [ ] Clicking a group's icon opens the **symbol popover**. The current symbol is highlighted in its color. Choosing one closes the popover and changes the icon.
- [ ] Up and down arrows move a group on the bar. They are dimmed at the first and last group.
- [ ] Trash is dimmed when only one group is left.
- [ ] Trash opens an **alert** titled "Delete “<name>”?" with the message "Its apps move to <group>." **Cancel** keeps the group. **Delete** removes it, and its apps appear in the fallback group.
- [ ] Escape on the alert cancels it, and the group stays.

## Header buttons and Hidden apps

- [ ] **Groups**, **Hidden N** and **Edit/Done** use the glass button style, and they show a hover state.
- [ ] **Hidden N** opens a popover with each hidden app and a **Restore** button. Restore brings the app back into the grid.
- [ ] Opening Hidden closes Groups, and opening Groups closes Hidden.
- [ ] With no hidden apps, the Hidden button does not appear.
- [ ] Hiding an app shows the **Undo** toast at the bottom. Undo restores the app. The toast disappears after its timer.

## Keyboard

- [ ] Tab moves focus through the header buttons and into the open popover. Each stop shows the system focus ring.
- [ ] Space or Return activates the focused button.
- [ ] Full Keyboard Access (System Settings > Keyboard) on: the same stops are reachable.
- [ ] Arrow keys still move the selection in the grid when no popover has focus.

## Context menus

- [ ] Right-click an app. **Move to Group** is a submenu. The current group has a checkmark and cannot be chosen.
- [ ] Right-click empty space in the grid. Nothing unexpected appears.

## Onboarding

- [ ] Back, Skip for now and Continue use the system styles. Continue is the prominent ink button. It is dimmed when it can't continue.
- [ ] On the shortcut step, each modifier key is a toggle button. Its on state is the same selected look as the segmented controls beside it.
- [ ] Modifier toggles can be focused with Tab and toggled with Space.
- [ ] The segmented controls for Opens, Press and Key still change the preview.

## Settings

- [ ] Command-, opens Settings. The sidebar lists eight panes, and each detail pane is a grouped Form.
- [ ] Every toggle, picker and stepper in every pane changes its value and survives a relaunch.
- [ ] Hot corner, Dock click and Recent apps show pop-up menus and list every option.
- [ ] Erase Launch History asks first with a destructive confirmation.

## Appearance

- [ ] Light, Dark and Auto change the Inlet windows. Settings follows the same choice.
- [ ] With Reduce Transparency on, the glass panels show a solid fill and the header buttons stay readable.
- [ ] With Increase Contrast on, secondary text becomes full-strength.
- [ ] Group colors are readable in both appearances.

## Pass or fail

Record each failure with the macOS version, the appearance, and a screenshot. A failure in the
popover or alert behavior is the highest priority, because those are the new code paths.
