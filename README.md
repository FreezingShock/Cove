# Cove

A personal Mac launcher that replaces Launchpad, which Apple removed in macOS 26 Tahoe. Native Swift, SwiftUI and AppKit. Everything stays on your Mac: no network calls, tracking or accounts.

**Current version: 0.1 (Skeleton).** Cove scans your app folders and shows every installed app in a plain grid of real icons. Click an icon to open the app. The glass overlay, hotkey, search and Dock panel come in later versions (see the roadmap below).

## Requirements

- macOS 26 or later
- Xcode 26 or later (free from the Mac App Store)
- No paid Apple Developer account. The build is signed "to run locally", which is fine for your own Mac.

## Open and run it in Xcode

1. Clone the repo, or in GitHub click **Code > Download ZIP** and unzip it.
2. Double-click `Cove.xcodeproj`. Xcode opens the project.
3. At the top of the window, make sure the scheme says **Cove** and the destination says **My Mac**.
4. Press **Command-R** (or click the triangle Play button). Xcode builds the app and launches it.
5. The Cove window shows every app. Click one to open it.

To stop Cove, press **Command-.** in Xcode or quit Cove normally.

### App icon files

The Crescent icon's PNG files aren't stored in git, because binary files can't be committed through the GitHub connector. Copy these 12 files from the Crescent icon set (the `AppIcon.appiconset` folder in the design project) into `Cove/Assets.xcassets/AppIcon.appiconset/`. The asset catalog's `Contents.json` already lists their names:

`light-16x16@1x.png`, `light-16x16@2x.png`, `light-32x32@1x.png`, `light-32x32@2x.png`, `light-128x128@1x.png`, `light-128x128@2x.png`, `light-256x256@1x.png`, `light-256x256@2x.png`, `light-512x512@1x.png`, `light-512x512@2x.png`, `dark-1024.png`, `tinted-1024.png`

Until they're copied in, Xcode shows a generic icon.

### If something goes wrong

- **"Signing for Cove requires a development team."** Click the blue Cove project in the left sidebar, choose the **Cove** target, open **Signing & Capabilities**, and either pick your Personal Team (sign in with your Apple ID under Xcode > Settings > Accounts) or set Signing Certificate to **Sign to Run Locally**.
- **Build fails with "Cannot find type ... in scope".** Make sure you opened `Cove.xcodeproj`, not a single Swift file, and that Xcode is version 26 or newer.
- **An app is missing.** Cove looks in `/Applications`, `~/Applications` and `/System/Applications`, including subfolders like Utilities. Apps stored elsewhere won't show yet. Press **Command-R inside Cove** (File > Reload Apps) to rescan; it also rescans every time you switch back to Cove.

### Running it without Xcode

After one successful run, choose **Product > Show Build Folder in Finder** in Xcode, open `Products/Debug`, and drag `Cove.app` into your Applications folder. You can then open it like any other app and keep it in the Dock.

## How the code is organized

| File | What it does |
|---|---|
| `Cove/CoveApp.swift` | Entry point. Creates the window and the File > Reload Apps menu item. |
| `Cove/Models/AppItem.swift` | One installed app: name, location, bundle ID. |
| `Cove/Models/AppLibrary.swift` | Holds the app list and rescans it in the background. |
| `Cove/Services/AppScanner.swift` | Walks the app folders and builds the sorted list. |
| `Cove/Services/IconCache.swift` | Gets each app's real icon from macOS and caches it. |
| `Cove/Services/AppLauncher.swift` | Opens an app through macOS and shows an alert if it fails. |
| `Cove/Views/AppGridView.swift` | The window: header and 7-column grid. |
| `Cove/Views/AppIconCell.swift` | One grid cell: icon, name, hover and press effects. |
| `Cove/CoveTheme.swift` | Design tokens from `theme-spec.md`: colors, radii, spacing, type, spring motion, glass, and the Reduce Motion, Reduce Transparency and Increase Contrast helpers. |

New files you add inside the `Cove` folder appear in Xcode automatically.

### Apple APIs used

Each was checked against Apple's current documentation.

- [`FileManager.enumerator(at:includingPropertiesForKeys:options:errorHandler:)`](https://developer.apple.com/documentation/foundation/filemanager/enumerator(at:includingpropertiesforkeys:options:errorhandler:)) with `.skipsPackageDescendants` to find `.app` bundles without looking inside them
- [`URLResourceKey.localizedNameKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/localizednamekey) for the name Finder shows
- [`NSWorkspace.icon(forFile:)`](https://developer.apple.com/documentation/appkit/nsworkspace/icon(forfile:)) for the real app icon
- [`NSWorkspace.openApplication(at:configuration:completionHandler:)`](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication(at:configuration:completionhandler:)) to launch
- [`LazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid) for the grid
- [`Spring`](https://developer.apple.com/documentation/swiftui/spring) and [`Animation.spring(_:blendDuration:)`](https://developer.apple.com/documentation/swiftui/animation/spring(_:blenddurations:)) for the motion tokens (macOS 14+)
- [`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)) for panel and capsule glass (macOS 26+)

## Decisions made in 0.1

- **No App Sandbox.** A sandboxed app can't freely read app folders or launch other apps. This matches the plan to skip the App Store.
- **Swift 5 language mode.** Swift 6's strict concurrency checks produce errors that are confusing when you're new to Swift. Moving to Swift 6 later is a one-line build setting change.
- **Deployment target macOS 26.0.** Matches "macOS 26 or later". Can be raised to 27 if that open question lands there.
- **Duplicates removed by bundle ID.** If the same app sits in two folders, the copy in `/Applications` wins, then `~/Applications`, then `/System/Applications`.
- **Background-only helpers are hidden** (apps marked `LSBackgroundOnly`), since opening them would look like nothing happened. Menu bar apps still show.
- **Rescan on focus** instead of watching the folders. Simpler for now, and fast because it runs in the background and only redraws when the list changed. Folder watching can replace it in 0.2 when Cove stays resident.
- **Design tokens follow `theme-spec.md` v1.1.** Light and dark values are both defined. The app is forced to dark for now, so the light values aren't visible until the Appearance setting lands in 0.5.
- **Grid side padding is 40 pt.** That value isn't in the spec. It stays until the 0.5 polish pass.

## Roadmap

| Version | What ships | Done when |
|---|---|---|
| **0.1 Skeleton** | Xcode project, app scan, plain grid of real icons, click to launch | Every installed app appears and opens |
| 0.2 Overlay | Full-screen glass overlay, instant show/hide, Escape, global hotkey | Opening feels instant |
| 0.3 Search | App filtering, Spotlight file results, top hit, keyboard nav | An app or file opens without the mouse |
| 0.4 Dock panel | Quick panel on Dock icon click, recent apps and files | Dock click toggles it reliably |
| 0.5 Polish | Full design pass, app icon, animations, settings | Screens match the mockup |
| 1.0 Daily driver | Bug fixes from real use | A week of daily use with no crash |
