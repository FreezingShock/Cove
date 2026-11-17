//
//  HotCornerTests.swift
//  InletTests
//
//  Checks which screen points count as a hot corner. Plain geometry, so no
//  window or event is needed.
//

import CoreGraphics
import XCTest
@testable import Inlet

final class HotCornerTests: XCTestCase {
    /// A 1440 x 900 screen with its origin at zero. The top edge is y = 900.
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testTopLeftNeedsBothTopAndLeftEdges() {
        XCTAssertTrue(HotCorner.topLeft.contains(CGPoint(x: 1, y: 899), in: screen))
        // Bottom-left corner is a different corner.
        XCTAssertFalse(HotCorner.topLeft.contains(CGPoint(x: 1, y: 1), in: screen))
        // Top edge, but not the left one.
        XCTAssertFalse(HotCorner.topLeft.contains(CGPoint(x: 720, y: 899), in: screen))
    }

    func testEachCornerMatchesOnlyItself() {
        let corners: [(HotCorner, CGPoint)] = [
            (.topLeft, CGPoint(x: 0, y: 900)),
            (.topRight, CGPoint(x: 1440, y: 900)),
            (.bottomLeft, CGPoint(x: 0, y: 0)),
            (.bottomRight, CGPoint(x: 1440, y: 0)),
        ]
        for (corner, point) in corners {
            XCTAssertTrue(corner.contains(point, in: screen), "\(corner) should match its own corner")
            for (other, _) in corners where other != corner {
                XCTAssertFalse(other.contains(point, in: screen), "\(other) should not match \(corner)")
            }
        }
    }

    func testCenterOfScreenMatchesNoCorner() {
        let center = CGPoint(x: 720, y: 450)
        for corner in HotCorner.allCases {
            XCTAssertFalse(corner.contains(center, in: screen), "\(corner) matched the center")
        }
    }

    func testOffNeverMatches() {
        XCTAssertFalse(HotCorner.off.contains(CGPoint(x: 0, y: 900), in: screen))
    }

    func testScreenOriginOffsetIsRespected() {
        // A second display to the right of the main one, with its top edge at y = 900.
        let second = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        XCTAssertTrue(HotCorner.topRight.contains(CGPoint(x: 3359, y: 1079), in: second))
        XCTAssertFalse(HotCorner.topRight.contains(CGPoint(x: 1440, y: 0), in: second))
    }

    func testRawValuesRoundTrip() {
        for corner in HotCorner.allCases {
            XCTAssertEqual(HotCorner(rawValue: corner.rawValue), corner)
        }
    }
}
