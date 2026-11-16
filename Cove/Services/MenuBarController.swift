//
//  MenuBarController.swift
//  Cove
//
//  The menu bar icon, built with AppKit's NSStatusItem. Settings > General
//  shows or hides it, and the change takes effect at once.
//
//  This is not a SwiftUI MenuBarExtra. With that scene in the app, the CI
//  test host stalled before the test runner connected, so the icon is left
//  out while unit tests run.
//

import AppKit

@MainActor
final class MenuBarController: NSObject {

    static let shared = MenuBarController()

    /// The icon in the menu bar, or nil while it is hidden.
    private var statusItem: NSStatusItem?
    /// Watches UserDefaults so a Settings change shows or hides the icon.
    private var defaultsObserver: NSObjectProtocol?

    /// Starts the icon and keeps it in step with the Settings toggle.
    /// Call once at launch. Does nothing while unit tests run.
    func start() {
        guard !Self.isRunningUnitTests else { return }
        sync()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
    }

    /// True inside the unit-test host. Xcode sets XCTestConfigurationFilePath.
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Adds the icon when Settings wants it, and removes it when not.
    private func sync() {
        let wanted = UserDefaults.standard.bool(forKey: CoveSettings.Key.showMenuBarIcon.rawValue)
        if wanted, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                let image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "Cove")
                image?.isTemplate = true
                button.image = image
            }
            item.menu = makeMenu()
            statusItem = item
        } else if !wanted, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let show = NSMenuItem(title: "Show Cove", action: #selector(showCove), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Cove", action: #selector(quitCove), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func showCove() {
        // The grid is the overlay, not a window. AppDelegate brings it forward.
        (NSApp.delegate as? AppDelegate)?.showGrid()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // The same action Cmd+, sends, so the Settings scene opens.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitCove() {
        NSApp.terminate(nil)
    }
}
