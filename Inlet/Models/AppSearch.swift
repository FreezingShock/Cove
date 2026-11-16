//
//  AppSearch.swift
//  Inlet
//
//  Finds apps for the search field. Pure logic: no views and no disk access,
//  so it is easy to test. Spotlight file results (T3.2) can reuse the same
//  normalizing rules.
//

import Foundation

enum AppSearch {

    /// Lowercases and strips accents, so "cafe" finds "Café" and "SAFARI"
    /// finds "Safari". Spaces at the ends are removed too.
    static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// How well a name matches the query. Lower raw value is a better match.
    private enum Rank: Int, Comparable {
        case exact = 0        // "Mail" for "mail"
        case prefix = 1       // "Mail Merge" for "mail"
        case wordPrefix = 2   // "Apple Mail" for "mail"
        case contains = 3     // "Gmail Archive" for "mail"

        static func < (lhs: Rank, rhs: Rank) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The rank of a normalized name against a normalized query, or nil if
    /// the name does not match at all.
    private static func rank(of name: String, query: String) -> Rank? {
        if name == query { return .exact }
        if name.hasPrefix(query) { return .prefix }
        // Split "Apple Mail" into ["Apple", "Mail"] so any word can match.
        let words = name.split { !$0.isLetter && !$0.isNumber }
        if words.contains(where: { $0.hasPrefix(query) }) { return .wordPrefix }
        if name.contains(query) { return .contains }
        return nil
    }

    /// Apps that match `query`, best match first. Ties keep the grid's
    /// existing (name) order. An empty query returns every app unchanged.
    static func results(for query: String, in apps: [AppItem]) -> [AppItem] {
        let q = normalize(query)
        guard !q.isEmpty else { return apps }

        return apps.enumerated()
            .compactMap { index, app -> (index: Int, rank: Rank, app: AppItem)? in
                guard let rank = rank(of: normalize(app.name), query: q) else { return nil }
                return (index, rank, app)
            }
            .sorted { lhs, rhs in
                // Best rank first; the original index keeps ties stable.
                (lhs.rank, lhs.index) < (rhs.rank, rhs.index)
            }
            .map(\.app)
    }
}
