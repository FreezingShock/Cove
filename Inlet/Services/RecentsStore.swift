//
//  RecentsStore.swift
//  Inlet
//
//  Remembers the apps launched through Inlet, newest first, and saves the
//  list as JSON in Application Support so it survives a relaunch.
//  Recent files are a separate source (see `RecentFiles` below).
//

import AppKit
import Foundation
import Observation

/// One app Inlet has launched. Stored as a path, so it can be rebuilt into an
/// `AppItem` later. Apps that have been deleted since are skipped on read.
struct RecentApp: Codable, Hashable, Sendable {
    let name: String
    let path: String
    let bundleIdentifier: String?
    /// e.g. "public.app-category.productivity". Optional, so files from before this field still load.
    let categoryType: String?
    let launchedAt: Date

    var appItem: AppItem {
        AppItem(
            name: name,
            url: URL(fileURLWithPath: path),
            bundleIdentifier: bundleIdentifier,
            categoryType: categoryType
        )
    }
}

/// The file on disk. `version` leaves room to change the format later.
private struct RecentsFile: Codable {
    var version: Int
    var apps: [RecentApp]
}

/// Holds recent apps for the whole program. Main-actor only, like the UI that reads it.
@MainActor
@Observable
final class RecentsStore {
    /// The one store the app uses. Launches and the Privacy pane both go through it.
    static let shared = RecentsStore()

    /// Keep this many launches on disk. The quick panel shows at most 12.
    static let maxStored = 24

    /// Newest first.
    private(set) var apps: [RecentApp] = []

    private let fileURL: URL

    private init() {
        self.fileURL = RecentsStore.defaultFileURL()
        self.apps = loadFromDisk()

        // Settings > Privacy > Erase Launch History posts this notification.
        // Listening here keeps Settings from depending on the recents store.
        NotificationCenter.default.addObserver(
            forName: .inletEraseLaunchHistory,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clear()
            }
        }
    }

    /// ~/Library/Application Support/Inlet/recents.json
    private static func defaultFileURL() -> URL {
        let support = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("Inlet", isDirectory: true)
            .appendingPathComponent("recents.json")
    }

    /// Called after an app opens successfully through Inlet.
    func recordLaunch(of app: AppItem, at date: Date = .now) {
        // Move an app that is already listed to the top instead of listing it twice.
        apps.removeAll { $0.path == app.url.path }
        apps.insert(
            RecentApp(
                name: app.name,
                path: app.url.path,
                bundleIdentifier: app.bundleIdentifier,
                categoryType: app.categoryType,
                launchedAt: date
            ),
            at: 0
        )
        if apps.count > Self.maxStored {
            apps.removeLast(apps.count - Self.maxStored)
        }
        save()
    }

    /// The newest launches whose app is still on disk, up to `limit`.
    func recentAppItems(limit: Int) -> [AppItem] {
        var result: [AppItem] = []
        for recent in apps where result.count < limit {
            if FileManager.default.fileExists(atPath: recent.path) {
                result.append(recent.appItem)
            }
        }
        return result
    }

    /// Clears the list in memory and deletes the file. Used by Privacy > Erase launch history.
    func clear() {
        apps = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Convenience for the Privacy pane: `RecentsStore.eraseAll()`.
    static func eraseAll() {
        shared.clear()
    }

    // MARK: - Disk

    private func loadFromDisk() -> [RecentApp] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            let file = try makeDecoder().decode(RecentsFile.self, from: data)
            return file.apps
        } catch {
            // A damaged file shouldn't stop the app. The next save replaces it.
            NSLog("Inlet: couldn't read recents, starting empty: %@", error.localizedDescription)
            return []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(RecentsFile(version: 1, apps: apps))
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // `.atomic` writes to a temp file first, so a crash can't leave half a file.
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Inlet: couldn't save recents: %@", error.localizedDescription)
        }
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// A file someone opened recently, shown in the quick panel.
struct RecentFile: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let name: String
    let url: URL
}

/// Recent files for the quick panel.
/// TEMPORARY STUB: returns nothing until the Spotlight service (PR #5,
/// `FileSearch.recentFiles(limit:)`) merges. Then this body is replaced by a call to it.
enum RecentFiles {
    static func recent(limit: Int) async -> [RecentFile] {
        _ = limit
        return []
    }
}
