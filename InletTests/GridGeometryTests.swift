//
//  GridGeometryTests.swift
//  InletTests
//
//  Checks the paged grid's slot math and hit testing: every slot's center
//  maps back to its own slot, gaps between rows hit nothing, later pages
//  continue the count, and the drag edge zones are where they should be.
//

import CoreGraphics
import XCTest
@testable import Inlet

final class GridGeometryTests: XCTestCase {

    /// 3 columns x 2 rows of 100 x 120 cells with a 10 pt row gap, on a 300 pt page.
    private let geo = GridGeometry(
        columns: 3,
        rows: 2,
        cellSize: CGSize(width: 100, height: 120),
        rowSpacing: 10,
        origin: .zero,
        pageWidth: 300
    )

    func testPageCountIsAtLeastOne() {
        XCTAssertEqual(geo.pageCount(itemCount: 0), 1)
        XCTAssertEqual(geo.pageCount(itemCount: 6), 1)
        XCTAssertEqual(geo.pageCount(itemCount: 7), 2)
    }

    func testCenterOfEachSlotHitsThatSlot() {
        for index in 0..<(geo.perPage * 2) {
            XCTAssertEqual(geo.index(at: geo.center(ofIndex: index)), index, "slot \(index)")
        }
    }

    func testGapBetweenRowsHitsNothing() {
        // The first row ends at y = 120 and the second starts at y = 130.
        XCTAssertNil(geo.index(at: CGPoint(x: 50, y: 125)))
    }

    func testLaterPagesKeepCounting() {
        let center = geo.center(ofIndex: 6)
        XCTAssertGreaterThan(center.x, geo.pageWidth)
        XCTAssertEqual(geo.index(at: center), 6)
    }

    func testEdgeZonesFlipOnlyNearTheEdges() {
        XCTAssertEqual(GridMetrics.edgeDirection(x: 10, pageWidth: 300), -1)
        XCTAssertEqual(GridMetrics.edgeDirection(x: 290, pageWidth: 300), 1)
        XCTAssertEqual(GridMetrics.edgeDirection(x: 150, pageWidth: 300), 0)
    }
}
