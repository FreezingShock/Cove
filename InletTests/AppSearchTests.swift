//
//  AppSearchTests.swift
//  InletTests
//
//  Checks the rules behind the search field: accents and case are ignored,
//  exact names beat prefixes, prefixes beat word matches, and an empty query
//  keeps the grid as it was.
//

import XCTest
@testable import Inlet

final class AppSearchTests: XCTestCase {

    private func app(_ name: String) -> AppItem {
        AppItem(
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: nil,
            categoryType: nil
        )
    }

    func testEmptyQueryReturnsEveryAppInOrder() {
        let apps = [app("Mail"), app("Maps"), app("Notes")]

        XCTAssertEqual(AppSearch.results(for: "   ", in: apps), apps)
    }

    func testExactThenPrefixThenWordThenContains() {
        let apps = [app("Gmail Archive"), app("Apple Mail"), app("Mail Merge"), app("Mail")]

        let names = AppSearch.results(for: "mail", in: apps).map(\.name)

        XCTAssertEqual(names, ["Mail", "Mail Merge", "Apple Mail", "Gmail Archive"])
    }

    func testIgnoresCaseAndAccents() {
        let apps = [app("Café"), app("Safari")]

        XCTAssertEqual(AppSearch.results(for: "CAFE", in: apps).map(\.name), ["Café"])
        XCTAssertEqual(AppSearch.results(for: "safari", in: apps).map(\.name), ["Safari"])
    }

    func testNoMatchReturnsNothing() {
        let apps = [app("Mail"), app("Notes")]

        XCTAssertTrue(AppSearch.results(for: "zzz", in: apps).isEmpty)
    }

    func testTiesKeepGridOrder() {
        // Both names are word matches for "pro", so the input order must hold.
        let apps = [app("Adobe Pro"), app("Xcode Pro")]

        XCTAssertEqual(AppSearch.results(for: "pro", in: apps).map(\.name), ["Adobe Pro", "Xcode Pro"])
    }
}
