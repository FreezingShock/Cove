//
//  IconCache.swift
//  Cove
//
//  Gets each app's real icon from macOS and remembers it, so scrolling
//  the grid doesn't ask the system for the same icon twice.
//

import AppKit

@MainActor
final class IconCache {
    static let shared = IconCache()

    /// `NSCache` drops entries on its own if the Mac runs low on memory.
    private let cache = NSCache<NSString, NSImage>()

    private init() {}

    /// The app's own icon exactly as Finder and the Dock show it.
    /// Cove never draws its own icons for other apps.
    func icon(for app: AppItem) -> NSImage {
        let key = app.url.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: app.url.path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}
