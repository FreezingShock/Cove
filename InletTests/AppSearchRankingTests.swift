//
//  AppSearchRankingTests.swift
//  InletTests
//
//  Checks how app search ranks matches: exact, prefix, word, initials, and
//  loose letter matches, plus launch counts breaking ties.
//

import XCTest
@testable import Inlet

final class AppSearchRankingTests: XCTestCase {

    private func app(_ name: String) -> AppItem {
        AppItem(
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: nil,
            categoryType: nil
        )
    }

    func testInitialsFindMultiWordName() {
        let apps = [app("Visual Studio Code"), app("Chrome"), app("Mail")]

        XCTAssertEqual(AppSearch.results(for: "vsc", in: apps).map(\.name), ["Visual Studio Code"])
    }

    func testLettersInOrderFindNameWithGaps() {
        let apps = [app("Visual Studio Code"), app("Chrome"), app("Mail")]

        XCTAssertEqual(AppSearch.results(for: "chrm", in: apps).map(\.name), ["Chrome"])
    }

    func testTwoLettersDoNotMatchLooseLetters() {
        let apps = [app("Chrome")]

        XCTAssertTrue(AppSearch.results(for: "cm", in: apps).isEmpty)
    }

    func testExactMatchComesBeforePrefix() {
        let apps = [app("Mail Merge"), app("Mail")]

        XCTAssertEqual(AppSearch.results(for: "mail", in: apps).map(\.name), ["Mail", "Mail Merge"])
    }

    func testLaunchCountBreaksTiesWithinARank() {
        let mailMerge = app("Mail Merge")
        let mailNotes = app("Mail Notes")
        let usage = [mailNotes.id: 3]

        let results = AppSearch.results(for: "mail", in: [mailMerge, mailNotes], usage: usage)

        XCTAssertEqual(results.map(\.name), ["Mail Notes", "Mail Merge"])
    }

    func testLaunchCountNeverBeatsABetterRank() {
        let gmail = app("Gmail")
        let mailMerge = app("Mail Merge")
        let usage = [gmail.id: 99]

        let results = AppSearch.results(for: "mail", in: [gmail, mailMerge], usage: usage)

        XCTAssertEqual(results.map(\.name), ["Mail Merge", "Gmail"])
    }

    func testEmptyQueryKeepsEveryAppInOrder() {
        let apps = [app("Mail"), app("Chrome"), app("Notes")]

        XCTAssertEqual(AppSearch.results(for: "   ", in: apps), apps)
    }
}
