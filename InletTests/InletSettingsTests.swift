//
//  InletSettingsTests.swift
//  InletTests
//
//  Checks the range rules for the count settings. A zero is a real choice
//  for both counts ("no recent files", "no file rows"), so it must survive
//  instead of falling back to the default. These tests call the pure
//  helpers, so they never touch the user's UserDefaults.
//

import XCTest
@testable import Inlet

final class InletSettingsTests: XCTestCase {

    func testRecentFilesKeepsZero() {
        XCTAssertEqual(InletSettings.normalizedRecentFiles(0), 0)
    }

    func testRecentFilesIsClampedToFive() {
        XCTAssertEqual(InletSettings.normalizedRecentFiles(9), 5)
        XCTAssertEqual(InletSettings.normalizedRecentFiles(-2), 0)
    }

    func testRecentFilesKeepsValidValues() {
        XCTAssertEqual(InletSettings.normalizedRecentFiles(3), 3)
    }

    func testFileResultCountKeepsZero() {
        XCTAssertEqual(InletSettings.normalizedFileResultCount(0), 0)
    }

    func testFileResultCountIsClampedToEight() {
        XCTAssertEqual(InletSettings.normalizedFileResultCount(12), 8)
    }
}
