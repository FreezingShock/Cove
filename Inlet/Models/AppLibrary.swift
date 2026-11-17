//
//  AppLibrary.swift
//  Inlet
//
//  Holds the list of installed apps and refreshes it. Views read from
//  this object and redraw automatically when `apps` changes. A file-system
//  watcher asks for a rescan whenever an app is added, removed or renamed.
//

import Foundation
import Observation

/// `@Observable` makes SwiftUI watch this object's properties.
/// `@MainActor` means its properties are only touched on the main thread,
/// which is where all UI work happens.
@MainActor
@Observable
final class AppLibrary {
    /// Every app found, sorted by name.
    private(set) var apps: [AppItem] = []
    /// True while a scan is running.
    private(set) var isScanning = false
    /// True once the first scan has finished (so we can tell "still
    /// loading" apart from "found nothing").
    private(set) var hasScanned = false
    /// When the last scan finished. Shown in Settings > About.
    private(set) var lastScanned: Date?

    /// Set when a change arrives during a scan. The scan that is running
    /// may have read the folders before the change, so one more scan runs
    /// after it. Without this the change would wait for the next launch.
    @ObservationIgnored private var rescanRequested = false
    @ObservationIgnored private var watcher: AppFolderWatcher?

    /// Starts watching the app folders. Call once at launch, after the first
    /// `reload()`. Folders that don't exist yet (such as ~/Applications) are
    /// picked up at the next launch.
    func startWatching() {
        guard watcher == nil else { return }
        let watcher = AppFolderWatcher(paths: AppScanner.existingSearchFolderPaths) { [weak self] in
            self?.reload()
        }
        watcher.start()
        self.watcher = watcher
    }

    /// Rescans the app folders in the background.
    /// Safe to call often: if a scan is already running, the next one is queued
    /// (one extra scan at most, however many calls arrive).
    func reload() {
        guard !isScanning else {
            rescanRequested = true
            return
        }
        isScanning = true
        rescanRequested = false

        Task {
            // Scanning touches the disk, so run it off the main thread
            // to keep the window responsive.
            let found = await Task.detached(priority: .userInitiated) {
                AppScanner.scanInstalledApps()
            }.value

            // Only assign when something changed, so the grid doesn't
            // redraw for nothing every time the window is focused.
            if found != apps {
                apps = found
            }
            isScanning = false
            hasScanned = true
            lastScanned = Date()

            if rescanRequested {
                reload()
            }
        }
    }
}
