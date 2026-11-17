//
//  AppFolderWatcherTests.swift
//  InletTests
//
//  Checks which file-system changes trigger an app rescan. The watcher itself
//  needs a real FSEvents stream, so these tests cover the filter it uses.
//

import XCTest
@testable import Inlet

@MainActor
final class AppFolderWatcherTests: XCTestCase {

    func testInstalledOrRemovedAppBundleIsRelevant() {
        XCTAssertTrue(AppFolderWatcher.isRelevant("/Applications/Notes.app"))
        XCTAssertTrue(AppFolderWatcher.isRelevant("/Users/someone/Applications/Chrome Apps/Gmail.app"))
    }

    func testChangeInsideAppBundleIsIgnored() {
        XCTAssertFalse(AppFolderWatcher.isRelevant("/Applications/Notes.app/Contents/Info.plist"))
        XCTAssertFalse(AppFolderWatcher.isRelevant("/Applications/Notes.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle"))
    }

    func testNewSubfolderIsRelevant() {
        // A new folder can hold apps (for example a new Setapp or Utilities folder).
        XCTAssertTrue(AppFolderWatcher.isRelevant("/Applications/Setapp"))
    }

    func testSearchFoldersThatExistIncludeApplications() {
        XCTAssertTrue(AppScanner.existingSearchFolderPaths.contains("/Applications"))
    }

    func testWatcherIgnoresEmptyPathList() {
        let watcher = AppFolderWatcher(paths: []) {}
        watcher.start()
        watcher.stop()
    }
}
