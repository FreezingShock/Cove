//
//  GridZoneTests.swift
//  InletTests
//
//  Checks zone placement (overlap, bounds, fitting to a column count) and
//  which apps a zone holds, including hidden apps and the first-zone rule.
//

import XCTest
@testable import Inlet

final class GridZoneTests: XCTestCase {

    private func zone(_ id: String, column: Int, row: Int, width: Int, height: Int = 1, groups: [String] = []) -> GridZone {
        GridZone(id: id, name: id, column: column, row: row, width: width, height: height, groupIDs: groups)
    }

    private func app(_ name: String) -> AppItem {
        AppItem(
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: nil,
            categoryType: nil
        )
    }

    func testOverlapIsDetected() {
        let a = zone("a", column: 0, row: 0, width: 3)
        XCTAssertTrue(a.overlaps(zone("b", column: 2, row: 0, width: 2)))
        XCTAssertFalse(a.overlaps(zone("c", column: 3, row: 0, width: 2)), "touching edges is not overlap")
        XCTAssertFalse(a.overlaps(zone("d", column: 0, row: 1, width: 3)))
    }

    func testFitsRejectsOutOfBoundsAndOverlap() {
        let a = zone("a", column: 0, row: 0, width: 2)
        XCTAssertTrue(ZoneLayout.fits(a, columns: 7, among: []))
        XCTAssertFalse(ZoneLayout.fits(zone("b", column: 6, row: 0, width: 2), columns: 7, among: []))
        XCTAssertFalse(ZoneLayout.fits(zone("c", column: 1, row: 0, width: 2), columns: 7, among: [a]))
        XCTAssertFalse(ZoneLayout.fits(zone("d", column: 0, row: 0, width: 1, height: 5), columns: 7, among: []))
        XCTAssertFalse(ZoneLayout.fits(zone("e", column: 0, row: -1, width: 1), columns: 7, among: []))
    }

    func testFittedClampsToTheGrid() {
        let fitted = zone("a", column: 6, row: 0, width: 4, height: 9).fitted(columns: 5)
        XCTAssertEqual(fitted.width, 4)
        XCTAssertEqual(fitted.column, 1)
        XCTAssertEqual(fitted.height, GridZone.maxHeight)
        XCTAssertTrue(ZoneLayout.fits(fitted, columns: 5, among: []))
    }

    func testBandRowsCountsTheTallestZone() {
        XCTAssertEqual(ZoneLayout.bandRows([]), 0)
        let rows = ZoneLayout.bandRows([
            zone("a", column: 0, row: 0, width: 2, height: 2),
            zone("b", column: 3, row: 1, width: 2, height: 3),
        ])
        XCTAssertEqual(rows, 4)
    }

    func testAnAppGoesToTheFirstZoneThatHoldsItsGroup() {
        let mail = app("Mail")
        let notes = app("Notes")
        let games = app("Chess")
        let groupOf: (AppItem) -> String = { $0.name == "Chess" ? "games" : "everyday" }

        let zones = [
            zone("first", column: 0, row: 0, width: 2, groups: ["everyday"]),
            zone("second", column: 3, row: 0, width: 2, groups: ["everyday", "games"]),
        ]
        let contents = ZoneLayout.contents(of: zones, apps: [mail, notes, games], hidden: [], groupOf: groupOf)

        XCTAssertEqual(contents["first"]?.map(\.name), ["Mail", "Notes"])
        XCTAssertEqual(contents["second"]?.map(\.name), ["Chess"])
    }

    func testHiddenAppsStayOutOfEveryZone() {
        let mail = app("Mail")
        let zones = [zone("only", column: 0, row: 0, width: 2, groups: ["everyday"])]
        let contents = ZoneLayout.contents(
            of: zones,
            apps: [mail],
            hidden: [mail.id],
            groupOf: { _ in "everyday" }
        )
        XCTAssertEqual(contents["only"], [])
    }
}
