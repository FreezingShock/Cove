//
//  InletSettings.swift
//  Inlet
//
//  The one list of settings keys and defaults for the whole app.
//
//  Settings are stored in UserDefaults. SwiftUI views read them with
//  `@AppStorage(InletSettings.Key.gridColumns.rawValue)`. Code that is not
//  a view (the hotkey, the overlay, the search service) reads them with
//  `UserDefaults.standard`, using the same keys and the typed helpers below.
//
//  Rules for everyone:
//  - Add a key here, never a string literal somewhere else.
//  - Keep the default in `registerDefaults()`, so a read before the
//    Settings window has ever opened still returns the right value.
//  - Call `InletSettings.registerDefaults()` once at launch (InletApp does this).
//

import Foundation

enum InletSettings {

    /// Every stored setting. The raw value is the UserDefaults key.
    /// Keys start with "inlet." so they never collide with system keys.
    enum Key: String, CaseIterable {
        // General
        case showMenuBarIcon          = "inlet.general.showMenuBarIcon"          // Bool, true
        case closeAfterLaunch         = "inlet.general.closeAfterLaunch"         // Bool, true
        case escapeClearsSearchFirst  = "inlet.general.escapeClearsSearchFirst"  // Bool, true
        case rememberLastGroup        = "inlet.general.rememberLastCategory"     // Bool, true (key kept from v1)

        // Appearance: "auto", "light" or "dark"
        case appearance               = "inlet.appearance.mode"                  // String, "auto"

        // Grid
        case gridColumns              = "inlet.grid.columns"                     // Int, 5...9, 7
        case lastGroup                = "inlet.grid.lastCategory"                // String, a group id, "" for All (key kept from v1)
        case pinchToOpen              = "inlet.grid.pinchToOpen"                 // Bool, true
        case hotCorner                = "inlet.grid.hotCorner"                   // String, a HotCorner raw value, "off"
        case f4Opens                  = "inlet.grid.f4Opens"                     // Bool, true

        // Search
        case searchIncludesFiles      = "inlet.search.includeFiles"              // Bool, true
        case searchFileResultCount    = "inlet.search.fileResultCount"           // Int, 0...8, 5

        // Quick Panel
        case dockClickOpens           = "inlet.quickPanel.dockClickOpens"        // String, "quickPanel" or "grid"
        case quickPanelRecentApps     = "inlet.quickPanel.recentApps"            // Int, 4, 8 or 12, 8
        case quickPanelRecentFiles    = "inlet.quickPanel.recentFiles"           // Int, 0...5, 3

        // Privacy
        case diagnosticsEnabled       = "inlet.diagnostics.enabled"              // Bool, false
        // Supporter: custom themes and zones. Honor-based gate, see Supporter.swift
        case supporterActive          = "inlet.supporter.active"                 // Bool, false
        case activeTheme              = "inlet.themes.active"                    // String, an AppTheme id, "inlet"
        case customThemes             = "inlet.themes.custom"                    // Data, JSON [AppTheme]
        case zones                    = "inlet.zones"                            // Data, JSON [GridZone]
    }

    /// Values for `Appearance`. Stored as the raw string.
    enum AppearanceMode: String, CaseIterable {
        case auto, light, dark
    }

    /// Values for "Dock click opens".
    enum DockClickAction: String, CaseIterable {
        case quickPanel, grid
    }

    /// Defaults for every key. Call once at launch.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.showMenuBarIcon.rawValue: true,
            Key.closeAfterLaunch.rawValue: true,
            Key.escapeClearsSearchFirst.rawValue: true,
            Key.rememberLastGroup.rawValue: true,
            Key.appearance.rawValue: AppearanceMode.auto.rawValue,
            Key.gridColumns.rawValue: 7,
            Key.lastGroup.rawValue: "",
            Key.pinchToOpen.rawValue: true,
            Key.hotCorner.rawValue: HotCorner.off.rawValue,
            Key.f4Opens.rawValue: true,
            Key.searchIncludesFiles.rawValue: true,
            Key.searchFileResultCount.rawValue: 5,
            Key.dockClickOpens.rawValue: DockClickAction.quickPanel.rawValue,
            Key.quickPanelRecentApps.rawValue: 8,
            Key.quickPanelRecentFiles.rawValue: 3,
            Key.diagnosticsEnabled.rawValue: false,
            Key.supporterActive.rawValue: false,
            Key.activeTheme.rawValue: AppTheme.standard.id,
        ])
        // Theme colors and sizes are read by the tokens on every draw, so the
        // saved theme has to be loaded before the first window opens.
        ThemeRuntime.loadFromDefaults()
    }

    // MARK: - Typed reads for non-view code

    static var gridColumns: Int {
        clamp(UserDefaults.standard.integer(forKey: Key.gridColumns.rawValue), 5...9, fallback: 7)
    }

    /// The group to open the grid on: the last one the user picked, when
    /// "Remember the last group" is on. Nil means All. The grid checks that
    /// the group still exists.
    static var startingGroupID: String? {
        guard UserDefaults.standard.bool(forKey: Key.rememberLastGroup.rawValue) else { return nil }
        let raw = UserDefaults.standard.string(forKey: Key.lastGroup.rawValue) ?? ""
        return raw.isEmpty ? nil : raw
    }

    /// Saves the group the user picked. Nil (All) is stored as an empty string.
    static func saveLastGroup(_ groupID: String?) {
        UserDefaults.standard.set(groupID ?? "", forKey: Key.lastGroup.rawValue)
    }

    static var searchIncludesFiles: Bool {
        UserDefaults.standard.bool(forKey: Key.searchIncludesFiles.rawValue)
    }

    static var searchFileResultCount: Int {
        clamp(UserDefaults.standard.integer(forKey: Key.searchFileResultCount.rawValue), 0...8, fallback: 5)
    }

    static var dockClickAction: DockClickAction {
        let raw = UserDefaults.standard.string(forKey: Key.dockClickOpens.rawValue) ?? ""
        return DockClickAction(rawValue: raw) ?? .quickPanel
    }

    static var quickPanelRecentApps: Int {
        let value = UserDefaults.standard.integer(forKey: Key.quickPanelRecentApps.rawValue)
        return [4, 8, 12].contains(value) ? value : 8
    }

    static var quickPanelRecentFiles: Int {
        clamp(UserDefaults.standard.integer(forKey: Key.quickPanelRecentFiles.rawValue), 0...5, fallback: 3)
    }

    static var pinchToOpen: Bool {
        UserDefaults.standard.bool(forKey: Key.pinchToOpen.rawValue)
    }

    static var hotCorner: HotCorner {
        let raw = UserDefaults.standard.string(forKey: Key.hotCorner.rawValue) ?? ""
        return HotCorner(rawValue: raw) ?? .off
    }

    static var f4Opens: Bool {
        UserDefaults.standard.bool(forKey: Key.f4Opens.rawValue)
    }

    static var closeAfterLaunch: Bool {
        UserDefaults.standard.bool(forKey: Key.closeAfterLaunch.rawValue)
    }

    static var escapeClearsSearchFirst: Bool {
        UserDefaults.standard.bool(forKey: Key.escapeClearsSearchFirst.rawValue)
    }

    /// Crash reporting is opt-in. Read at launch by DiagnosticsCollector.
    static var diagnosticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.diagnosticsEnabled.rawValue)
    }

    static var appearance: AppearanceMode {
        let raw = UserDefaults.standard.string(forKey: Key.appearance.rawValue) ?? ""
        return AppearanceMode(rawValue: raw) ?? .auto
    }

    // MARK: - Helpers

    /// Keeps a stored number inside its allowed range. A value that was never
    /// written reads as 0, so 0 also falls back to the default.
    private static func clamp(_ value: Int, _ range: ClosedRange<Int>, fallback: Int) -> Int {
        guard value != 0 else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

extension Notification.Name {
    /// Posted when the user confirms Settings > Privacy > Erase Launch History.
    /// Any store that keeps launch history (recent apps, recent files) should
    /// observe this and clear itself.
    static let inletEraseLaunchHistory = Notification.Name("inlet.eraseLaunchHistory")
}
