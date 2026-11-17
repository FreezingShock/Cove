//
//  AppGroup.swift
//  Inlet
//
//  A group is a named filter on the group bar: a name, a color, an SF Symbol
//  and the apps in it. A fresh install starts with six preset groups, one per
//  AppCategory. The user can add, rename, recolor, re-icon, reorder and delete
//  groups, and move apps between them. Every installed app is in exactly one
//  group. This file is plain data with no UI.
//

import Foundation

/// The colors a group can use. Saved by name, so new cases can be added later
/// without breaking an existing file.
enum GroupColor: String, Codable, CaseIterable, Hashable, Sendable {
    case blue, teal, green, yellow, orange, red, pink, purple, gray
}

/// One group on the group bar.
struct AppGroup: Codable, Hashable, Identifiable, Sendable {
    /// Preset groups use their category's raw value ("create", "games", ...),
    /// so a "last group" saved by an older version still matches. Custom
    /// groups get a random UUID.
    var id: String
    /// Shown on the bar and in the Groups panel. At most `maxNameLength` characters.
    var name: String
    var color: GroupColor
    /// An SF Symbol name, such as "hammer".
    var symbol: String
    /// Newly installed apps with this category join this group. Nil for custom groups.
    var suggestedCategory: AppCategory?
    /// Apps in the group, in display order.
    var appIDs: [String]
    /// The zone this group belongs to. Nil means the group sits outside any zone.
    /// Reserved for custom zones: zones will hold groups, so every group already
    /// carries the link. Nothing reads it yet.
    var zoneID: String? = nil

    /// The longest name a group can have.
    static let maxNameLength = 40

    /// The six groups a new install starts with, in bar order.
    static var presets: [AppGroup] {
        AppCategory.allCases.map { category in
            let look = presetLook(for: category)
            return AppGroup(
                id: category.rawValue,
                name: category.title,
                color: look.color,
                symbol: look.symbol,
                suggestedCategory: category,
                appIDs: []
            )
        }
    }

    /// Icons the Groups panel offers. Each one is a standard SF Symbol.
    static let symbolChoices: [String] = [
        "star", "heart", "bolt", "flame", "leaf", "moon",
        "paintbrush.pointed", "hammer", "book", "house", "gamecontroller", "square.grid.2x2",
        "music.note", "camera", "film", "briefcase", "cart", "airplane",
        "globe", "envelope", "bubble.left", "creditcard", "gift", "terminal",
    ]

    /// Trims the name and caps its length. Returns nil when nothing is left,
    /// so an empty name is never saved.
    static func cleanName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    /// Index of the group a newly installed app with `category` should join.
    /// Prefers a group suggested for that category, then the Other group,
    /// then the first group. Nil only when there are no groups.
    static func suggestedIndex(for category: AppCategory, in groups: [AppGroup]) -> Int? {
        if let index = groups.firstIndex(where: { $0.suggestedCategory == category }) { return index }
        if let index = groups.firstIndex(where: { $0.suggestedCategory == .other }) { return index }
        return groups.isEmpty ? nil : 0
    }

    /// The color and icon a preset starts with. The user can change both.
    private static func presetLook(for category: AppCategory) -> (color: GroupColor, symbol: String) {
        switch category {
        case .create:
            return (.pink, "paintbrush.pointed")
        case .build:
            return (.blue, "hammer")
        case .school:
            return (.green, "book")
        case .everyday:
            return (.teal, "house")
        case .games:
            return (.purple, "gamecontroller")
        case .other:
            return (.gray, "square.grid.2x2")
        }
    }
}
