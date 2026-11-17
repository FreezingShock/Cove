import AppKit
import Foundation
import Observation

// MARK: - FileItem

/// One file found through Spotlight. Used for the Files list in search and for
/// the recent-files row in the Dock quick panel.
struct FileItem: Identifiable, Hashable {
    /// The file's location on disk. Also the identity of the item.
    let url: URL
    /// The name shown to the user (Spotlight's display name, e.g. "Report.pdf").
    let name: String
    /// When the file was last opened, from Spotlight's last-used date. Nil if unknown.
    let lastUsed: Date?

    var id: URL { url }

    /// The folder that holds the file, with the home folder shortened to "~".
    var displayPath: String {
        let folder = url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if folder == home { return "~" }
        if folder.hasPrefix(home + "/") {
            return "~" + String(folder.dropFirst(home.count))
        }
        return folder
    }

    /// Opens the file with its default app. The caller should hide Inlet first.
    func open() {
        NSWorkspace.shared.open(url)
    }

    /// Selects the file in a Finder window (Cmd+Return in search).
    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Builds an item from one Spotlight result. Returns nil if the result has no path.
    init?(metadata item: NSMetadataItem) {
        guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
            return nil
        }
        self.url = URL(fileURLWithPath: path)
        self.name = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String)
            ?? url.lastPathComponent
        self.lastUsed = item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
    }

    init(url: URL, name: String, lastUsed: Date?) {
        self.url = url
        self.name = name
        self.lastUsed = lastUsed
    }
}

// MARK: - FileSearch

/// Searches files with Spotlight (NSMetadataQuery). Inlet keeps no index of its own.
///
/// Two entry points:
/// - `update(query:resultCount:)` for the search field. It debounces keystrokes and
///   publishes up to `resultCount` rows in `results`.
/// - `recentFiles(limit:)` for the quick panel. It returns files sorted by
///   Spotlight's last-used date, newest first.
///
/// Everything here runs on the main actor, because NSMetadataQuery needs a run loop.
@MainActor
@Observable
final class FileSearch {

    /// File rows for the current query, best match first. Empty when the query is empty.
    private(set) var results: [FileItem] = []

    /// True while a Spotlight query for the current text is pending or still gathering.
    private(set) var isSearching = false

    /// Wait this long after the last keystroke before querying (spec T3.2 proposes 150 ms).
    var debounceInterval: Duration = .milliseconds(150)

    /// Stop waiting for Spotlight after this long and show what has arrived.
    /// Keeps a slow query from stalling the list.
    var searchTimeout: Duration = .milliseconds(500)

    /// How many items to read from Spotlight before ranking. Reading more gives better
    /// ranking but costs time on common names.
    private let scanLimit = 200

    private var debounceTask: Task<Void, Never>?
    private var activeRunner: MetadataQueryRunner?

    // MARK: Search field

    /// Call on every change to the search text.
    ///
    /// - Parameters:
    ///   - query: The raw text from the search field.
    ///   - resultCount: Maximum number of rows to show. Pass the Settings value
    ///     (`searchFileResultCount`, 0 to 8). When it is 0, no query runs and results are cleared.
    func update(query: String, resultCount: Int) {
        debounceTask?.cancel()
        debounceTask = nil
        activeRunner?.stop()
        activeRunner = nil
        isSearching = false

        let terms = Self.searchTerms(from: query)
        guard !terms.isEmpty, resultCount > 0 else {
            results = []
            return
        }

        // Pending counts as searching too, so the "Searching files" line does not
        // flicker off during the debounce between keystrokes.
        isSearching = true
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: self?.debounceInterval ?? .milliseconds(150))
            guard !Task.isCancelled, let self else { return }
            await self.runSearch(terms: terms, query: query, resultCount: resultCount)
        }
    }

    /// Clears the results and stops any query in flight. Call when the overlay closes
    /// or the search field is cleared.
    func cancel() {
        debounceTask?.cancel()
        debounceTask = nil
        activeRunner?.stop()
        activeRunner = nil
        isSearching = false
        results = []
    }

    private func runSearch(terms: [String], query: String, resultCount: Int) async {
        isSearching = true
        let predicate = Self.namePredicate(terms: terms)
        let items: [FileItem] = await withCheckedContinuation { continuation in
            let runner = MetadataQueryRunner(
                predicate: predicate,
                sortDescriptors: [Self.lastUsedDescending],
                scanLimit: scanLimit,
                timeout: searchTimeout
            )
            activeRunner = runner
            runner.start { continuation.resume(returning: $0) }
        }

        // A newer keystroke cancelled this search. Don't overwrite its results.
        guard !Task.isCancelled else { return }
        activeRunner = nil
        isSearching = false
        results = Self.rank(items, for: query, limit: resultCount)
    }

    // MARK: Recents

    /// Returns up to `limit` files sorted by Spotlight's last-used date, newest first.
    /// Folders and apps are left out. Runs for at most about one second.
    static func recentFiles(limit: Int) async -> [FileItem] {
        guard limit > 0 else { return [] }
        return await withCheckedContinuation { continuation in
            let runner = MetadataQueryRunner(
                predicate: Self.recentPredicate(),
                sortDescriptors: [Self.lastUsedDescending],
                scanLimit: max(200, limit * 10),
                timeout: .seconds(1)
            )
            runner.start { items in
                continuation.resume(returning: Array(items.prefix(limit)))
            }
        }
    }

    // MARK: Predicates and ranking

    private static let lastUsedDescending = NSSortDescriptor(
        key: NSMetadataItemLastUsedDateKey,
        ascending: false
    )

    /// Splits typed text into words. Strips `*`, `?`, `\` and `"` because they are
    /// wildcard or escape characters in Spotlight queries.
    static func searchTerms(from query: String) -> [String] {
        let wildcardsAndEscapes: Set<Character> = ["*", "?", "\\", "\""]
        let cleaned = String(query.map { wildcardsAndEscapes.contains($0) ? " " : $0 })
        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    /// Every word must appear somewhere in the display name (case and diacritic insensitive).
    /// Folders and app bundles are excluded, because apps already appear in the grid.
    private static func namePredicate(terms: [String]) -> NSPredicate {
        var parts: [NSPredicate] = terms.map {
            NSPredicate(format: "%K LIKE[cd] %@", NSMetadataItemDisplayNameKey, "*\($0)*")
        }
        parts.append(contentsOf: excludedKindPredicates)
        return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }

    /// Anything that has a last-used date. Items with no date don't match `>=` against 1970.
    private static func recentPredicate() -> NSPredicate {
        let hasDate = NSPredicate(
            format: "%K >= %@",
            NSMetadataItemLastUsedDateKey,
            NSDate(timeIntervalSince1970: 0)
        )
        return NSCompoundPredicate(andPredicateWithSubpredicates: [hasDate] + excludedKindPredicates)
    }

    private static let excludedKindPredicates: [NSPredicate] = [
        NSPredicate(format: "NOT (%K == %@)", NSMetadataItemContentTypeTreeKey, "com.apple.application-bundle"),
        NSPredicate(format: "NOT (%K == %@)", NSMetadataItemContentTypeTreeKey, "public.folder"),
    ]

    /// Orders matches so exact names come first, then names that start with the query,
    /// then everything else. Ties keep Spotlight's last-used order.
    static func rank(_ items: [FileItem], for query: String, limit: Int) -> [FileItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ranked = items.enumerated().sorted { lhs, rhs in
            let left = matchRank(lhs.element.name, needle)
            let right = matchRank(rhs.element.name, needle)
            if left != right { return left < right }
            return lhs.offset < rhs.offset
        }
        return ranked.prefix(limit).map(\.element)
    }

    private static func matchRank(_ name: String, _ needle: String) -> Int {
        let lowered = name.lowercased()
        if lowered == needle { return 0 }
        if lowered.hasPrefix(needle) { return 1 }
        return 2
    }
}

// MARK: - MetadataQueryRunner

/// Runs one NSMetadataQuery and returns its results once gathering finishes, or when
/// the timeout expires. Holds itself alive until it finishes or is stopped.
@MainActor
private final class MetadataQueryRunner {
    private let query = NSMetadataQuery()
    private let scanLimit: Int
    private let timeout: Duration
    private var observer: NSObjectProtocol?
    private var timeoutTask: Task<Void, Never>?
    private var completion: (([FileItem]) -> Void)?
    /// Keeps the runner alive while its query is running. Cleared on finish or stop.
    private var selfReference: MetadataQueryRunner?

    init(predicate: NSPredicate, sortDescriptors: [NSSortDescriptor], scanLimit: Int, timeout: Duration) {
        self.scanLimit = scanLimit
        self.timeout = timeout
        query.predicate = predicate
        query.sortDescriptors = sortDescriptors
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
    }

    /// Starts gathering. `completion` runs once, on the main actor.
    func start(completion: @escaping ([FileItem]) -> Void) {
        self.completion = completion
        selfReference = self

        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.finish() }
        }

        timeoutTask = Task { [weak self, timeout] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.finish()
        }

        if !query.start() {
            finish()
        }
    }

    /// Stops the query and returns no results. Safe to call more than once.
    func stop() {
        finish(discard: true)
    }

    private func finish(discard: Bool = false) {
        guard let completion else { return }
        self.completion = nil

        var items: [FileItem] = []
        if !discard {
            query.disableUpdates()
            let count = min(query.resultCount, scanLimit)
            items = (0..<count).compactMap { index in
                guard let metadata = query.result(at: index) as? NSMetadataItem else { return nil }
                return FileItem(metadata: metadata)
            }
        }

        query.stop()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        selfReference = nil

        completion(items)
    }
}
