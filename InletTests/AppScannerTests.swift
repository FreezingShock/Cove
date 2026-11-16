//
//  AppScannerTests.swift
//  InletTests
//
//  Checks what the app scan promises: sorted output, no duplicate apps, and
//  the folders it searches. These run against the real disk, so they only
//  assert rules that hold on any Mac, not specific apps being present.
//

import XCTest
@testable import Inlet

final class AppScannerTests: XCTestCase {

    func testSearchesApplicationsFirstSoItWinsDuplicates() {
        let folders = AppScanner.searchFolders

        XCTAssertEqual(folders.first?.path, "/Applications")
        XCTAssertTrue(folders.contains { $0.path == "/System/Applications" })
    }

    func testScanFindsAtLeastOneApp() {
        XCTAssertFalse(AppScanner.scanInstalledApps().isEmpty)
    }

    func testScanIsSortedLikeFinder() {
        let names = AppScanner.scanInstalledApps().map(\.name)

        let sorted = names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        XCTAssertEqual(names, sorted)
    }

    func testScanHasNoDuplicatePathsOrBundleIDs() {
        let apps = AppScanner.scanInstalledApps()

        XCTAssertEqual(Set(apps.map(\.id)).count, apps.count)

        let bundleIDs = apps.compactMap(\.bundleIdentifier)
        XCTAssertEqual(Set(bundleIDs).count, bundleIDs.count)
    }

    func testEveryScannedAppIsAnAppBundle() {
        for app in AppScanner.scanInstalledApps() {
            XCTAssertEqual(app.url.pathExtension, "app", "\(app.url.path) is not an .app bundle")
            XCTAssertFalse(app.name.hasSuffix(".app"), "\(app.name) still has the .app suffix")
        }
    }

    /// Records how long a full scan takes. The number shows in Xcode's
    /// test report and can be compared between runs; it does not fail the test.
    func testScanTiming() {
        measure {
            _ = AppScanner.scanInstalledApps()
        }
    }
}
