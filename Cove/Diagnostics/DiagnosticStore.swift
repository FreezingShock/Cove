//
//  DiagnosticStore.swift
//  Cove
//
//  Keeps crash and hang reports on this Mac, in Application Support.
//  Nothing in this file touches the network. A report leaves the Mac only
//  when the user copies it or submits a GitHub issue themselves
//  (see FeedbackComposer).
//

import Foundation
import OSLog

/// Metadata for one saved MetricKit diagnostic payload.
/// The full JSON is stored in its own file, named after `id`.
struct StoredDiagnostic: Codable, Identifiable, Hashable {
    let id: UUID
    /// When Cove received the report (not when the problem happened).
    let receivedAt: Date
    /// Start and end of the period the report covers.
    let periodStart: Date
    let periodEnd: Date
    let crashCount: Int
    let hangCount: Int
    let cpuExceptionCount: Int
    let diskWriteExceptionCount: Int
    let appVersion: String
    let osVersion: String

    /// True when the payload holds at least one problem.
    var problemCount: Int {
        crashCount + hangCount + cpuExceptionCount + diskWriteExceptionCount
    }
}

/// Saves diagnostic payloads as JSON files under
/// `~/Library/Application Support/Cove/Diagnostics/`, with an `index.json`
/// listing them newest first.
///
/// All disk access runs on one serial queue, so MetricKit's background
/// callbacks and the UI never touch the files at the same time.
final class DiagnosticStore: @unchecked Sendable {
    static let shared = DiagnosticStore()

    /// Most reports kept on disk. Older ones are deleted when a new one arrives.
    static let maxReports = 20

    private let log = Logger(subsystem: "com.freezingshock.Cove", category: "Diagnostics")
    private let queue = DispatchQueue(label: "com.freezingshock.Cove.diagnostic-store")
    private let directory: URL

    private init() {
        let support = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory

        directory = support.appending(path: "Cove/Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: Reading

    /// Every saved report, newest first.
    func all() -> [StoredDiagnostic] {
        queue.sync { loadIndex() }
    }

    /// The full JSON for one report, or nil if the file is gone.
    func json(for id: UUID) -> Data? {
        queue.sync { try? Data(contentsOf: fileURL(for: id)) }
    }

    // MARK: Writing

    /// Saves one payload and its metadata, then prunes old reports.
    func save(json: Data, metadata: StoredDiagnostic) {
        queue.sync {
            do {
                try json.write(to: fileURL(for: metadata.id), options: .atomic)

                var index = loadIndex()
                index.insert(metadata, at: 0)

                for dropped in index.dropFirst(Self.maxReports) {
                    try? FileManager.default.removeItem(at: fileURL(for: dropped.id))
                }
                try writeIndex(Array(index.prefix(Self.maxReports)))
            } catch {
                log.error("Couldn't save diagnostic report: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Deletes every saved report. Wired to "Erase" in the Privacy pane.
    func eraseAll() {
        queue.sync {
            for item in loadIndex() {
                try? FileManager.default.removeItem(at: fileURL(for: item.id))
            }
            try? FileManager.default.removeItem(at: indexURL)
        }
    }

    // MARK: Files

    private var indexURL: URL {
        directory.appending(path: "index.json")
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    private func loadIndex() -> [StoredDiagnostic] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? Self.decoder.decode([StoredDiagnostic].self, from: data)) ?? []
    }

    private func writeIndex(_ index: [StoredDiagnostic]) throws {
        let data = try Self.encoder.encode(index)
        try data.write(to: indexURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
