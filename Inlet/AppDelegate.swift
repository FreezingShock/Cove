//
//  AppDelegate.swift
//  Inlet
//
//  The one AppKit delegate. It starts the grid overlay at launch, handles
//  what happens when the Dock icon is clicked (quick panel or grid, from
//  Settings), and wires the global hotkeys. SwiftUI can't do these parts
//  by itself, so they live here.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// One shared list of installed apps for the whole program.
    let library = AppLibrary()
    /// The saved grid layout (order, hidden apps), saved to Application Support.
    let layoutStore = LayoutStore()

    override init() {
        super.init()
        // "Show All Apps" in the quick panel opens the full grid overlay.
        QuickPanelController.shared.onShowAll = { [weak self] in
            self?.showGrid()
        }
    }

    /// Builds the overlay and starts the first scan. Runs once at launch.
    func applicationDidFinishLaunching(_ notification: Notification) {
        OverlayController.shared.configure(library: library, layoutStore: layoutStore)
        // Scan once at launch. The overlay never scans on open (spec).
        library.reload()

        // Grid hotkey (Option+Space) toggles the full grid overlay: the first
        // press opens it, the second closes it.
        HotkeyManager.shared.onGridHotkey = {
            MainActor.assumeIsolated {
                InletSignpost.beginHotkeyToVisible()
                OverlayController.shared.toggle()
            }
        }
        // Quick panel hotkey (Control+Option+Space) toggles the quick panel.
        HotkeyManager.shared.onQuickPanelHotkey = {
            MainActor.assumeIsolated { QuickPanelController.shared.toggle() }
        }

        // Menu bar icon, shown or hidden by Settings > General.
        MenuBarController.shared.start()

        // Pinch in on the desktop, and a hot corner, also open the grid.
        OpenTriggers.shared.start()

        OverlayController.shared.show()

        // First-run setup opens once, until the user finishes it. It is also
        // reachable from Help > Inlet Setup…
        OnboardingWindowController.showOnFirstLaunch()
    }

    /// Called when the app is reopened: a Dock click, or launching it again
    /// from Finder. Returning `false` tells AppKit we handled it ourselves.
    /// See applicationShouldHandleReopen(_:hasVisibleWindows:) in Apple's docs.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        switch InletSettings.dockClickAction {
        case .quickPanel:
            QuickPanelController.shared.toggle()
        case .grid:
            showGrid()
        }
        return false
    }

    /// Keep running with the overlay hidden.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Brings the grid overlay to the front, opening it if it was closed.
    func showGrid() {
        NSApp.activate(ignoringOtherApps: true)
        OverlayController.shared.show()
    }
}
