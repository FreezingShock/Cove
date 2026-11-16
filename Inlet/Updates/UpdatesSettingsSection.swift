//
//  UpdatesSettingsSection.swift
//  Inlet
//
//  The "Updates" block for the Settings window. It is a plain SwiftUI `Section`,
//  so any `Form` can host it. Put it inside the About or General pane.
//

import SwiftUI

struct UpdatesSettingsSection: View {
    /// The shared updater. The parent view passes it in.
    @ObservedObject var updater: AppUpdater

    var body: some View {
        Section("Updates") {
            // `$updater.automaticallyChecks` is a Binding. Toggling it updates
            // the @Published value, whose didSet tells Sparkle.
            Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)

            LabeledContent("Last checked") {
                Text(lastCheckedText)
                    .foregroundStyle(.secondary)
            }

            // Disabled while Sparkle is already checking, so users can't stack checks.
            Button("Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }

    private var lastCheckedText: String {
        guard let date = updater.lastCheckDate else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
