//
//  CoveApp.swift
//  Cove
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
struct CoveApp: App {
    /// Owns the app list, the overlay and Dock clicks. Stays alive for the whole run.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// The Sparkle updater. `@StateObject` (not `@State`) because it is a
    /// class that publishes changes, which the menu item watches.
    @StateObject private var updater = AppUpdater()

    /// Settings > General. Drives the menu bar icon, live: turning it off
    /// removes the icon without a relaunch.
    @AppStorage(CoveSettings.Key.showMenuBarIcon.rawValue) private var showMenuBarIcon = true

    /// Runs once at launch. Registers the global hotkeys (see HotkeyManager).
    /// Also starts crash collection, which only runs if the user opted in.
    @MainActor
    init() {
        // Give every setting its default before any window reads it.
        CoveSettings.registerDefaults()
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
            CoveCommands(library: appDelegate.library, updater: updater)
        }

        // Menu bar icon, on by default. `isInserted` adds or removes it as
        // the Settings toggle changes.
        MenuBarExtra("Cove", systemImage: "square.grid.3x3.fill", isInserted: menuBarInserted) {
            MenuBarMenu()
        }
    }

    /// Whether the menu bar icon is shown. Off inside unit tests: with the icon
    /// in the test host, CI stalled before the test runner connected.
    private var menuBarInserted: Binding<Bool> {
        Binding(
            get: { showMenuBarIcon && !CoveApp.isRunningUnitTests },
            set: { showMenuBarIcon = $0 }
        )
    }

    /// True inside the unit-test host. Xcode sets XCTestConfigurationFilePath.
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

/// The menu under the menu bar icon: open the grid, open Settings, quit.
struct MenuBarMenu: View {
    var body: some View {
        Button("Show Cove") {
            // The grid is the overlay now, not a window. AppDelegate brings it forward.
            (NSApp.delegate as? AppDelegate)?.showGrid()
        }

        // SettingsLink opens the same Settings scene as Cmd+, does.
        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Cove") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

/// Menu bar commands. Replaces File > New Window (meaningless for a
/// single-window app) with File > Reload Apps (Command-R).
struct CoveCommands: Commands {
    let library: AppLibrary
    let updater: AppUpdater

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Reload Apps") {
                library.reload()
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        // Adds "Check for Updates…" right after "About Cove" in the Cove menu.
        CommandGroup(after: .appInfo) {
            CheckForUpdatesButton(updater: updater)
        }

        // Replaces the default Help menu contents with one item that opens
        // the in-app feedback form. The form only opens GitHub in the browser.
        CommandGroup(replacing: .help) {
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
