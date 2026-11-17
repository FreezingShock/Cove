//
//  ThemeStore.swift
//  Inlet
//
//  Holds the saved themes and the one the user picked. Every change is saved
//  at once and pushed into `ThemeRuntime`, so open windows redraw in the new look.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    /// The user's own themes, in the order they were made.
    private(set) var customThemes: [AppTheme]
    /// The id of the theme the user picked. It stays picked when Supporter is off.
    private(set) var selectedID: String
    /// Goes up on every change. Window roots use it to redraw.
    private(set) var revision = 0

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        customThemes = AppTheme.savedThemes(in: defaults)
        selectedID = defaults.string(forKey: InletSettings.Key.activeTheme.rawValue) ?? AppTheme.standard.id
    }

    /// Presets first, then the user's own.
    var allThemes: [AppTheme] { AppTheme.presets + customThemes }

    /// The theme the user picked.
    var selected: AppTheme {
        allThemes.first { $0.id == selectedID } ?? .standard
    }

    /// The theme on screen right now.
    var effective: AppTheme {
        AppTheme.effective(selectedID: selectedID, custom: customThemes, supporter: Supporter.isOn(in: defaults))
    }

    func isCustom(_ theme: AppTheme) -> Bool {
        customThemes.contains { $0.id == theme.id }
    }

    func select(_ id: String) {
        guard allThemes.contains(where: { $0.id == id }) else { return }
        selectedID = id
        persistSelection()
        publish()
    }

    /// Adds a new custom theme, or saves changes to one that exists.
    /// Presets can't be changed, so saving one does nothing.
    func save(_ theme: AppTheme) {
        guard !theme.isPreset else { return }
        let clean = theme.sanitized
        if let index = customThemes.firstIndex(where: { $0.id == clean.id }) {
            customThemes[index] = clean
        } else {
            customThemes.append(clean)
        }
        persistCustom()
        publish()
    }

    /// Copies any theme into a new custom theme, selects it, and returns it.
    @discardableResult
    func duplicate(_ theme: AppTheme) -> AppTheme {
        var copy = theme.sanitized
        copy.id = "custom." + UUID().uuidString
        copy.name = String((theme.name + " Copy").prefix(40))
        customThemes.append(copy)
        selectedID = copy.id
        persistCustom()
        persistSelection()
        publish()
        return copy
    }

    /// Deletes a custom theme. Presets are kept. If the deleted theme was picked, Inlet's look is picked instead.
    func delete(_ id: String) {
        guard customThemes.contains(where: { $0.id == id }) else { return }
        customThemes.removeAll { $0.id == id }
        if selectedID == id { selectedID = AppTheme.standard.id }
        persistCustom()
        persistSelection()
        publish()
    }

    /// Reads an exported theme file, saves it as a new theme, and selects it.
    @discardableResult
    func importTheme(from data: Data) throws -> AppTheme {
        let theme = try AppThemeFile.importTheme(from: data)
        customThemes.append(theme)
        selectedID = theme.id
        persistCustom()
        persistSelection()
        publish()
        return theme
    }

    func exportData(for theme: AppTheme) throws -> Data {
        try AppThemeFile.export(theme)
    }

    // MARK: Private

    private func publish() {
        ThemeRuntime.current = effective
        revision += 1
    }

    private func persistCustom() {
        defaults.set(try? JSONEncoder().encode(customThemes), forKey: InletSettings.Key.customThemes.rawValue)
    }

    private func persistSelection() {
        defaults.set(selectedID, forKey: InletSettings.Key.activeTheme.rawValue)
    }
}

extension View {
    /// Rebuilds this window's content when the theme changes. The color tokens
    /// read the theme directly, which SwiftUI can't see, so the subtree is
    /// rebuilt on each change. Use it on a root view that stays open.
    func inletThemeRefresh() -> some View {
        ThemeRefresh(content: self)
    }
}

private struct ThemeRefresh<Content: View>: View {
    let content: Content

    var body: some View {
        content.id(ThemeStore.shared.revision)
    }
}

extension Color {
    /// This color as "#RRGGBB" in sRGB, or nil when it can't be read.
    var themeHex: String? {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return ThemeColor.hex(ThemeColor.RGB(
            r: Double(rgb.redComponent),
            g: Double(rgb.greenComponent),
            b: Double(rgb.blueComponent)
        ))
    }

    /// A color from "#RRGGBB", or `fallback` when the text isn't valid hex.
    init(themeHex: String?, fallback: ThemeColor.RGB) {
        let rgb = themeHex.flatMap { ThemeColor.parseHex($0) } ?? fallback
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
