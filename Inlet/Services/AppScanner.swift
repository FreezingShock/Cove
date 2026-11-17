//
//  AppScanner.swift
//  Inlet
//
//  Finds installed apps by walking the standard app folders.
//

import Foundation

enum AppScanner {
    /// Folders to search, in priority order. If the same app (same bundle
    /// ID) shows up in two places, the copy in the earlier folder wins.
    static var searchFolders: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        ]
    }

    /// The search folders that exist right now, with symlinks resolved. The file
    /// watcher uses these, since FSEvents can only watch folders that exist.
    static var existingSearchFolderPaths: [String] {
        searchFolders.compactMap { folder in
            let resolved = folder.resolvingSymlinksInPath()
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { return nil }
            return resolved.path
        }
    }

    /// Returns every launchable app in `searchFolders`, sorted by name the
    /// way Finder sorts (so "App 2" comes before "App 10").
    ///
    /// This reads the disk, so call it off the main thread.
    static func scanInstalledApps() -> [AppItem] {
        var results: [AppItem] = []
        var seenBundleIDs = Set<String>()
        var seenPaths = Set<String>()

        // Resolve each folder first, so a folder that is a symlink (such as a
        // ~/Applications that points at another disk) is scanned at its target.
        for folder in searchFolders.map({ $0.resolvingSymlinksInPath() }) {
            for appURL in findAppBundles(in: folder) {
                // Resolve symlinks so one app linked from two places
                // only appears once.
                let realPath = appURL.resolvingSymlinksInPath().path
                guard seenPaths.insert(realPath).inserted else { continue }

                guard let item = makeItem(for: appURL) else { continue }

                if let bundleID = item.bundleIdentifier {
                    guard seenBundleIDs.insert(bundleID).inserted else { continue }
                }
                results.append(item)
            }
        }

        return results.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Walks `folder` and its subfolders (e.g. /System/Applications/Utilities)
    /// and returns every .app bundle inside.
    private static func findAppBundles(in folder: URL) -> [URL] {
        // `skipsPackageDescendants` stops the walk from going *inside* an
        // .app bundle, so helper apps hidden inside other apps are skipped.
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isApplicationKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true } // unreadable folder: keep going
        ) else {
            return [] // folder doesn't exist (e.g. no ~/Applications)
        }

        var bundles: [URL] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isApplicationKey])
            if values?.isApplication == true || url.pathExtension == "app" {
                bundles.append(url)
            }
        }
        return bundles
    }

    /// Reads an app's name and bundle ID. Returns nil for bundles that are
    /// not meant to be opened by people (background-only agents).
    private static func makeItem(for url: URL) -> AppItem? {
        let info = Bundle(url: url)?.infoDictionary ?? [:]

        // Background-only apps have no window or Dock icon; launching
        // them from a grid would look like nothing happened.
        if info["LSBackgroundOnly"] as? Bool == true { return nil }

        return AppItem(
            name: displayName(for: url),
            url: url,
            bundleIdentifier: info["CFBundleIdentifier"] as? String,
            categoryType: info["LSApplicationCategoryType"] as? String
        )
    }

    /// The name Finder shows, in the user's language, without ".app".
    private static func displayName(for url: URL) -> String {
        let localized = (try? url.resourceValues(forKeys: [.localizedNameKey]))?.localizedName
        var name = localized ?? url.deletingPathExtension().lastPathComponent
        if name.hasSuffix(".app") {
            name = String(name.dropLast(4))
        }
        return name
    }
}
