//
//  LayoutStore.swift
//  Inlet
//
//  Loads and saves the grid layout as JSON in Application Support, so the
//  order, folders and hidden apps survive a relaunch.
//

import Foundation
import Observation
import os

/// Holds the current `GridLayout` and saves it after every change.
///
/// - Views read `layout` and redraw when it changes.
/// - Changes go through `update(_:)`, which saves only when something differs.
/// - Pointer moves during a drag never touch disk: save on drop, not per frame.
@MainActor
@Observable
final class LayoutStore {
    private static let log = Logger(subsystem: "com.freezingshock.Inlet", category: "Layout")

    /// The layout as it is now.
    private(set) var layout = GridLayout()

    private let fileURL: URL

    /// Loads the saved layout, or starts empty if there is none yet.
    /// Pass a different `fileURL` in tests.
    init(fileURL: URL = LayoutStore.defaultFileURL()) {
        self.fileURL = fileURL
        self.layout = Self.load(from: fileURL)
    }

    /// `~/Library/Application Support/Inlet/layout.json`.
    /// Nonisolated because it only reads FileManager, so the init default
    /// argument can call it outside the main actor.
    nonisolated static func defaultFileURL() -> URL {
        let support = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return support
            .appendingPathComponent("Inlet", isDirectory: true)
            .appendingPathComponent("layout.json")
    }

    /// Applies one change and saves the result. The only way the layout changes.
    func update(_ change: (inout GridLayout) -> Void) {
        var next = layout
        change(&next)
        guard next != layout else { return }
        layout = next
        save()
    }

    /// Makes the saved layout match the installed apps. Call after each scan.
    func reconcile(with apps: [AppItem]) {
        update { $0 = $0.reconciled(with: apps) }
    }

    // MARK: - Disk

    /// Reads the file. A missing file means a first run. An unreadable file
    /// is moved aside (so nothing is lost) and the grid starts fresh.
    private static func load(from url: URL) -> GridLayout {
        guard FileManager.default.fileExists(atPath: url.path) else { return GridLayout() }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(GridLayout.self, from: data)
            guard decoded.version == GridLayout.currentVersion else {
                throw CocoaError(.fileReadUnknown)
            }
            return decoded
        } catch {
            log.error("Layout file unreadable, moving it aside: \(error.localizedDescription, privacy: .public)")
            let aside = url.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: url, to: aside)
            return GridLayout()
        }
    }

    /// Writes atomically, so a crash mid-save can't leave a half-written file.
    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(layout).write(to: fileURL, options: .atomic)
        } catch {
            Self.log.error("Could not save layout: \(error.localizedDescription, privacy: .public)")
        }
    }
}
