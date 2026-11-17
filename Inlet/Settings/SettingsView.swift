//
//  SettingsView.swift
//  Inlet
//
//  The Settings window (Cmd+,). A sidebar lists the panes, and the detail
//  side shows the selected pane as a grouped Form. Standard controls only,
//  so macOS 26 draws the glass sidebar and grouped rows for us.
//

import SwiftUI

/// The panes in the sidebar, in the order the mockup shows them.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, keyboard, appearance, grid, search, quickPanel, privacy, pro, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    return "General"
        case .keyboard:   return "Keyboard"
        case .appearance: return "Appearance"
        case .grid:       return "Grid"
        case .search:     return "Search"
        case .quickPanel: return "Quick Panel"
        case .privacy:    return "Privacy"
        case .pro:        return "Inlet Pro"
        case .about:      return "About"
        }
    }

    /// SF Symbol shown in the colored tile next to the title.
    var symbol: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .keyboard:   return "keyboard.fill"
        case .appearance: return "circle.lefthalf.filled"
        case .grid:       return "square.grid.3x3.fill"
        case .search:     return "magnifyingglass"
        case .quickPanel: return "dock.rectangle"
        case .privacy:    return "hand.raised.fill"
        case .pro:        return "star.circle.fill"
        case .about:      return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general, .keyboard: return .gray
        case .appearance:         return .indigo
        case .grid:               return .blue
        case .search:             return .orange
        case .quickPanel:         return .teal
        case .privacy:            return .pink
        case .pro:                return .purple
        case .about:              return .gray
        }
    }
}

struct SettingsView: View {
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            // Custom rows, not List(selection:): the system selection puts a white
            // label on the system accent, which is aqua in Dark (1.6:1). The selected
            // row uses the ink-on-glass lozenge instead.
            List {
                ForEach(SettingsPane.allCases) { pane in
                    Button {
                        selection = pane
                    } label: {
                        Label {
                            Text(pane.title)
                        } icon: {
                            SettingsTile(symbol: pane.symbol, tint: pane.tint)
                        }
                        .foregroundStyle(InletColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == pane ? .isSelected : [])
                    .listRowBackground(sidebarRowBackground(for: pane))
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

    @ViewBuilder
    private func sidebarRowBackground(for pane: SettingsPane) -> some View {
        if selection == pane {
            RoundedRectangle(cornerRadius: InletRadius.sm, style: .continuous)
                .fill(LinearGradient(colors: [InletColor.selTop, InletColor.selBot], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: InletRadius.sm, style: .continuous).strokeBorder(InletColor.selRing, lineWidth: 1))
                .padding(.horizontal, InletSpace.xs)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func detail(for pane: SettingsPane) -> some View {
        switch pane {
        case .general:    GeneralPane()
        case .keyboard:   KeyboardPane()
        case .appearance: AppearancePane()
        case .grid:       GridPane()
        case .search:     SearchPane()
        case .quickPanel: QuickPanelPane()
        case .privacy:    PrivacyPane()
        case .pro:        ProPane()
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
