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
    /// Handles Dock clicks (reopen) and opens the quick panel. See AppDelegate.swift.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // `Window` (instead of `WindowGroup`) gives exactly one main window,
        // which is what a launcher wants. Clicking the Dock icon reopens it.
        Window("Cove", id: "main") {
            AppGridView()
                .environment(library)        // hand the library to every view inside
                .preferredColorScheme(.dark) // Cove is always dark for now; Appearance settings come in 0.5
                .background(GridWindowBridge(delegate: appDelegate))
        }
        .defaultSize(width: CoveSize.gridWindowWidth, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CoveCommands(library: library)
        }
    }
}

/// Passes SwiftUI's `openWindow` action to the app delegate, so the delegate
/// can reopen the grid window from AppKit code (Show All Apps, grid Dock mode).
private struct GridWindowBridge: View {
    @Environment(\.openWindow) private var openWindow
    let delegate: AppDelegate

    var body: some View {
        Color.clear
            .onAppear {
                delegate.openGridWindow = { openWindow(id: "main") }
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
    }
}
