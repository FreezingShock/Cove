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
    enum Rank: Int, Comparable {
        case exact = 0        // "Mail" for "mail"
        case prefix = 1       // "Mail Merge" for "mail"
        case wordPrefix = 2   // "Apple Mail" for "mail"
        case acronym = 3      // "Visual Studio Code" for "vsc"
        case contains = 4     // "Gmail Archive" for "mail"
        case subsequence = 5  // "Chrome" for "chrm": letters in order, gaps allowed

        static func < (lhs: Rank, rhs: Rank) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The rank of a normalized name against a normalized query, or nil if
    /// the name does not match at all.
    ///
    /// Every typed word has to match. Words can come in any order, so
    /// "mail apple" finds "Apple Mail".
    static func rank(of name: String, query: String) -> Rank? {
        if name == query { return .exact }
        if name.hasPrefix(query) { return .prefix }
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        // Split "Apple Mail" into ["apple", "mail"] so any word can match.
        let words = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        if terms.allSatisfy({ term in words.contains { $0.hasPrefix(term) } }) {
            return .wordPrefix
        }
        // Initials: "vsc" matches "Visual Studio Code". Needs two or more
        // letters, so a one-letter query does not match every multi-word app.
        if query.count >= 2, words.count >= 2, String(words.compactMap(\.first)) == query {
            return .acronym
        }
        // Otherwise each word may sit anywhere inside the name.
        if terms.allSatisfy({ name.contains($0) }) { return .contains }
        // Loose match for typed-from-memory names. Three letters minimum,
        // so short queries stay precise.
        if query.count >= 3, isSubsequence(query, of: name) { return .subsequence }
        return nil
    }

    /// True when every character of `needle` appears in `haystack` in order.
    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var remaining = needle[...]
        for character in haystack where remaining.first == character {
            remaining = remaining.dropFirst()
        }
        return remaining.isEmpty
    }

    /// Apps that match `query`, best match first. Within the same rank, apps
    /// launched more often come first (`usage` counts launches by app ID, which
    /// is the app's path). Remaining ties keep the grid's order. An empty query
    /// returns every app unchanged.
    static func results(for query: String, in apps: [AppItem], usage: [String: Int] = [:]) -> [AppItem] {
        let q = normalize(query)
        guard !q.isEmpty else { return apps }

        return apps.enumerated()
            .compactMap { index, app -> (index: Int, rank: Rank, uses: Int, app: AppItem)? in
                guard let rank = rank(of: normalize(app.name), query: q) else { return nil }
                return (index, rank, usage[app.id] ?? 0, app)
            }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                if lhs.uses != rhs.uses { return lhs.uses > rhs.uses }
                return lhs.index < rhs.index
            }
            .map(\.app)
    }
}
