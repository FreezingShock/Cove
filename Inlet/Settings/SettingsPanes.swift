//
//  SettingsPanes.swift
//  Inlet
//
//  The eight Settings panes from the v1 spec (Q9). Each one is a grouped
//  Form. Every control writes to the shared InletSettings keys, so the grid,
//  search and quick panel read the same values.
//

import ServiceManagement
import SwiftUI

// MARK: - General

struct GeneralPane: View {
    @AppStorage(InletSettings.Key.showMenuBarIcon.rawValue) private var showMenuBarIcon = true
    @AppStorage(InletSettings.Key.closeAfterLaunch.rawValue) private var closeAfterLaunch = true
    @AppStorage(InletSettings.Key.escapeClearsSearchFirst.rawValue) private var escapeClearsSearchFirst = true
    @AppStorage(InletSettings.Key.rememberLastGroup.rawValue) private var rememberLastGroup = true

    /// The login item state comes from the system, so it is read live and never stored.
    @State private var loginStatus: SMAppService.Status = SMAppService.mainApp.status
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: openAtLogin)
            } footer: {
                if let loginError {
                    Text(loginError)
                } else if loginStatus == .requiresApproval {
                    Text("Allow Inlet in System Settings > General > Login Items.")
                } else {
                    Text("Inlet opens when you log in to your Mac.")
                }
            }

            Section {
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            }

            Section {
                Toggle("Close after launching an app", isOn: $closeAfterLaunch)
                Toggle("Escape clears the search first", isOn: $escapeClearsSearchFirst)
                Toggle("Remember the last group", isOn: $rememberLastGroup)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onAppear { loginStatus = SMAppService.mainApp.status }
    }

    /// Registers or unregisters Inlet as a login item.
    private var openAtLogin: Binding<Bool> {
        Binding(
            get: { loginStatus == .enabled },
            set: { wantsOn in
                do {
                    if wantsOn {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    loginError = nil
                } catch {
                    loginError = "Couldn't change the login item: \(error.localizedDescription)"
                }
                loginStatus = SMAppService.mainApp.status
            }
        )
    }
}

// MARK: - Keyboard

struct KeyboardPane: View {
    var body: some View {
        Form {
            Section {
                HotkeyRecorderRow(title: "Show all apps", name: .showGrid)
                HotkeyRecorderRow(title: "Quick panel", name: .showQuickPanel)
            } footer: {
                Text("Press a new shortcut to change it. Esc cancels. A shortcut that another app uses is refused.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Keyboard")
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
                Text("Auto follows Appearance in System Settings.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
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
                Text("The grid changes as soon as you adjust this.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Grid")
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

// MARK: - Privacy

struct PrivacyPane: View {
    @State private var confirmErase = false

    var body: some View {
        Form {
            Section {
                Button("Erase Launch History", role: .destructive) {
                    confirmErase = true
                }
            } footer: {
                Text("Clears Recent Apps and Recent Files. Inlet sends nothing anywhere, so this is the only history it keeps.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy")
        .confirmationDialog(
            "Erase launch history?",
            isPresented: $confirmErase,
            titleVisibility: .visible
        ) {
            Button("Erase", role: .destructive) {
                // The recents store listens for this and clears itself. Keeping it
                // a notification means this PR doesn't depend on the quick panel PR.
                NotificationCenter.default.post(name: .inletEraseLaunchHistory, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Recent apps and files will be cleared. This can't be undone.")
        }
    }
}

// MARK: - About

struct AboutPane: View {
    @Environment(AppLibrary.self) private var library
    @EnvironmentObject private var updater: AppUpdater

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: versionText)
                LabeledContent("Apps found", value: "\(library.apps.count)")
                LabeledContent("Last scan", value: lastScanText)
            }

            // Automatic-check toggle, last check time and a manual check button.
            UpdatesSettingsSection(updater: updater)
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
