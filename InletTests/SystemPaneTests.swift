//
//  SystemPaneTests.swift
//  InletTests
//
//  Checks that System Settings pane search finds the right pane, and that
//  every deep link is a valid URL.
//

import XCTest
@testable import Inlet

final class SystemPaneTests: XCTestCase {

    func testKeywordFindsPane() {
        XCTAssertEqual(SystemPane.matches(for: "wifi", limit: 3).first?.title, "Wi-Fi")
    }

    func testPrefixFindsPane() {
        XCTAssertEqual(SystemPane.matches(for: "privacy", limit: 3).first?.title, "Privacy & Security")
    }

    func testEmptyQueryFindsNothing() {
        XCTAssertTrue(SystemPane.matches(for: "   ", limit: 3).isEmpty)
    }

    func testLimitIsRespected() {
        XCTAssertEqual(SystemPane.matches(for: "sound", limit: 1).count, 1)
    }

    func testEveryLinkIsAValidURL() {
        for pane in SystemPane.all {
            XCTAssertNotNil(pane.url, "\(pane.title) has an invalid link")
        }
    }
}
