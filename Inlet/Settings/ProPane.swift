//
//  ProPane.swift
//  Inlet
//
//  Settings > Inlet Pro. The Supporter switch, the theme list and editor,
//  and a count of zones. Zones are placed on the grid, in Edit mode.
//

import SwiftUI
import UniformTypeIdentifiers

struct ProPane: View {
    @AppStorage(InletSettings.Key.supporterActive.rawValue) private var supporterOn = false
    @Environment(\.colorSchemeContrast) private var contrast

    private let store = ThemeStore.shared
    private let zoneStore = ZoneStore.shared

    /// The result of the last import or export, shown under the buttons.
    @State private var notice: String?

    var body: some View {
        Form {
            Section {
                Toggle("Supporter", isOn: $supporterOn)
            } footer: {
                Text("Supporter unlocks custom themes and zones. For now it works on your honor: payment isn't set up yet. Inlet's code is MIT licensed, so anyone can build it with these on.")
            }

            Section {
                ForEach(store.allThemes) { theme in
                    ThemeRow(theme: theme, isSelected: theme.id == store.selectedID) {
                        store.select(theme.id)
                    }
                }
            } header: {
                Text("Theme")
            } footer: {
                Text(store.isCustom(store.selected)
                     ? "Changes save as you make them."
                     : "Presets are fixed. Duplicate one to make your own.")
            }
            .disabled(!supporterOn)

            Section {
                HStack(spacing: InletSpace.s) {
                    Button("Duplicate") { store.duplicate(store.selected) }
                    Button("Delete", role: .destructive) { store.delete(store.selectedID) }
                        .disabled(!store.isCustom(store.selected))
                    Spacer()
                    Button("Import…") { importTheme() }
                    Button("Export…") { exportTheme() }
                }
                if let notice {
                    Text(notice)
                        .font(InletFont.caption)
                        .foregroundStyle(InletText.secondary(contrast))
                }
            } footer: {
                Text("Export saves the selected theme as a JSON file you can share. Import adds one as a new theme.")
            }
            .disabled(!supporterOn)

            if store.isCustom(store.selected) {
                editor(for: store.selected)
                    .disabled(!supporterOn)
            }

            Section {
                LabeledContent("Zones", value: "\(zoneStore.zones.count)")
            } header: {
                Text("Zones")
            } footer: {
                Text("Turn on Edit on the grid, then choose Add Zone. A zone takes its groups' apps off the main grid and shows them in its own block.")
            }
            .disabled(!supporterOn)
        }
        .formStyle(.grouped)
        .navigationTitle("Inlet Pro")
    }

    // MARK: Editor

    @ViewBuilder
    private func editor(for theme: AppTheme) -> some View {
        Section {
            TextField("Name", text: Binding(
                get: { theme.name },
                set: { value in update(theme) { $0.name = value } }
            ))

            ColorPicker("Accent", selection: Binding(
                get: { Color(themeHex: theme.accentHex, fallback: ThemeStyle.defaultAccent) },
                set: { color in update(theme) { $0.accentHex = color.themeHex } }
            ), supportsOpacity: false)

            HStack {
                Spacer()
                Button("Use Inlet's Accent") { update(theme) { $0.accentHex = nil } }
                    .disabled(theme.accentHex == nil)
            }

            ColorPicker("Background tint", selection: Binding(
                get: { Color(themeHex: theme.tintHex, fallback: ThemeStyle.defaultTint) },
                set: { color in update(theme) { $0.tintHex = color.themeHex } }
            ), supportsOpacity: false)

            LabeledContent("Tint strength") {
                Slider(value: slider(theme, \.tintStrength, AppTheme.Limits.unit), in: AppTheme.Limits.unit)
                    .frame(width: 200)
                    .disabled(theme.tintHex == nil)
            }

            HStack {
                Spacer()
                Button("No Tint") { update(theme) { $0.tintHex = nil } }
                    .disabled(theme.tintHex == nil)
            }
        } header: {
            Text("Colors")
        }

        Section {
            LabeledContent("Glass") {
                Slider(value: slider(theme, \.glassIntensity, AppTheme.Limits.glass), in: AppTheme.Limits.glass)
                    .frame(width: 200)
            }
            LabeledContent("Backdrop") {
                Slider(value: slider(theme, \.backdropVeil, AppTheme.Limits.unit), in: AppTheme.Limits.unit)
                    .frame(width: 200)
            }
        } header: {
            Text("Surfaces")
        } footer: {
            Text("Glass sets how solid the panels are. Backdrop dims the desktop behind the grid. macOS doesn't give SwiftUI a blur radius, so Backdrop is a veil, not a true blur.")
        }

        Section {
            LabeledContent("Icon size") {
                Slider(value: slider(theme, \.iconSize, AppTheme.Limits.iconSize), in: AppTheme.Limits.iconSize, step: 2)
                    .frame(width: 200)
            }
            Picker("Labels", selection: Binding(
                get: { theme.labelStyle },
                set: { value in update(theme) { $0.labelStyle = value } }
            )) {
                ForEach(AppTheme.LabelStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Icons")
        } footer: {
            Text("Icon size changes the artwork. Each cell keeps its size, so larger icons leave less room for the name.")
        }
    }

    // MARK: Helpers

    /// Saves a changed copy of `theme`. Every edit goes through here.
    private func update(_ theme: AppTheme, _ change: (inout AppTheme) -> Void) {
        var copy = theme
        change(&copy)
        store.save(copy)
    }

    /// A binding to one number on the theme, clamped to `range`.
    private func slider(
        _ theme: AppTheme,
        _ keyPath: WritableKeyPath<AppTheme, Double>,
        _ range: ClosedRange<Double>
    ) -> Binding<Double> {
        Binding(
            get: { theme[keyPath: keyPath] },
            set: { value in
                update(theme) { $0[keyPath: keyPath] = min(max(value, range.lowerBound), range.upperBound) }
            }
        )
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an Inlet theme file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let theme = try store.importTheme(from: Data(contentsOf: url))
            notice = "Imported “\(theme.name)”."
        } catch {
            notice = error.localizedDescription
        }
    }

    private func exportTheme() {
        let theme = store.selected
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(theme.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportData(for: theme).write(to: url, options: .atomic)
            notice = "Exported “\(theme.name)”."
        } catch {
            notice = error.localizedDescription
        }
    }
}

/// Colors the pane uses before a theme sets its own.
private enum ThemeStyle {
    static let defaultAccent = ThemeColor.RGB(r: 0.039, g: 0.498, b: 0.455)
    static let defaultTint = ThemeColor.RGB(r: 0.420, g: 0.459, b: 0.502)
}

/// One theme in the list: a small swatch, its name, and a check when picked.
private struct ThemeRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: InletSpace.m) {
                swatch
                Text(theme.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The theme's background and accent, drawn the way the grid would draw them.
    private var swatch: some View {
        let colors = swatchColors()
        return ZStack {
            RoundedRectangle(cornerRadius: InletRadius.xs, style: .continuous)
                .fill(Color(red: colors.background.r, green: colors.background.g, blue: colors.background.b))
            Circle()
                .fill(Color(red: colors.accent.r, green: colors.accent.g, blue: colors.accent.b))
                .frame(width: 10, height: 10)
        }
        .frame(width: 36, height: 24)
        .overlay(
            RoundedRectangle(cornerRadius: InletRadius.xs, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private func swatchColors() -> (background: ThemeColor.RGB, accent: ThemeColor.RGB) {
        let dark = scheme == .dark
        let base = dark
            ? ThemeColor.RGB(r: 0.020, g: 0.027, b: 0.047)
            : ThemeColor.RGB(r: 0.902, g: 0.925, b: 0.949)
        var background = base
        if let tintHex = theme.tintHex, let tint = ThemeColor.parseHex(tintHex) {
            background = ThemeColor.tinted(base, toward: tint, strength: theme.tintStrength)
        }
        let defaultAccent = dark
            ? ThemeColor.RGB(r: 0.247, g: 0.851, b: 0.788)
            : ThemeColor.RGB(r: 0.039, g: 0.498, b: 0.455)
        let accent = theme.accentHex.flatMap { ThemeColor.parseHex($0) } ?? defaultAccent
        return (background, accent)
    }
}
