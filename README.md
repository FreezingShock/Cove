<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="website/assets/inlet-wordmark-dark.svg">
    <img src="website/assets/inlet-wordmark-light.svg" alt="Inlet" height="48">
  </picture>
</p>

# Inlet

A personal Mac launcher that replaces Launchpad, which Apple removed in macOS 26 Tahoe. Native Swift, SwiftUI and AppKit. Everything stays on your Mac: no accounts and no tracking. The only network call is an update check, which you can turn off.

**Current version: 0.1 (Skeleton).** Inlet scans your app folders and shows every installed app in a plain grid of real icons. Click an icon to open the app. The glass overlay, hotkey, search and Dock panel come in later versions (see the roadmap below).

## Requirements

- macOS 26 or later
- Xcode 26 or later (free from the Mac App Store)
- No paid Apple Developer account. The build is signed "to run locally", which is fine for your own Mac.

## Open and run it in Xcode

1. Clone the repo, or in GitHub click **Code > Download ZIP** and unzip it.
2. Double-click `Inlet.xcodeproj`. Xcode opens the project.
3. At the top of the window, make sure the scheme says **Inlet** and the destination says **My Mac**.
4. Press **Command-R** (or click the triangle Play button). Xcode builds the app and launches it.
5. The Inlet window shows every app. Click one to open it.

To stop Inlet, press **Command-.** in Xcode or quit Inlet normally.

### If something goes wrong

- **"Signing for Inlet requires a development team."** Click the blue Inlet project in the left sidebar, choose the **Inlet** target, open **Signing & Capabilities**, and either pick your Personal Team (sign in with your Apple ID under Xcode > Settings > Accounts) or set Signing Certificate to **Sign to Run Locally**.
- **Build fails with "Cannot find type ... in scope".** Make sure you opened `Inlet.xcodeproj`, not a single Swift file, and that Xcode is version 26 or newer.
- **An app is missing.** Inlet looks in `/Applications`, `~/Applications` and `/System/Applications`, including subfolders like Utilities. Apps stored elsewhere won't show yet. Press **Command-R inside Inlet** (File > Reload Apps) to rescan; it also rescans every time you switch back to Inlet.

### Running it without Xcode

After one successful run, choose **Product > Show Build Folder in Finder** in Xcode, open `Products/Debug`, and drag `Inlet.app` into your Applications folder. You can then open it like any other app and keep it in the Dock.

## How the code is organized

| File | What it does |
|---|---|
| `Inlet/InletApp.swift` | Entry point. Creates the window and the File > Reload Apps menu item. |
| `Inlet/Models/AppItem.swift` | One installed app: name, location, bundle ID, category. |
| `Inlet/Models/AppCategory.swift` | Maps each app's category to a preset: Create, Build, School, Everyday, Games, Other. |
| `Inlet/Models/AppGroup.swift` | A group on the group bar: name, color, icon, apps. Presets come from the categories. |
| `Inlet/Models/AppLibrary.swift` | Holds the app list and rescans it in the background. |
| `Inlet/Services/AppScanner.swift` | Walks the app folders and builds the sorted list. |
| `Inlet/Services/IconCache.swift` | Gets each app's real icon from macOS and caches it. |
| `Inlet/Services/AppLauncher.swift` | Opens an app through macOS and shows an alert if it fails. |
| `Inlet/Views/AppGridView.swift` | The window: header and 7-column grid. |
| `Inlet/Views/AppIconCell.swift` | One grid cell: icon, name, hover and press effects. |
| `Inlet/AppDelegate.swift` | Handles Dock clicks (reopen) and opens the quick panel or grid. |
| `Inlet/Services/RecentsStore.swift` | Recent apps, saved as JSON in Application Support. Recent files stub. |
| `Inlet/Views/QuickPanel/` | Quick panel window (controller) and its SwiftUI view. |
| `Inlet/InletTheme.swift` | Design tokens from `theme-spec.md`: colors, radii, spacing, type, spring motion, glass, and the Reduce Motion, Reduce Transparency and Increase Contrast helpers. |
| `Inlet/Views/Groups/GroupBar.swift` | The All-plus-groups bar above the grid. Tap to filter. Fades out while search has text. |
| `Inlet/Views/Groups/GroupsPanel.swift` | The Groups panel: add, rename, recolor, re-icon, reorder and delete groups. |
| `Inlet/Views/Groups/GroupStyle.swift` | Group colors and the Move to Group context menu. |
| `Inlet/Theme.swift` | Colors and sizes from the design system. |

New files you add inside the `Inlet` folder appear in Xcode automatically.

### Apple APIs used

Each was checked against Apple's current documentation.

- [`FileManager.enumerator(at:includingPropertiesForKeys:options:errorHandler:)`](https://developer.apple.com/documentation/foundation/filemanager/enumerator(at:includingpropertiesforkeys:options:errorhandler:)) with `.skipsPackageDescendants` to find `.app` bundles without looking inside them
- [`URLResourceKey.localizedNameKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/localizednamekey) for the name Finder shows
- [`NSWorkspace.icon(forFile:)`](https://developer.apple.com/documentation/appkit/nsworkspace/icon(forfile:)) for the real app icon
- [`NSWorkspace.openApplication(at:configuration:completionHandler:)`](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication(at:configuration:completionhandler:)) to launch
- [`LazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid) for the grid

## Decisions made in 0.1

- **No App Sandbox.** A sandboxed app can't freely read app folders or launch other apps. This matches the plan to skip the App Store.
- **Swift 5 language mode.** Swift 6's strict concurrency checks produce errors that are confusing when you're new to Swift. Moving to Swift 6 later is a one-line build setting change.
- **Deployment target macOS 26.0.** Matches "macOS 26 or later". Can be raised to 27 if that open question lands there.
- **Duplicates removed by bundle ID.** If the same app sits in two folders, the copy in `/Applications` wins, then `~/Applications`, then `/System/Applications`.
- **Background-only helpers are hidden** (apps marked `LSBackgroundOnly`), since opening them would look like nothing happened. Menu bar apps still show.
- **Rescan on focus** instead of watching the folders. Simpler for now, and fast because it runs in the background and only redraws when the list changed. Folder watching can replace it in 0.2 when Inlet stays resident.
- **App icon is in the asset catalog but not checked on a Mac yet.** The Crescent set is in `Inlet/Assets.xcassets/AppIcon.appiconset`. Check it in Xcode 26 and at 16 and 32 pt in the Dock.

## Roadmap

| Version | What ships | Done when |
|---|---|---|
| **0.1 Skeleton** | Xcode project, app scan, plain grid of real icons, click to launch | Every installed app appears and opens |
| 0.2 Overlay | Full-screen glass overlay, instant show/hide, Escape, global hotkey | Opening feels instant |
| 0.3 Search | App filtering, Spotlight file results, top hit, keyboard nav | An app or file opens without the mouse |
| 0.4 Dock panel | Quick panel on Dock icon click, recent apps and files | Dock click toggles it reliably |
| 0.5 Polish | Full design pass, app icon, animations, settings | Screens match the mockup |
| 1.0 Daily driver | Bug fixes from real use | A week of daily use with no crash |

## License

Inlet is released under the MIT License. See [LICENSE](LICENSE).
