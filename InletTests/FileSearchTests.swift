//
//  FileSearchTests.swift
//  InletTests
//
//  Checks the pure parts of file search: how typed text becomes Spotlight
//  terms, how file matches are ranked, and how a path is shown. No Spotlight
//  query runs here, so the tests are fast and do not depend on the disk.
//

import XCTest
@testable import Inlet

@MainActor
final class FileSearchTests: XCTestCase {

    private func file(_ name: String) -> FileItem {
        FileItem(url: URL(fileURLWithPath: "/Users/test/Documents/\(name)"), name: name, lastUsed: nil)
    }

    func testSearchTermsSplitOnSpacesAndStripSpecialCharacters() {
        XCTAssertEqual(FileSearch.searchTerms(from: "  re*port  \"q\" "), ["re", "port", "q"])
    }

    func testSearchTermsOfBlankTextIsEmpty() {
        XCTAssertTrue(FileSearch.searchTerms(from: "   ").isEmpty)
    }

    func testRankPutsExactNameThenPrefixThenOtherMatches() {
        let items = [file("my notes"), file("notes.txt"), file("notes")]

        let names = FileSearch.rank(items, for: "notes", limit: 10).map(\.name)

        XCTAssertEqual(names, ["notes", "notes.txt", "my notes"])
    }

    func testRankKeepsSpotlightOrderWithinTheSameRank() {
        let items = [file("b report.pdf"), file("a report.pdf")]

        let names = FileSearch.rank(items, for: "report", limit: 10).map(\.name)

        XCTAssertEqual(names, ["b report.pdf", "a report.pdf"])
    }

    func testRankStopsAtTheLimit() {
        let items = [file("a.txt"), file("b.txt"), file("c.txt")]

        XCTAssertEqual(FileSearch.rank(items, for: "txt", limit: 2).count, 2)
    }

    func testDisplayPathShortensTheHomeFolder() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let item = FileItem(url: URL(fileURLWithPath: home + "/Documents/plan.md"), name: "plan.md", lastUsed: nil)

        XCTAssertEqual(item.displayPath, "~/Documents")
    }

    func testRowsThatStopMatchingAreDropped() {
        let rows = [file("Report.pdf"), file("Reading List.txt"), file("Budget.xlsx")]

        XCTAssertEqual(FileSearch.keeping(rows, matching: ["rep"]).map(\.name), ["Report.pdf"])
    }

    func testEveryTypedWordMustAppearInTheRow() {
        let rows = [file("Tax Return 2025.pdf"), file("Tax Notes.pdf")]

        XCTAssertEqual(FileSearch.keeping(rows, matching: ["tax", "return"]).map(\.name), ["Tax Return 2025.pdf"])
    }
}
