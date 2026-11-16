//
//  UpdatesSettingsSection.swift
//  Cove
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

            LabeledContent("Current version", value: AppVersion.display)

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

/// Reads the version numbers that Xcode writes into the app's Info.plist.
/// CFBundleShortVersionString is the marketing version (0.1). CFBundleVersion
/// is the build number Sparkle compares when it looks for updates.
enum AppVersion {
    static var display: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
