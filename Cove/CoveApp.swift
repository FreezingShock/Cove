//
//  CoveApp.swift
//  Cove
//
//  The entry point. `@main` tells Swift this is where the app starts.
//  A SwiftUI `App` describes its windows ("scenes") and menu commands;
//  macOS handles the rest (Dock icon, menu bar, window management).
//
//  The grid is not a window. It is the full-screen overlay that
//  `OverlayController` owns, and `CoveAppDelegate` starts it.
//

import SwiftUI

@main
struct CoveApp: App {
    /// Owns the app list and the overlay. Stays alive for the whole run.
    @NSApplicationDelegateAdaptor(CoveAppDelegate.self) private var appDelegate

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
        }
        .commands {
            CoveCommands(library: appDelegate.library)
        }
    }
}

/// Starts the overlay at launch, and reopens it on a Dock click. Cove
/// stays resident after the overlay closes, so the next open is instant.
@MainActor
final class CoveAppDelegate: NSObject, NSApplicationDelegate {
    /// One shared list of installed apps for the whole program.
    let library = AppLibrary()

    func applicationDidFinishLaunching(_ notification: Notification) {
        OverlayController.shared.configure(library: library)
        // Scan once at launch. The overlay never scans on open (spec).
        library.reload()

        // Grid hotkey (Option+Space): the first press opens the overlay, the
        // second closes it.
        HotkeyManager.shared.onGridHotkey = {
            MainActor.assumeIsolated { OverlayController.shared.toggle() }
        }
        // Quick panel hotkey (Control+Option+Space). The quick panel itself
        // comes in 0.4; until then it opens the same overlay.
        HotkeyManager.shared.onQuickPanelHotkey = {
            MainActor.assumeIsolated { OverlayController.shared.toggle() }
        }

        OverlayController.shared.show()
    }

    /// A Dock click reopens the overlay. (0.4 changes this to the quick panel.)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        OverlayController.shared.show()
        return false
    }

    /// Keep running with the overlay hidden.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// Menu bar commands. Replaces File > New Window (meaningless for a
/// single-window app) with File > Reload Apps (Command-R).
struct CoveCommands: Commands {
    let library: AppLibrary

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Reload Apps") {
                library.reload()
            }
            .keyboardShortcut("r", modifiers: .command)
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
