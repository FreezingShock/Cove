//
//  AppItem.swift
//  Inlet
//
//  One installed app, as Inlet sees it.
//

import Foundation

/// A plain value describing one app on disk.
///
/// - `Identifiable` lets SwiftUI's `ForEach` tell items apart.
/// - `Hashable` lets us compare two scans to see if anything changed.
/// - `Sendable` means it is safe to build on a background thread and
///   hand to the main thread.
struct AppItem: Identifiable, Hashable, Sendable {
    /// The app's file path is unique on disk, so it doubles as the ID.
    var id: String { url.path }

    /// Name shown under the icon, e.g. "Safari" (no ".app").
    let name: String
    /// Location of the .app bundle, e.g. /Applications/Safari.app.
    let url: URL
    /// e.g. "com.apple.Safari". Used to drop duplicates. Can be nil for
    /// very old or unusual apps.
    let bundleIdentifier: String?
    /// The raw `LSApplicationCategoryType` from the app's Info.plist, e.g.
    /// "public.app-category.developer-tools". Nil when the app declares none.
    let categoryType: String?

    /// The preset this app's category suggests. Unknown or missing
    /// categories suggest `.other`. Used when the app is first installed.
    var category: AppCategory {
        AppCategory.bucket(forCategoryType: categoryType)
    }
}
