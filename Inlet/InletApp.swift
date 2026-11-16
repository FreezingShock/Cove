//
//  InletApp.swift
//  Inlet
//
//  The entry point. `@main` tells Swift this is where the app starts.
//  A SwiftUI `App` describes its windows ("scenes") and menu commands;
//  macOS handles the rest (Dock icon, menu bar, window management).
//
//  The grid is not a window. It is the full-screen overlay that
//  `OverlayController` owns, and `AppDelegate` starts it.
//

import AppKit
import SwiftUI

@main
struct InletApp: App {
    /// Owns the app list, the overlay and Dock clicks. Stays alive for the whole run.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// The Sparkle updater. `@StateObject` (not `@State`) because it is a
    /// class that publishes changes, which the menu item watches.
    @StateObject private var updater = AppUpdater()

    /// Runs once at launch. Registers the global hotkeys (see HotkeyManager).
    /// Also starts crash collection, which only runs if the user opted in.
    @MainActor
    init() {
        // Give every setting its default before any window reads it.
        InletSettings.registerDefaults()
        HotkeyManager.shared.start()
        // Starts crash collection only if the user has opted in. Off by default.
        DiagnosticsCollector.shared.startIfEnabled()
    }

    var body: some Scene {
        // Settings window, opened by Cmd+, and the app menu.
        Settings {
            SettingsView()
                .environment(appDelegate.library)
                .environmentObject(updater)
        }
        .commands {
            InletCommands(library: appDelegate.library, updater: updater)
        }

        // The menu bar icon is an NSStatusItem, started by AppDelegate.
        // See MenuBarController for why it is not a MenuBarExtra scene.
    }
}

/// Menu bar commands. Replaces File > New Window (meaningless for a
/// single-window app) with File > Reload Apps (Command-R).
struct InletCommands: Commands {
    let library: AppLibrary
    let updater: AppUpdater

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Reload Apps") {
                library.reload()
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        // Adds "Check for Updates…" right after "About Inlet" in the Inlet menu.
        CommandGroup(after: .appInfo) {
            CheckForUpdatesButton(updater: updater)
        }

        // Replaces the default Help menu contents with one item that opens
        // the in-app feedback form. The form only opens GitHub in the browser.
        CommandGroup(replacing: .help) {
            Button("Inlet Setup…") {
                OnboardingWindowController.shared.show()
            }
            Button("Send Feedback…") {
                FeedbackWindow.shared.show()
            }
        }
    }
}

/// Its own View so SwiftUI redraws the disabled state when Sparkle's
/// `canCheckForUpdates` changes. Menu items are not redrawn by themselves.
struct CheckForUpdatesButton: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
