//
//  AppLauncher.swift
//  Cove
//
//  Opens apps through macOS.
//

import AppKit

enum AppLauncher {
    /// Launches (or brings forward, if already running) the app.
    /// Shows an alert if macOS refuses, e.g. the app was deleted after
    /// the last scan or is damaged.
    static func launch(_ app: AppItem) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true // bring the app to the front

        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { _, error in
            guard let error else { return }
            // The completion handler runs on a background thread;
            // alerts must be shown on the main thread.
            DispatchQueue.main.async {
                let alert = NSAlert(error: error)
                alert.messageText = "Couldn't open \(app.name)"
                alert.runModal()
            }
        }
    }
}
