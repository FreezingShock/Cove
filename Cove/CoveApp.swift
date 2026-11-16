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
    /// One shared list of installed apps for the whole program.
    /// `@State` keeps this object alive for as long as the app runs.
    @State private var library = AppLibrary()

    /// Runs once at launch. Registers the global hotkeys (see HotkeyManager).
    /// Also starts crash collection, which only runs if the user opted in.
    @MainActor
    init() {
        HotkeyManager.shared.start()
        // Starts crash collection only if the user has opted in. Off by default.
        DiagnosticsCollector.shared.startIfEnabled()
    }

    var body: some Scene {
        // `Window` (instead of `WindowGroup`) gives exactly one main window,
        // which is what a launcher wants. Clicking the Dock icon reopens it.
        Window("Cove", id: "main") {
            AppGridView()
                .environment(library)        // hand the library to every view inside
                .preferredColorScheme(.dark) // Cove is always dark for now; Appearance settings come in 0.5
        }
        .defaultSize(width: CoveSize.gridWindowWidth, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CoveCommands(library: library)
        }
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
