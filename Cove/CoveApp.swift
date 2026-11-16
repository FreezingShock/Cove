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

    /// The Sparkle updater. `@StateObject` (not `@State`) because it is a
    /// class that publishes changes, which the menu item watches.
    @StateObject private var updater = AppUpdater()

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
                .background(GridWindowBridge(delegate: appDelegate))
                // Opens first-run setup once, until the user finishes it.
                .onAppear { OnboardingWindowController.showOnFirstLaunch() }
        }
        .defaultSize(width: CoveSize.gridWindowWidth, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CoveCommands(library: library, updater: updater)
        }

        // Settings window, opened by Cmd+, and the app menu.
        Settings {
            SettingsView()
                .environment(library)
                .environmentObject(updater)
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
            Button("Cove Setup…") {
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
