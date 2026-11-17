//
//  InletSettingsTests.swift
//  InletTests
//
//  Checks the Settings defaults and clamps that the grid, search and quick
//  panel read, and that the grid's opening animation follows the column
//  count the user picked.
//

import CoreGraphics
import XCTest
@testable import Inlet

@MainActor
final class InletSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InletSettings.registerDefaults()
    }

    override func tearDown() {
        // Leave the test host's defaults as the app expects them.
        UserDefaults.standard.removeObject(forKey: InletSettings.Key.gridColumns.rawValue)
        UserDefaults.standard.removeObject(forKey: InletSettings.Key.diagnosticsEnabled.rawValue)
        super.tearDown()
    }

    func testCrashReportingIsOffByDefault() {
        UserDefaults.standard.removeObject(forKey: InletSettings.Key.diagnosticsEnabled.rawValue)
        InletSettings.registerDefaults()
        XCTAssertFalse(InletSettings.diagnosticsEnabled)
    }

    func testGridColumnsIsClampedToTheStepperRange() {
        UserDefaults.standard.set(3, forKey: InletSettings.Key.gridColumns.rawValue)
        XCTAssertEqual(InletSettings.gridColumns, 5)

        UserDefaults.standard.set(12, forKey: InletSettings.Key.gridColumns.rawValue)
        XCTAssertEqual(InletSettings.gridColumns, 9)

        UserDefaults.standard.set(0, forKey: InletSettings.Key.gridColumns.rawValue)
        XCTAssertEqual(InletSettings.gridColumns, 7, "A value never written falls back to 7")
    }

    func testOpeningAnimationCentersOnTheChosenColumnCount() {
        // With 3 columns, cell 4 is the middle of a 3 x 3 grid, so it
        // starts where it stands. The old code always used 7 columns.
        let middle = OpenPlacement.forCell(at: 4, total: 9, columns: 3)
        XCTAssertEqual(middle.offset, .zero)
        XCTAssertEqual(middle.delay, 0)

        let edge = OpenPlacement.forCell(at: 0, total: 9, columns: 3)
        XCTAssertNotEqual(edge.offset, .zero)
    }
}
