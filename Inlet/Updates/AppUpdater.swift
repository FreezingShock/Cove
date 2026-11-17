//
//  AppUpdater.swift
//  Inlet
//
//  Wires Sparkle (the auto-update framework) into Inlet.
//  Sparkle reads an "appcast" feed (SUFeedURL in Config/Info.plist), downloads
//  a newer build when one exists, checks its EdDSA signature against
//  SUPublicEDKey, and installs it. This file owns the updater and exposes the
//  few values the UI needs. Sparkle draws its own update windows.
//

import Combine
import Foundation
import Sparkle

/// One updater for the whole app. InletApp creates it once and keeps it alive.
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

    /// True when Xcode runs the unit tests inside this app. Xcode sets
    /// XCTestConfigurationFilePath for that. Sparkle's launch-time check can
    /// stall the test host, so the updater stays off during tests.
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// True once the real Sparkle public key is in Config/Info.plist. Until
    /// then the placeholder is still there, and Sparkle refuses every update,
    /// so the updater stays off instead of failing on each launch.
    static var hasPublicKey: Bool {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        return !key.isEmpty && !key.hasPrefix("REPLACE_WITH")
    }

    init() {
        // startingUpdater: true starts scheduled checks right away, but only
        // with a real signing key (see hasPublicKey). Both delegates are nil
        // because Inlet doesn't customise behaviour yet.
        let controller = SPUStandardUpdaterController(
            startingUpdater: !AppUpdater.isRunningUnitTests && AppUpdater.hasPublicKey,
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

        // The same KVO route for the last check date. The publisher emits the
        // current value on subscribe, so the row starts with the right date.
        controller.updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.lastCheckDate = value
            }
            .store(in: &cancellables)

        // Sparkle's schedule alone checks about once a day. Inlet also checks on
        // every launch, as long as automatic checks are on. Skipped in unit tests
        // and without a real signing key, the same as the scheduled checks.
        if !AppUpdater.isRunningUnitTests, AppUpdater.hasPublicKey,
           controller.updater.automaticallyChecksForUpdates {
            controller.updater.checkForUpdatesInBackground()
        }
    }

    /// A user-started check. Sparkle shows "You're up to date" or the update window.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// When Sparkle last checked for an update. nil before the first check.
    /// Published, so the Settings row redraws after a check finishes.
    @Published private(set) var lastCheckDate: Date?
}
