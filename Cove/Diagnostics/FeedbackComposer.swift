//
//  FeedbackComposer.swift
//  Cove
//
//  Builds the text for a feedback or crash report. The text goes to the
//  clipboard or into a GitHub issue URL that the user opens in their browser.
//  Cove never sends it on its own.
//

import Foundation

enum FeedbackComposer {
    /// Opens a blank new-issue form on the public repo.
    static let newIssueURL = "https://github.com/FreezingShock/Cove/issues/new"

    /// Keeps the issue URL under the length GitHub accepts reliably.
    static let maxEncodedBodyLength = 6_000

    /// The short report: the user's note, app and macOS versions, and one
    /// line per crash report. This is what the preview shows and what the
    /// issue body starts with.
    static func summary(note: String, reports: [StoredDiagnostic]) -> String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = []
        lines.append("## What happened")
        lines.append(trimmed.isEmpty ? "_No description given._" : trimmed)
        lines.append("")
        lines.append("## Environment")
        lines.append("- Cove \(Bundle.main.appVersionString)")
        lines.append("- \(ProcessInfo.processInfo.operatingSystemVersionString)")

        if !reports.isEmpty {
            lines.append("")
            lines.append("## Crash reports (\(reports.count))")
            for report in reports {
                let when = report.periodEnd.formatted(date: .abbreviated, time: .shortened)
                lines.append(
                    "- \(when): \(report.crashCount) crash, \(report.hangCount) hang, " +
                    "\(report.cpuExceptionCount) CPU exception, " +
                    "\(report.diskWriteExceptionCount) disk write exception"
                )
            }
        }
        return lines.joined(separator: "\n")
    }

    /// The summary plus the raw JSON of each report. Used by "Copy Full Report".
    static func fullReport(
        note: String,
        reports: [StoredDiagnostic],
        jsonFor: (UUID) -> Data?
    ) -> String {
        var text = summary(note: note, reports: reports)

        for report in reports {
            guard let data = jsonFor(report.id) else { continue }
            let json = String(decoding: data, as: UTF8.self)
            text += "\n\n### Diagnostic report \(report.id.uuidString)\n```json\n\(json)\n```"
        }
        return text
    }

    /// A new-issue URL with the summary prefilled in the body.
    /// Long bodies are cut down, and the user is told to paste the full
    /// report from the clipboard.
    static func issueURL(note: String, reports: [StoredDiagnostic]) -> URL? {
        let title = reports.isEmpty
            ? "Feedback for Cove \(Bundle.main.appVersionString)"
            : "Crash report for Cove \(Bundle.main.appVersionString)"

        var body = summary(note: note, reports: reports)
        var truncated = false
        while encoded(body).count > maxEncodedBodyLength, body.count > 500 {
            body = String(body.prefix(body.count * 4 / 5))
            truncated = true
        }
        if truncated {
            body += "\n\n_Report cut short. Paste the full report from Cove's Copy Full Report button._"
        }

        return URL(string: "\(newIssueURL)?title=\(encoded(title))&body=\(encoded(body))")
    }

    // MARK: Helpers

    /// Percent-encodes a query value. Only unreserved characters pass through,
    /// so `+` and `&` in the text can't be read as separators.
    private static func encoded(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

extension Bundle {
    /// "1.0 (42)" style version string from Info.plist.
    var appVersionString: String {
        let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
