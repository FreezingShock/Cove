//
//  AppCategory.swift
//  Cove
//
//  The five buckets on the category bar, and how an app's
//  LSApplicationCategoryType maps onto them.
//

import Foundation

/// The five buckets the category bar offers. Every installed app is in
/// exactly one of them.
enum AppCategory: String, CaseIterable, Identifiable, Sendable {
    case create
    case build
    case school
    case everyday
    case other

    var id: String { rawValue }

    /// The label on the category bar.
    var title: String {
        switch self {
        case .create: "Create"
        case .build: "Build"
        case .school: "School"
        case .everyday: "Everyday"
        case .other: "Other"
        }
    }

    /// Maps an app's `LSApplicationCategoryType`, such as
    /// "public.app-category.developer-tools", to one bucket.
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
        case "education", "reference", "educational-games":
            return .school
        case "business", "entertainment", "finance", "games", "healthcare-fitness",
             "lifestyle", "medical", "news", "productivity", "social-networking",
             "sports", "travel", "utilities", "weather":
            return .everyday
        case _ where gameSubcategories.contains(key):
            return .everyday
        default:
            return .other
        }
    }

    /// Returns `apps` in one bucket, or every app when `category` is nil.
    /// Keeps the input order, so the caller's sort is preserved.
    static func filter(_ apps: [AppItem], by category: AppCategory?) -> [AppItem] {
        guard let category else { return apps }
        return apps.filter { $0.category == category }
    }

    // MARK: - Private

    /// The prefix Apple puts on every `LSApplicationCategoryType` value.
    private static let categoryTypePrefix = "public.app-category."

    /// The game subcategories Apple documents. "games" itself is handled in
    /// the switch above. Each one is a game, so each goes to Everyday, except
    /// educational-games, which goes to School.
    private static let gameSubcategories: Set<String> = [
        "action-games", "adventure-games", "arcade-games", "board-games",
        "card-games", "casino-games", "dice-games", "family-games",
        "kids-games", "music-games", "puzzle-games", "racing-games",
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
