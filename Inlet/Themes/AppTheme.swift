//
//  AppTheme.swift
//  Inlet
//
//  A Supporter theme: one named set of look choices for the grid. Plain data
//  with no UI. Themes export to a small JSON file so they can be shared.
//

import Foundation

/// One look for Inlet. Presets ship with the app; the user can save their own.
struct AppTheme: Codable, Equatable, Identifiable, Sendable {

    /// What sits under each icon.
    enum LabelStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case standard, compact, hidden

        var id: String { rawValue }

        var title: String {
            switch self {
            case .standard: "Standard"
            case .compact: "Compact"
            case .hidden: "Hidden"
            }
        }
    }

    /// The ranges the editor offers. Imports and stored values are clamped to these.
    enum Limits {
        static let unit: ClosedRange<Double> = 0...1
        /// Glass below this is too faint to hold text.
        static let glass: ClosedRange<Double> = 0.2...1
        static let iconSize: ClosedRange<Double> = 56...88
    }

    var id: String
    var name: String
    /// "#RRGGBB" for a custom accent. Nil keeps Inlet's accent.
    var accentHex: String?
    /// "#RRGGBB" for a background tint. Nil keeps Inlet's neutral background.
    var tintHex: String?
    /// 0...1. How much of the tint's hue and saturation reaches the background.
    var tintStrength: Double
    /// 0.2...1. 0.5 is Inlet's glass. Higher is more opaque.
    var glassIntensity: Double
    /// 0...1. 0.5 is Inlet's backdrop. Higher veils the desktop more.
    var backdropVeil: Double
    /// Points. The artwork draws at this size; the cell stays the same.
    var iconSize: Double
    var labelStyle: LabelStyle

    /// Inlet's own look. Always available, and what a non-Supporter sees.
    static let standard = AppTheme(
        id: "inlet",
        name: "Inlet",
        accentHex: nil,
        tintHex: nil,
        tintStrength: 0,
        glassIntensity: 0.5,
        backdropVeil: 0.5,
        iconSize: 72,
        labelStyle: .standard
    )

    /// Built-in themes. They can't be edited; duplicate one to change it.
    static let presets: [AppTheme] = [
        .standard,
        AppTheme(id: "preset.graphite", name: "Graphite", accentHex: "#8E9AAF", tintHex: "#6B7280",
                 tintStrength: 0.35, glassIntensity: 0.6, backdropVeil: 0.6, iconSize: 72, labelStyle: .standard),
        AppTheme(id: "preset.harbor", name: "Harbor", accentHex: "#4FB3FF", tintHex: "#1E3A5F",
                 tintStrength: 0.6, glassIntensity: 0.5, backdropVeil: 0.55, iconSize: 72, labelStyle: .standard),
        AppTheme(id: "preset.ember", name: "Ember", accentHex: "#FF8A4C", tintHex: "#3B1F16",
                 tintStrength: 0.5, glassIntensity: 0.55, backdropVeil: 0.5, iconSize: 72, labelStyle: .standard),
        AppTheme(id: "preset.paper", name: "Paper", accentHex: "#0A7F74", tintHex: "#D9CBB0",
                 tintStrength: 0.45, glassIntensity: 0.7, backdropVeil: 0.4, iconSize: 80, labelStyle: .standard),
        AppTheme(id: "preset.minimal", name: "Minimal", accentHex: nil, tintHex: nil,
                 tintStrength: 0, glassIntensity: 0.3, backdropVeil: 0.3, iconSize: 64, labelStyle: .compact),
    ]

    var isPreset: Bool { AppTheme.presets.contains { $0.id == id } }

    /// The same theme with every value in range and every color valid.
    /// A bad color becomes nil, so a damaged file still loads.
    var sanitized: AppTheme {
        var copy = self
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        copy.name = trimmed.isEmpty ? "Untitled Theme" : trimmed
        copy.accentHex = accentHex.flatMap { ThemeColor.parseHex($0) }.map { ThemeColor.hex($0) }
        copy.tintHex = tintHex.flatMap { ThemeColor.parseHex($0) }.map { ThemeColor.hex($0) }
        copy.tintStrength = min(max(tintStrength, Limits.unit.lowerBound), Limits.unit.upperBound)
        copy.glassIntensity = min(max(glassIntensity, Limits.glass.lowerBound), Limits.glass.upperBound)
        copy.backdropVeil = min(max(backdropVeil, Limits.unit.lowerBound), Limits.unit.upperBound)
        copy.iconSize = min(max(iconSize, Limits.iconSize.lowerBound), Limits.iconSize.upperBound)
        return copy
    }

    /// The theme to draw with. Only a Supporter gets the picked theme;
    /// everyone else gets Inlet's own look. The pick is kept either way.
    static func effective(selectedID: String, custom: [AppTheme], supporter: Bool) -> AppTheme {
        guard supporter else { return .standard }
        return (presets + custom).first { $0.id == selectedID } ?? .standard
    }

    /// The custom themes saved in UserDefaults. A damaged list reads as empty.
    static func savedThemes(in defaults: UserDefaults) -> [AppTheme] {
        guard let data = defaults.data(forKey: InletSettings.Key.customThemes.rawValue),
              let themes = try? JSONDecoder().decode([AppTheme].self, from: data)
        else { return [] }
        return themes.map(\.sanitized)
    }
}

/// The file a theme exports to: JSON with a format tag, so an import can
/// tell an Inlet theme from any other file.
struct AppThemeFile: Codable {
    static let formatTag = "inlet-theme"
    static let currentVersion = 1

    var format: String
    var version: Int
    var theme: AppTheme

    enum FileError: LocalizedError, Equatable {
        case notAnInletTheme
        case newerVersion(Int)
        case invalidColor

        var errorDescription: String? {
            switch self {
            case .notAnInletTheme:
                "This file isn't an Inlet theme."
            case .newerVersion(let version):
                "This theme uses format \(version), which is newer than this copy of Inlet. Update Inlet to import it."
            case .invalidColor:
                "This theme has a color that isn't a valid hex value."
            }
        }
    }

    /// Encodes a theme as pretty JSON. The theme is sanitized first.
    static func export(_ theme: AppTheme) throws -> Data {
        let file = AppThemeFile(format: formatTag, version: currentVersion, theme: theme.sanitized)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    /// Reads a theme file. The result gets a new id, so an import never
    /// overwrites a theme that is already saved.
    static func importTheme(from data: Data) throws -> AppTheme {
        let file: AppThemeFile
        do {
            file = try JSONDecoder().decode(AppThemeFile.self, from: data)
        } catch {
            throw FileError.notAnInletTheme
        }
        guard file.format == formatTag else { throw FileError.notAnInletTheme }
        guard file.version <= currentVersion else { throw FileError.newerVersion(file.version) }

        let hexes = [file.theme.accentHex, file.theme.tintHex].compactMap { $0 }
        if hexes.contains(where: { ThemeColor.parseHex($0) == nil }) {
            throw FileError.invalidColor
        }

        var theme = file.theme.sanitized
        theme.id = "custom." + UUID().uuidString
        return theme
    }
}
