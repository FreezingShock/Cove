//
//  CoveApp.swift
//  Cove
//
//  The entry point. `@main` tells Swift this is where the app starts.
//  A SwiftUI `App` describes its windows ("scenes") and menu commands;
//  macOS handles the rest (Dock icon, menu bar, window management).
//

import AppKit
import SwiftUI

@main
struct CoveApp: App {
    /// One shared list of installed apps for the whole program.
    /// `@State` keeps this object alive for as long as the app runs.
    @State private var library = AppLibrary()

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
        // `Window` (instead of `WindowGroup`) gives exactly one main window,
        // which is what a launcher wants. Clicking the Dock icon reopens it.
        Window("Cove", id: "main") {
            AppGridView()
                .environment(library)   // hand the library to every view inside
                .coveAppearance()       // Light, Dark or Auto, from Settings > Appearance
        }
        .defaultSize(width: CoveSize.gridWindowWidth, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CoveCommands(library: library)
        }

        // Settings window, opened by Cmd+, and the app menu.
        Settings {
            SettingsView()
                .environment(library)
        }

        // Menu bar icon, on by default. `isInserted` adds or removes it as
        // the Settings toggle changes.
        MenuBarExtra("Cove", systemImage: "square.grid.3x3.fill", isInserted: $showMenuBarIcon) {
            MenuBarMenu()
        }
    }
}

/// The menu under the menu bar icon: open the grid, open Settings, quit.
struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Cove") {
            openWindow(id: "main")
            // Bring Cove forward even when another app is active.
            NSApp.activate(ignoringOtherApps: true)
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
