//
//  SettingsPanes.swift
//  Inlet
//
//  One view per Settings pane. Each is a grouped Form. Every control writes
//  to an InletSettings key (or, for login, to the system), so the grid,
//  search and quick panel read the same values the moment they change.
//

import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

// MARK: - Login item

/// Inlet's login item is owned by macOS, so it is read live and never
/// stored in UserDefaults.
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// Registers or unregisters Inlet as a login item. Throws if macOS refuses.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// The words shown for the current state.
    static func label(for status: SMAppService.Status) -> String {
        switch status {
        case .enabled:          return "On"
        case .requiresApproval: return "Needs approval"
        default:                return "Off"
        }
    }
}

// MARK: - General

struct GeneralPane: View {
    @AppStorage(InletSettings.Key.showMenuBarIcon.rawValue) private var showMenuBarIcon = true
    @AppStorage(InletSettings.Key.closeAfterLaunch.rawValue) private var closeAfterLaunch = true
    @AppStorage(InletSettings.Key.escapeClearsSearchFirst.rawValue) private var escapeClearsSearchFirst = true
    @AppStorage(InletSettings.Key.rememberLastGroup.rawValue) private var rememberLastGroup = true
    @AppStorage(InletSettings.Key.pinchToOpen.rawValue) private var pinchToOpen = true
    @AppStorage(InletSettings.Key.f4Opens.rawValue) private var f4Opens = true
    @AppStorage(InletSettings.Key.hotCorner.rawValue) private var hotCornerRaw = HotCorner.off.rawValue

    @State private var loginStatus = LoginItem.status
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: openAtLogin)
                if loginStatus == .requiresApproval {
                    Button("Open Login Items Settings…") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
            } footer: {
                Text(loginFooter)
            }

            Section {
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            }

            Section {
                Toggle("Close after launching an app", isOn: $closeAfterLaunch)
                Toggle("Escape clears the search first", isOn: $escapeClearsSearchFirst)
                Toggle("Remember the last group", isOn: $rememberLastGroup)
            }

            Section {
                Toggle("Pinch in on the desktop to open", isOn: $pinchToOpen)
                Toggle("F4 opens the grid", isOn: $f4Opens)
                    .onChange(of: f4Opens) { _, enabled in
                        HotkeyManager.shared.setF4Enabled(enabled)
                    }
                Picker("Hot corner", selection: $hotCornerRaw) {
                    ForEach(HotCorner.allCases, id: \.rawValue) { corner in
                        Text(corner.title).tag(corner.rawValue)
                    }
                }
            } header: {
                Text("Opening the grid")
            } footer: {
                Text("Pinch in works while Finder is the front app, so a pinch in Safari never opens Inlet. Spread out closes the grid. A hot corner opens it when the pointer rests in that corner.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onAppear(perform: refreshLoginStatus)
        // The user may approve the login item in System Settings and come back.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLoginStatus()
        }
    }

    private var loginFooter: String {
        if let loginError { return loginError }
        if loginStatus == .requiresApproval {
            return "Allow Inlet in System Settings > General > Login Items."
        }
        return "Inlet opens when you log in to your Mac."
    }

    private func refreshLoginStatus() {
        loginStatus = LoginItem.status
    }

    private var openAtLogin: Binding<Bool> {
        Binding(
            get: { loginStatus == .enabled },
            set: { wantsOn in
                do {
                    try LoginItem.setEnabled(wantsOn)
                    loginError = nil
                } catch {
                    loginError = "Couldn't change the login item: \(error.localizedDescription)"
                }
                refreshLoginStatus()
            }
        )
    }
}

// MARK: - Appearance

struct AppearancePane: View {
    @AppStorage(InletSettings.Key.appearance.rawValue)
    private var appearance = InletSettings.AppearanceMode.auto.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearance) {
                    Text("Light").tag(InletSettings.AppearanceMode.light.rawValue)
                    Text("Dark").tag(InletSettings.AppearanceMode.dark.rawValue)
                    Text("Auto").tag(InletSettings.AppearanceMode.auto.rawValue)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Auto follows Appearance in System Settings. Applies to the grid and this window.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}

// MARK: - Shortcuts

struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section {
                HotkeyRecorderRow(title: "Show all apps", name: .showGrid)
                HotkeyRecorderRow(title: "Quick panel", name: .showQuickPanel)
            } footer: {
                Text("Press a new shortcut to change it. Esc cancels. A shortcut that another app uses is refused.")
            }

            Section {
                Button("Restore Default Shortcuts") {
                    KeyboardShortcuts.reset(.showGrid, .showQuickPanel)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shortcuts")
    }
}

// MARK: - Grid

struct GridPane: View {
    @AppStorage(InletSettings.Key.gridColumns.rawValue) private var gridColumns = 7

    var body: some View {
        Form {
            Section {
                Stepper(value: $gridColumns, in: 5...9) {
                    LabeledContent("Columns", value: "\(gridColumns)")
                }
            } footer: {
                Text("The grid changes as soon as you adjust this, including the opening animation.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Grid")
    }
}

// MARK: - Hidden Apps

struct HiddenAppsPane: View {
    @Environment(AppLibrary.self) private var library
    @Environment(LayoutStore.self) private var layoutStore

    var body: some View {
        Form {
            Section {
                if layoutStore.layout.hidden.isEmpty {
                    Text("No hidden apps")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(layoutStore.layout.hidden, id: \.appID) { hidden in
                        LabeledContent {
                            Button("Restore") {
                                layoutStore.update { $0.restoreApp(hidden.appID) }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if let app = app(for: hidden.appID) {
                                    Image(nsImage: IconCache.shared.icon(for: app))
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                Text(name(for: hidden.appID))
                            }
                        }
                    }
                }
            } footer: {
                Text("Hide an app from the grid in Edit mode. Restore puts it back where it was. Apple's own apps can't be hidden.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Hidden Apps")
    }

    private func app(for appID: String) -> AppItem? {
        library.apps.first { $0.id == appID }
    }

    /// Falls back to the file name when the app is no longer installed.
    private func name(for appID: String) -> String {
        app(for: appID)?.name ?? URL(fileURLWithPath: appID).deletingPathExtension().lastPathComponent
    }
}

// MARK: - Search

struct SearchPane: View {
    @AppStorage(InletSettings.Key.searchIncludesFiles.rawValue) private var includeFiles = true
    @AppStorage(InletSettings.Key.searchFileResultCount.rawValue) private var fileResultCount = 5

    var body: some View {
        Form {
            Section {
                Toggle("Include files", isOn: $includeFiles)
                Stepper(value: $fileResultCount, in: 0...8) {
                    LabeledContent("File results", value: "\(fileResultCount)")
                }
                .disabled(!includeFiles)
            } footer: {
                Text("Files come from Spotlight. Inlet keeps no index of its own.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Search")
    }
}

// MARK: - Quick Panel

struct QuickPanelPane: View {
    @AppStorage(InletSettings.Key.dockClickOpens.rawValue)
    private var dockClickOpens = InletSettings.DockClickAction.quickPanel.rawValue
    @AppStorage(InletSettings.Key.quickPanelRecentApps.rawValue) private var recentApps = 8
    @AppStorage(InletSettings.Key.quickPanelRecentFiles.rawValue) private var recentFiles = 3

    var body: some View {
        Form {
            Section {
                Picker("Dock click opens", selection: $dockClickOpens) {
                    Text("Quick Panel").tag(InletSettings.DockClickAction.quickPanel.rawValue)
                    Text("Full Grid").tag(InletSettings.DockClickAction.grid.rawValue)
                }
            }

            Section {
                Picker("Recent apps", selection: $recentApps) {
                    Text("4").tag(4)
                    Text("8").tag(8)
                    Text("12").tag(12)
                }
                .pickerStyle(.segmented)

                Stepper(value: $recentFiles, in: 0...5) {
                    LabeledContent("Recent files", value: "\(recentFiles)")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Quick Panel")
    }
}

// MARK: - Privacy & Permissions

struct PrivacyPane: View {
    @AppStorage(InletSettings.Key.diagnosticsEnabled.rawValue) private var diagnostics = false

    @State private var loginStatus = LoginItem.status
    @State private var reportCount = DiagnosticStore.shared.all().count
    @State private var confirmEraseHistory = false
    @State private var confirmEraseReports = false

    var body: some View {
        Form {
            // Permission rows. Inlet currently requests no privacy permission
            // (no Accessibility, Screen Recording, Input Monitoring or Full Disk
            // Access prompt in the code), so only the login item is shown.
            Section {
                LabeledContent("Open at login", value: LoginItem.label(for: loginStatus))
                if loginStatus == .requiresApproval {
                    Button("Open Login Items Settings…") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Inlet asks for no privacy permissions. Everything runs on this Mac.")
            }

            Section {
                Toggle("Collect crash reports", isOn: $diagnostics)
                LabeledContent("Saved reports", value: "\(reportCount)")
                Button("Erase Reports…", role: .destructive) {
                    confirmEraseReports = true
                }
                .disabled(reportCount == 0)
            } header: {
                Text("Crash Reports")
            } footer: {
                Text("Off by default. Reports stay on this Mac, up to 20, and nothing is uploaded. A change takes effect the next time Inlet opens.")
            }

            Section {
                Button("Erase Launch History…", role: .destructive) {
                    confirmEraseHistory = true
                }
            } header: {
                Text("History")
            } footer: {
                Text("Clears Recent Apps and Recent Files. This is the only history Inlet keeps.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy & Permissions")
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        .confirmationDialog(
            "Erase launch history?",
            isPresented: $confirmEraseHistory,
            titleVisibility: .visible
        ) {
            Button("Erase", role: .destructive) {
                // The recents store listens for this and clears itself.
                NotificationCenter.default.post(name: .inletEraseLaunchHistory, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Recent apps and files will be cleared. This can't be undone.")
        }
        .confirmationDialog(
            "Erase all crash reports?",
            isPresented: $confirmEraseReports,
            titleVisibility: .visible
        ) {
            Button("Erase", role: .destructive) {
                DiagnosticStore.shared.eraseAll()
                refresh()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every saved report on this Mac will be deleted. This can't be undone.")
        }
    }

    private func refresh() {
        loginStatus = LoginItem.status
        reportCount = DiagnosticStore.shared.all().count
    }
}

// MARK: - Updates

struct UpdatesPane: View {
    @EnvironmentObject private var updater: AppUpdater

    var body: some View {
        Form {
            UpdatesSettingsSection(updater: updater)
        }
        .formStyle(.grouped)
        .navigationTitle("Updates")
    }
}

// MARK: - About

struct AboutPane: View {
    @Environment(AppLibrary.self) private var library

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: versionText)
                LabeledContent("Apps found", value: "\(library.apps.count)")
                LabeledContent("Last scan", value: lastScanText)
            }

            Section {
                Button("Send Feedback…") {
                    FeedbackWindow.shared.show()
                }
            } footer: {
                Text("Feedback opens a form that leads to a GitHub issue in your browser.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }

    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(short) (\(build))"
    }

    private var lastScanText: String {
        guard let date = library.lastScanned else { return "Not yet" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
