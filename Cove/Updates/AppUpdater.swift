//
//  AppUpdater.swift
//  Cove
//
//  Wires Sparkle (the auto-update framework) into Cove.
//  Sparkle reads an "appcast" feed (SUFeedURL in Config/Info.plist), downloads
//  a newer build when one exists, checks its EdDSA signature against
//  SUPublicEDKey, and installs it. This file owns the updater and exposes the
//  few values the UI needs. Sparkle draws its own update windows.
//

import Combine
import Foundation
import Sparkle

/// One updater for the whole app. CoveApp creates it once and keeps it alive.
@MainActor
final class AppUpdater: ObservableObject {
    /// Sparkle's ready-made controller. It starts the updater when created,
    /// runs scheduled background checks, and shows Sparkle's update window.
    let controller: SPUStandardUpdaterController

    /// False while Sparkle is already checking. Menu items use it to grey out.
    @Published private(set) var canCheckForUpdates = false

    /// Mirrors Sparkle's "check automatically" setting. Writing to it passes
    /// the value straight through to Sparkle (see `didSet`).
    @Published var automaticallyChecks: Bool {
        didSet {
            controller.updater.automaticallyChecksForUpdates = automaticallyChecks
        }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        // startingUpdater: true starts scheduled checks right away.
        // Both delegates are nil because Cove doesn't customise behaviour yet.
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        self.automaticallyChecks = controller.updater.automaticallyChecksForUpdates

        // Sparkle publishes canCheckForUpdates through KVO (Key-Value Observing).
        // Combine turns that into a stream we can copy into a @Published property,
        // so SwiftUI redraws when it changes.
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
            .store(in: &cancellables)
    }

    /// A user-started check. Sparkle shows "You're up to date" or the update window.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// When Sparkle last checked for an update. nil before the first check.
    var lastCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }
}
