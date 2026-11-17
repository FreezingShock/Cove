//
//  AppCategory.swift
//  Inlet
//
//  The six preset groups, and how an app's LSApplicationCategoryType maps
//  onto them. A new install seeds one group per case; after that the user
//  owns the groups (see AppGroup).
//

import Foundation

/// The preset groups a new install starts with. Each app's category decides
/// which preset it joins when it is first installed.
enum AppCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case create
    case build
    case school
    case everyday
    case games
    case other

    var id: String { rawValue }

    /// The name of the matching preset group.
    var title: String {
        switch self {
        case .create: "Create"
        case .build: "Build"
        case .school: "School"
        case .everyday: "Everyday"
        case .games: "Games"
        case .other: "Other"
        }
    }

    /// Maps an app's `LSApplicationCategoryType`, such as
    /// "public.app-category.developer-tools", to one preset.
    ///
    /// - A nil or empty value goes to `.other`.
    /// - Any value Apple does not document goes to `.other`, so an app
    ///   can never be left without a bucket.
    /// - Matching ignores case and the "public.app-category." prefix,
    ///   so "developer-tools" and "Developer-Tools" also work.
    ///
    /// The table follows Apple's documented list. It is the starting point
    /// from the v1 spec (Q5); tune it against a real /Applications scan.
    static func bucket(forCategoryType rawValue: String?) -> AppCategory {
        guard let key = normalizedKey(rawValue) else { return .other }

        switch key {
        case "graphics-design", "photography", "video", "music":
            return .create
        case "developer-tools":
            return .build
        case "education", "reference":
            return .school
        case "business", "entertainment", "finance", "healthcare-fitness",
             "lifestyle", "medical", "news", "productivity", "social-networking",
             "sports", "travel", "utilities", "weather":
            return .everyday
        case "games":
            return .games
        case _ where gameSubcategories.contains(key):
            return .games
        default:
            return .other
        }
    }

    // MARK: - Private

    /// The prefix Apple puts on every `LSApplicationCategoryType` value.
    private static let categoryTypePrefix = "public.app-category."

    /// The game subcategories Apple documents. "games" itself is handled in
    /// the switch above. Every game, including educational games, goes to
    /// the Games bucket.
    private static let gameSubcategories: Set<String> = [
        "action-games", "adventure-games", "arcade-games", "board-games",
        "card-games", "casino-games", "dice-games", "educational-games",
        "family-games", "kids-games", "music-games", "puzzle-games", "racing-games",
        "role-playing-games", "simulation-games", "sports-games",
        "strategy-games", "trivia-games", "word-games",
    ]

    /// Lowercases, trims, and strips the UTI prefix. Returns nil for an
    /// empty value.
    private static func normalizedKey(_ rawValue: String?) -> String? {
        guard var key = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(), !key.isEmpty else { return nil }

        if key.hasPrefix(categoryTypePrefix) {
            key.removeFirst(categoryTypePrefix.count)
        }
        return key.isEmpty ? nil : key
    }
}
