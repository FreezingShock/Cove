//
//  QuickCalcTests.swift
//  InletTests
//
//  Checks the search-field calculator: precedence, right-to-left powers,
//  bad input that must return nil instead of crashing, and number formatting.
//

import XCTest
@testable import Inlet

final class QuickCalcTests: XCTestCase {

    func testMultiplicationBindsTighterThanAddition() {
        XCTAssertEqual(QuickCalc.evaluate("2+2*3"), 8)
    }

    func testParenthesesOverridePrecedence() {
        XCTAssertEqual(QuickCalc.evaluate("(1+2)*3"), 9)
    }

    func testPowersAreRightToLeft() {
        XCTAssertEqual(QuickCalc.evaluate("2^3^2"), 512)
    }

    func testLeadingMinusInsideAnExpression() {
        XCTAssertEqual(QuickCalc.evaluate("-3+5"), 2)
    }

    func testDivisionKeepsDecimals() {
        XCTAssertEqual(QuickCalc.evaluate("10/4"), 2.5)
    }

    func testMultiplySignAndSpacesAreAccepted() {
        XCTAssertEqual(QuickCalc.evaluate("2 × 3"), 6)
    }

    func testDivisionByZeroIsNil() {
        XCTAssertNil(QuickCalc.evaluate("1/0"))
    }

    func testPlainNumberIsNotACalculation() {
        XCTAssertNil(QuickCalc.evaluate("42"))
        XCTAssertNil(QuickCalc.evaluate("-5"))
    }

    func testWordsAreNotACalculation() {
        XCTAssertNil(QuickCalc.evaluate("mail"))
    }

    func testIncompleteExpressionsAreNil() {
        XCTAssertNil(QuickCalc.evaluate("2+"))
        XCTAssertNil(QuickCalc.evaluate("(2+3"))
        XCTAssertNil(QuickCalc.evaluate("3.5.2+1"))
        XCTAssertNil(QuickCalc.evaluate("1e5+1"))
    }

    func testWholeNumbersHaveNoDecimalPoint() {
        XCTAssertEqual(QuickCalc.format(8), "8")
        XCTAssertEqual(QuickCalc.format(-0.0), "0")
    }

    func testFractionsKeepTenSignificantDigits() {
        XCTAssertEqual(QuickCalc.format(2.5), "2.5")
        XCTAssertEqual(QuickCalc.format(1.0 / 3.0), "0.3333333333")
    }
}
