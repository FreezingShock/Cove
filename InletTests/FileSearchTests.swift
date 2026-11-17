//
//  FileSearchTests.swift
//  InletTests
//
//  Checks the rules that run while the search text changes: rows that no
//  longer match the typed words leave the list at once, and the words are
//  split the same way the Spotlight query reads them.
//

import Foundation
import XCTest
@testable import Inlet

@MainActor
final class FileSearchTests: XCTestCase {

    private func file(_ name: String) -> FileItem {
        FileItem(url: URL(fileURLWithPath: "/Users/test/\(name)"), name: name, lastUsed: nil)
    }

    func testRowsThatStopMatchingAreDropped() {
        let rows = [file("Report.pdf"), file("Reading List.txt"), file("Budget.xlsx")]
        let kept = FileSearch.keeping(rows, matching: ["rep"])
        XCTAssertEqual(kept.map(\.name), ["Report.pdf"])
    }

    func testEveryTypedWordMustAppear() {
        let rows = [file("Tax Return 2025.pdf"), file("Tax Notes.pdf")]
        let kept = FileSearch.keeping(rows, matching: ["tax", "return"])
        XCTAssertEqual(kept.map(\.name), ["Tax Return 2025.pdf"])
    }

    func testSearchTermsSplitOnSpacesAndStripWildcards() {
        XCTAssertEqual(FileSearch.searchTerms(from: "  tax*  return? "), ["tax", "return"])
    }
}
