//
//  AppDelegate.swift
//  Cove
//
//  Handles what happens when the Dock icon is clicked while Cove is running.
//  SwiftUI can't do this part by itself, so it lives in an AppKit delegate.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opens the full grid window. CoveApp sets this once the window's
    /// `openWindow` action is available.
    var openGridWindow: (() -> Void)?

    override init() {
        super.init()
        QuickPanelController.shared.onShowAll = { [weak self] in
            self?.showGrid()
        }
    }

    /// Called when the app is reopened: a Dock click, or launching it again
    /// from Finder. Returning `false` tells AppKit we handled it ourselves.
    /// See applicationShouldHandleReopen(_:hasVisibleWindows:) in Apple's docs.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        switch CoveSettings.dockClickAction {
        case .quickPanel:
            QuickPanelController.shared.toggle()
        case .grid:
            showGrid()
        }
        return false
    }

    /// Brings the grid to the front, opening it if it was closed.
    func showGrid() {
        NSApp.activate(ignoringOtherApps: true)
        openGridWindow?()
    }
}
