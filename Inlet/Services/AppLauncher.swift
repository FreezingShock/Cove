//
//  AppLauncher.swift
//  Inlet
//
//  Opens apps through macOS. Every successful launch is recorded in recents.
//

import AppKit

enum AppLauncher {
    /// Launches (or brings forward, if already running) the app.
    /// Shows an alert if macOS refuses, e.g. the app was deleted after
    /// the last scan or is damaged.
    ///
    /// - Parameter closesOverlay: Hide the overlay first, so the app comes up
    ///   with nothing in front of it. The grid passes its "Close after
    ///   launching" setting here.
    @MainActor
    static func launch(_ app: AppItem, closesOverlay: Bool = true) {
        if closesOverlay {
            OverlayController.shared.hide()
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true // bring the app to the front

        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { _, error in
            // The completion handler runs on a background thread. Recents and
            // alerts both need the main thread.
            guard let error else {
                // Only launches that worked count as recents.
                Task { @MainActor in
                    RecentsStore.shared.recordLaunch(of: app)
                }
                return
            }
            DispatchQueue.main.async {
                let alert = NSAlert(error: error)
                alert.messageText = "Couldn't open \(app.name)"
                alert.runModal()
            }
        }
    }
}
