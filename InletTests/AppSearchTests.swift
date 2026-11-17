//
//  AppSearchTests.swift
//  InletTests
//
//  Checks how the search field matches app names: case and accents are
//  ignored, better matches come first, and every typed word has to match
//  with the words in any order.
//

import Foundation
import XCTest
@testable import Inlet

final class AppSearchTests: XCTestCase {

    /// An app whose ID is `/Applications/<name>.app`, matching `AppItem.id`.
    private func app(_ name: String) -> AppItem {
        AppItem(
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: nil,
            categoryType: nil
        )
    }

    private func names(_ query: String, in apps: [String]) -> [String] {
        AppSearch.results(for: query, in: apps.map { self.app($0) }).map(\.name)
    }

    func testEmptyQueryKeepsEveryAppInOrder() {
        XCTAssertEqual(names("  ", in: ["Mail", "Notes"]), ["Mail", "Notes"])
    }

    func testExactThenPrefixThenWordThenContains() {
        let found = names("mail", in: ["Gmail Archive", "Apple Mail", "Mail Merge", "Mail"])
        XCTAssertEqual(found, ["Mail", "Mail Merge", "Apple Mail", "Gmail Archive"])
    }

    func testIgnoresCaseAndAccents() {
        XCTAssertEqual(names("cafe", in: ["Café"]), ["Café"])
        XCTAssertEqual(names("SAFARI", in: ["Safari"]), ["Safari"])
    }

    func testWordsMatchInAnyOrder() {
        XCTAssertEqual(names("mail apple", in: ["Apple Mail"]), ["Apple Mail"])
    }

    func testEveryWordMustMatch() {
        XCTAssertEqual(names("photo zzz", in: ["Adobe Photoshop"]), [])
    }

    func testWordsCanSitInsideAWord() {
        XCTAssertEqual(names("photo shop", in: ["Adobe Photoshop"]), ["Adobe Photoshop"])
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertEqual(names("xyz", in: ["Mail", "Notes"]), [])
    }
}
