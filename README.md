<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/readme/icon-dark.png">
    <img src="docs/readme/icon-light.png" alt="Inlet app icon" width="112">
  </picture>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/readme/wordmark-dark.svg">
    <img src="docs/readme/wordmark-light.svg" alt="Inlet" height="56">
  </picture>
</p>

<p align="center">
  <strong>Every app, one keystroke away.</strong><br>
  The full-screen app grid Apple took away, back on your Mac.
</p>

<p align="center">
  <a href="https://github.com/FreezingShock/Inlet/releases/latest/download/Inlet.dmg">
    <img src="https://img.shields.io/badge/Download_for_Mac-Inlet.dmg-0B5D51?style=for-the-badge&logo=apple&logoColor=white" alt="Download Inlet for Mac">
  </a>
</p>

<p align="center">
  macOS 26 or later &nbsp;·&nbsp; Free &nbsp;·&nbsp; Open source (MIT)
</p>

<p align="center">
  <img src="docs/readme/hero-grid.png" alt="Inlet's full-screen grid of apps over a macOS desktop, with the search field at the top" width="100%">
</p>

---

## Install

Inlet installs like any other Mac app. You don't need an account, and there's nothing to set up first.

1. **Download** Inlet with the button above. You get a file called `Inlet.dmg`.
2. **Open** the disk image and drag **Inlet** onto **Applications**.
3. **Open Inlet** from Applications. Apple doesn't check Inlet yet, so macOS stops the first launch. Click **Done**.
4. Open **System Settings**, go to **Privacy & Security**, scroll down, and click **Open Anyway** next to Inlet. Enter your password. Inlet opens, and you won't see this again.

<p align="center">
  <img src="docs/readme/feature-install.png" alt="Drag Inlet from the disk image into the Applications folder" width="92%">
</p>

If the Open Anyway button disappears, try opening Inlet once more and it will come back.

Requires macOS 26 or later.

---

## Features

<p align="center">
  <img src="docs/readme/feature-grid.png" alt="The grid of every app on your Mac" width="92%">
</p>

**Every app, in one grid.** Inlet shows all the apps on your Mac with their own icons. Click one to open it. Press Escape or click outside to close the grid. You can swipe between pages on the trackpad, and pinch to open it.

<p align="center">
  <img src="docs/readme/feature-search.png" alt="Typing a search shows matching apps and files" width="92%">
</p>

**Search for anything.** Start typing and the grid narrows down. The best match is highlighted, and matching files show up underneath. Press Return to open the top match, or Command Return to show a file in Finder.

<p align="center">
  <img src="docs/readme/feature-quick.png" alt="The quick panel above the Dock, with recent apps and files" width="92%">
</p>

**A quick panel from your Dock.** Click the Inlet icon in the Dock to see your recent apps and files, with one button to open the full grid. You choose how many recent apps and files to show.

<p align="center">
  <img src="docs/readme/feature-groups.png" alt="A row of group tabs above the app grid, with four groups and their apps" width="92%">
</p>

**Groups.** Sort your apps into groups like Create, Build, School, Everyday, Games, and Other. Tap a group to see only its apps. Make your own groups too, and name them, color them, and put them in the order you like. Right-click any app to move it to another group.

<p align="center">
  <img src="docs/readme/feature-edit.png" alt="Edit mode with apps jiggling, a folder, and an Undo button" width="92%">
</p>

**Arrange it your way.** Press and hold an icon to move it. Put related apps in a folder, up to nine apps each. Hide any app you don't use by tapping the small minus badge, and bring it back later from the hidden list. Apple's own apps can't be hidden. Your layout is saved on your Mac.

<p align="center">
  <img src="docs/readme/feature-keys.png" alt="Keycaps for Option Space, Control Option Space, Return, and Command Return" width="92%">
</p>

**Keyboard first.** <kbd>⌥</kbd> <kbd>Space</kbd> opens the grid from anywhere. <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>Space</kbd> opens the quick panel. <kbd>F4</kbd> also opens the grid. <kbd>Esc</kbd> clears your search first and closes the grid when the search is empty. You can change any of these in Settings.

<p align="center">
  <img src="docs/readme/feature-settings.png" alt="A settings window with appearance, grid columns, search files, updates, and hot corner controls" width="92%">
</p>

**Settings that feel like a Mac.** Pick Light, Dark, or Auto for the appearance. Choose 5 to 9 grid columns. Decide whether search includes files. Turn update checks on or off. Press <kbd>⌘</kbd> <kbd>,</kbd> to open Settings.

<p align="center">
  <img src="docs/readme/feature-privacy.png" alt="A lock icon with the words stays on your Mac" width="92%">
</p>

**Stays on your Mac.** Inlet has no account and no analytics, and it doesn't upload your files or your list of apps. Your recent items, groups, and layout are saved only on your Mac. The one network call is a daily check for updates, and you can turn it off in Settings.

---

## Supporter

<p align="center">
  <img src="docs/readme/supporter.png" alt="The Supporter plan at five dollars a month, with custom themes and zones, unlimited groups, early builds, and the 1.0 release" width="92%">
</p>

Inlet is free, and the whole app is included. If you want to help keep it going, you can become a **Supporter** for **$5 a month** through [GitHub Sponsors](https://github.com/sponsors/FreezingShock).

Supporters get the customization tools (custom themes and zones) and early builds a few weeks before each release. Supporter opens with the 1.0 release. Building Inlet from source stays free.

---

## Build it yourself

<details>
<summary>Build from source (for developers)</summary>

You need macOS 26 and Xcode 26.

```sh
git clone https://github.com/FreezingShock/Inlet.git
cd Inlet
open Inlet.xcodeproj
```

In Xcode, choose the **Inlet** scheme and **My Mac**, then press <kbd>⌘</kbd> <kbd>R</kbd>. If Xcode asks for a development team, open **Signing & Capabilities** for the Inlet target and choose **Sign to Run Locally**. Press <kbd>⌘</kbd> <kbd>U</kbd> to run the tests.

</details>

---

## Privacy

Your data stays on your Mac. Inlet doesn't upload your files or your app list, and it has no analytics or tracking. The only network call is a daily update check to GitHub, and you can turn it off in Settings.

Inlet never sends a crash or feedback report on its own. Those open a GitHub issue in your browser, and you decide what to post.

---

## License

Inlet is open source under the [MIT License](LICENSE). Read it, change it, and build it for any purpose.

---

<p align="center">
  <sub>Inlet is an independent project by FreezingShock. It is not made by, endorsed by, or affiliated with Apple Inc.</sub>
</p>
