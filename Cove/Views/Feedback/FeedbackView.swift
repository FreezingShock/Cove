//
//  FeedbackView.swift
//  Cove
//
//  The Send Feedback form. Nothing is sent from here. The buttons copy the
//  report or open a prefilled GitHub issue in the browser, and the user
//  submits it there.
//

import AppKit
import SwiftUI

struct FeedbackView: View {
    @State private var note = ""
    @State private var reports: [StoredDiagnostic] = []
    /// Reports the user has left checked. New reports start checked.
    @State private var included: Set<UUID> = []
    @State private var copied = false

    private var includedReports: [StoredDiagnostic] {
        reports.filter { included.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            noteField
            crashReportList
            preview
            Spacer(minLength: 0)
            actions
        }
        .padding(24)
        .frame(width: 520, height: 640, alignment: .topLeading)
        .preferredColorScheme(.dark)
        .onAppear(perform: reload)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Send Feedback")
                .font(.title2.weight(.semibold))
            Text("Nothing is sent from Cove. Opening an issue takes you to GitHub in your browser. You can read everything there before you submit it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What happened, or what would you like to see?")
                .font(.headline)
            TextEditor(text: $note)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(6)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var crashReportList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Crash reports")
                .font(.headline)

            if reports.isEmpty {
                Text("None saved. To collect crash reports, turn on crash reporting in Settings > Privacy. Reports from crashes are saved here, and you choose which ones to share.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(reports) { report in
                    Toggle(isOn: binding(for: report.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.periodEnd.formatted(date: .abbreviated, time: .shortened))
                            Text(detailLine(for: report))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    private var preview: some View {
        DisclosureGroup("Preview what will be shared") {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView {
                    Text(FeedbackComposer.summary(note: note, reports: includedReports))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 120)

                Text("Copy Full Report also includes the raw JSON for each checked crash report.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 6)
        }
    }

    private var actions: some View {
        HStack {
            Button(copied ? "Copied" : "Copy Full Report") {
                copyFullReport()
            }

            Spacer()

            Button("Open GitHub Issue") {
                openIssue()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: Actions

    private func reload() {
        reports = DiagnosticStore.shared.all()
        included = Set(reports.map(\.id))
    }

    private func copyFullReport() {
        let text = FeedbackComposer.fullReport(note: note, reports: includedReports) {
            DiagnosticStore.shared.json(for: $0)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
    }

    private func openIssue() {
        guard let url = FeedbackComposer.issueURL(note: note, reports: includedReports) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Helpers

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { included.contains(id) },
            set: { isOn in
                if isOn {
                    included.insert(id)
                } else {
                    included.remove(id)
                }
            }
        )
    }

    private func detailLine(for report: StoredDiagnostic) -> String {
        "\(report.crashCount) crash, \(report.hangCount) hang, " +
        "\(report.cpuExceptionCount) CPU, \(report.diskWriteExceptionCount) disk · " +
        "Cove \(report.appVersion) · \(report.osVersion)"
    }
}
