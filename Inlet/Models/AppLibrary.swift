//
//  AppLibrary.swift
//  Inlet
//
//  Holds the list of installed apps and refreshes it. Views read from
//  this object and redraw automatically when `apps` changes.
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

    /// True when a reload was asked for during a scan. The scan that is
    /// running may have read the folders before the change, so one more runs after it.
    private var reloadQueued = false

    /// Rescans the app folders in the background.
    /// Safe to call often: a request during a scan is queued, not dropped,
    /// so an app installed mid-scan still shows up.
    func reload() {
        guard !isScanning else {
            reloadQueued = true
            return
        }
        isScanning = true

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

            if reloadQueued {
                reloadQueued = false
                reload()
            }
        }
    }
}
