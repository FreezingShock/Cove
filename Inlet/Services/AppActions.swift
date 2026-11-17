//
//  AppActions.swift
//  Inlet
//
//  The actions in an app's right-click menu. Kept here so the menu, and any
//  future caller, does the same thing for each action.
//

import AppKit

@MainActor
enum AppActions {

    /// Selects the app in a Finder window.
    static func showInFinder(_ app: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([app.url])
    }

    /// Puts the app's file path on the clipboard.
    static func copyPath(_ app: AppItem) {
        copy(app.url.path)
    }

    /// Puts the app's bundle identifier (e.g. com.apple.Safari) on the clipboard.
    /// Does nothing for an app without one.
    static func copyBundleIdentifier(_ app: AppItem) {
        guard let identifier = app.bundleIdentifier else { return }
        copy(identifier)
    }

    /// Replaces the clipboard contents with plain text.
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// The running copy of this app, or nil when it is not running.
    /// Matched by bundle path, so it also works for apps without an identifier.
    static func runningApplication(for app: AppItem) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleURL?.path == app.url.path }
    }

    /// Asks the running app to quit, the same as Quit in its own menu, so
    /// it can save its work first.
    static func quit(_ app: AppItem) {
        runningApplication(for: app)?.terminate()
    }
}
