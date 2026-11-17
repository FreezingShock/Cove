//
//  SettingsView.swift
//  Inlet
//
//  The Settings window (Cmd+,). A sidebar groups the panes the way System
//  Settings does, and the detail side shows the selected pane as a grouped
//  Form. Standard controls only, so macOS 26 draws the glass sidebar and
//  grouped rows for us.
//
//  Adding a pane (for example Groups): add a case to SettingsPane, give it
//  a title, symbol, tint and sidebar group, then add its view to
//  `detail(for:)`. Panes read and write through InletSettings keys only.
//

import SwiftUI

/// A titled block of rows in the sidebar. A nil title draws no header.
struct SidebarGroup: Identifiable {
    let title: String?
    let panes: [SettingsPane]

    var id: String { title ?? "main" }
}

/// The panes in the sidebar, in the order they appear.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, shortcuts
    case grid, hiddenApps, search, quickPanel
    case privacy, updates
    case account, about

    var id: String { rawValue }

    /// The sidebar, top to bottom.
    static let groups: [SidebarGroup] = [
        SidebarGroup(title: nil, panes: [.general, .appearance, .shortcuts]),
        SidebarGroup(title: "Launcher", panes: [.grid, .hiddenApps, .search, .quickPanel]),
        SidebarGroup(title: "Privacy & Updates", panes: [.privacy, .updates]),
        SidebarGroup(title: "Inlet", panes: [.account, .about]),
    ]

    var title: String {
        switch self {
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .shortcuts:  return "Shortcuts"
        case .grid:       return "Grid"
        case .hiddenApps: return "Hidden Apps"
        case .search:     return "Search"
        case .quickPanel: return "Quick Panel"
        case .privacy:    return "Privacy & Permissions"
        case .updates:    return "Updates"
        case .account:    return "Inlet Pro"
        case .about:      return "About"
        }
    }

    /// SF Symbol shown in the colored tile next to the title.
    var symbol: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .appearance: return "circle.lefthalf.filled"
        case .shortcuts:  return "keyboard.fill"
        case .grid:       return "square.grid.3x3.fill"
        case .hiddenApps: return "eye.slash.fill"
        case .search:     return "magnifyingglass"
        case .quickPanel: return "dock.rectangle"
        case .privacy:    return "hand.raised.fill"
        case .updates:    return "arrow.down.circle.fill"
        case .account:    return "sparkles"
        case .about:      return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general, .shortcuts, .about: return .gray
        case .appearance:                  return .indigo
        case .grid:                        return .blue
        case .hiddenApps:                  return .purple
        case .search:                      return .orange
        case .quickPanel:                  return .teal
        case .privacy:                     return .pink
        case .updates:                     return .green
        case .account:                     return .yellow
        }
    }
}

struct SettingsView: View {
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsPane.groups) { group in
                    Section {
                        ForEach(group.panes) { pane in
                            sidebarRow(pane)
                        }
                    } header: {
                        if let title = group.title {
                            Text(title)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
        } detail: {
            detail(for: selection ?? .general)
        }
        // Fixed size from the spec: 700 x 520.
        .frame(width: InletSize.settingsWindow.width, height: InletSize.settingsWindow.height)
        // Appearance changes apply to this window too.
        .inletAppearance()
    }

    private func sidebarRow(_ pane: SettingsPane) -> some View {
        Label {
            Text(pane.title)
        } icon: {
            SettingsTile(symbol: pane.symbol, tint: pane.tint)
        }
        .tag(pane)
    }

    @ViewBuilder
    private func detail(for pane: SettingsPane) -> some View {
        switch pane {
        case .general:    GeneralPane()
        case .appearance: AppearancePane()
        case .shortcuts:  ShortcutsPane()
        case .grid:       GridPane()
        case .hiddenApps: HiddenAppsPane()
        case .search:     SearchPane()
        case .quickPanel: QuickPanelPane()
        case .privacy:    PrivacyPane()
        case .updates:    UpdatesPane()
        case .account:    AccountPane()
        case .about:      AboutPane()
        }
    }
}

/// The 20 pt colored square with a white symbol, as in System Settings.
struct SettingsTile: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: InletRadius.icon(20), style: .continuous)
            .fill(tint.gradient)
            .frame(width: 20, height: 20)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// Applies the Appearance setting (Auto, Light or Dark) to a window's content.
/// Auto passes `nil`, which means "follow the system".
struct FollowsInletAppearance: ViewModifier {
    @AppStorage(InletSettings.Key.appearance.rawValue)
    private var mode = InletSettings.AppearanceMode.auto.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch InletSettings.AppearanceMode(rawValue: mode) ?? .auto {
        case .auto:  return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

extension View {
    /// Use on the root view of every Inlet window.
    func inletAppearance() -> some View {
        modifier(FollowsInletAppearance())
    }
}
