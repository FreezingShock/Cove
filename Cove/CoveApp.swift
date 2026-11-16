//
//  CoveApp.swift
//  Cove
//
//  The entry point. `@main` tells Swift this is where the app starts.
//  A SwiftUI `App` describes its windows ("scenes") and menu commands;
//  macOS handles the rest (Dock icon, menu bar, window management).
//

import SwiftUI

@main
struct CoveApp: App {
    /// Owns the app list and the overlay. Stays alive for the whole run.
    @NSApplicationDelegateAdaptor(CoveAppDelegate.self) private var appDelegate

    var body: some Scene {
        // Cove's UI is the full-screen overlay, which the delegate owns.
        // This placeholder scene is here only because an App needs a scene.
        // The Settings window replaces it in 0.5.
        Settings {
            EmptyView()
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
    }
}
