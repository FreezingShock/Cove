//
//  AppThemeTests.swift
//  InletTests
//
//  Checks the theme color math, the clamping of stored values, the
//  Supporter gate, and the export and import file format.
//

import XCTest
@testable import Inlet

final class AppThemeTests: XCTestCase {

    func testHexParsingAcceptsLongAndShortForms() {
        XCTAssertEqual(ThemeColor.parseHex("#FF0000"), ThemeColor.RGB(r: 1, g: 0, b: 0))
        XCTAssertEqual(ThemeColor.parseHex("0f0"), ThemeColor.RGB(r: 0, g: 1, b: 0))
        XCTAssertNil(ThemeColor.parseHex("#12345"))
        XCTAssertNil(ThemeColor.parseHex("zzzzzz"))
    }

    func testHexWritesUpperCaseAndRoundTrips() {
        let color = ThemeColor.RGB(r: 0.039, g: 0.498, b: 0.455)
        XCTAssertEqual(ThemeColor.hex(color), "#0A7F74")
        XCTAssertEqual(ThemeColor.hex(ThemeColor.parseHex("#0a7f74")!), "#0A7F74")
    }

    func testTintKeepsBrightnessAndTakesTheTintHue() {
        let base = ThemeColor.RGB(r: 0.902, g: 0.925, b: 0.949)
        let warm = ThemeColor.RGB(r: 0.851, g: 0.796, b: 0.690)
        let result = ThemeColor.tinted(base, toward: warm, strength: 0.6)
        XCTAssertEqual(ThemeColor.hsb(result).brightness, ThemeColor.hsb(base).brightness, accuracy: 0.001)
        XCTAssertGreaterThan(result.r, result.b, "a warm tint should leave red above blue")
    }

    func testZeroTintStrengthLeavesTheBackgroundAlone() {
        let base = ThemeColor.RGB(r: 0.2, g: 0.4, b: 0.6)
        let tint = ThemeColor.RGB(r: 1, g: 0, b: 0)
        XCTAssertEqual(ThemeColor.tinted(base, toward: tint, strength: 0), base)
    }

    func testInkIsReadableOnEveryAccentWeTested() {
        for hex in ["#0A7F74", "#3FD9C9", "#FF8A4C", "#8E9AAF", "#4FB3FF"] {
            let fill = ThemeColor.parseHex(hex)!
            let ink = ThemeColor.inkOn(fill)
            XCTAssertGreaterThanOrEqual(ThemeColor.contrast(ink, fill), 4.0, hex)
        }
    }

    func testSanitizedClampsValuesAndDropsBadColors() {
        var theme = AppTheme.standard
        theme.tintHex = "not a color"
        theme.tintStrength = 4
        theme.glassIntensity = 0
        theme.backdropVeil = -2
        theme.iconSize = 200
        theme.name = "   "
        let clean = theme.sanitized
        XCTAssertNil(clean.tintHex)
        XCTAssertEqual(clean.tintStrength, 1)
        XCTAssertEqual(clean.glassIntensity, AppTheme.Limits.glass.lowerBound)
        XCTAssertEqual(clean.backdropVeil, 0)
        XCTAssertEqual(clean.iconSize, AppTheme.Limits.iconSize.upperBound)
        XCTAssertEqual(clean.name, "Untitled Theme")
    }

    func testEffectiveThemeNeedsSupporter() {
        let custom = [AppTheme(
            id: "custom.one", name: "One", accentHex: "#FF0000", tintHex: nil, tintStrength: 0,
            glassIntensity: 0.5, backdropVeil: 0.5, iconSize: 72, labelStyle: .standard
        )]
        XCTAssertEqual(AppTheme.effective(selectedID: "custom.one", custom: custom, supporter: false), .standard)
        XCTAssertEqual(AppTheme.effective(selectedID: "custom.one", custom: custom, supporter: true), custom[0])
        XCTAssertEqual(AppTheme.effective(selectedID: "missing", custom: custom, supporter: true), .standard)
    }

    func testExportThenImportGivesANewIDWithTheSameLook() throws {
        var theme = AppTheme.presets[1]
        theme.id = "custom.test"
        let data = try AppThemeFile.export(theme)
        let imported = try AppThemeFile.importTheme(from: data)
        XCTAssertNotEqual(imported.id, theme.id)
        XCTAssertEqual(imported.name, theme.name)
        XCTAssertEqual(imported.accentHex, theme.accentHex)
        XCTAssertEqual(imported.tintHex, theme.tintHex)
        XCTAssertEqual(imported.iconSize, theme.iconSize)
        XCTAssertEqual(imported.labelStyle, theme.labelStyle)
    }

    func testImportRejectsOtherJSON() {
        let data = Data("{\"hello\": 1}".utf8)
        XCTAssertThrowsError(try AppThemeFile.importTheme(from: data)) { error in
            XCTAssertEqual(error as? AppThemeFile.FileError, .notAnInletTheme)
        }
    }

    func testImportRejectsANewerFormat() throws {
        let future = AppThemeFile(format: AppThemeFile.formatTag, version: 2, theme: .standard)
        let data = try JSONEncoder().encode(future)
        XCTAssertThrowsError(try AppThemeFile.importTheme(from: data)) { error in
            XCTAssertEqual(error as? AppThemeFile.FileError, .newerVersion(2))
        }
    }

    func testImportRejectsABadColor() throws {
        var theme = AppTheme.standard
        theme.accentHex = "#GGGGGG"
        let file = AppThemeFile(format: AppThemeFile.formatTag, version: 1, theme: theme)
        let data = try JSONEncoder().encode(file)
        XCTAssertThrowsError(try AppThemeFile.importTheme(from: data)) { error in
            XCTAssertEqual(error as? AppThemeFile.FileError, .invalidColor)
        }
    }

    func testRuntimeFallsBackToStandardWithoutSupporter() {
        let suite = UserDefaults(suiteName: "InletTests.theme.\(UUID().uuidString)")!
        suite.set("preset.ember", forKey: InletSettings.Key.activeTheme.rawValue)
        suite.set(false, forKey: InletSettings.Key.supporterActive.rawValue)
        ThemeRuntime.loadFromDefaults(suite)
        XCTAssertEqual(ThemeRuntime.current, .standard)

        suite.set(true, forKey: InletSettings.Key.supporterActive.rawValue)
        ThemeRuntime.loadFromDefaults(suite)
        XCTAssertEqual(ThemeRuntime.current.id, "preset.ember")
        ThemeRuntime.current = .standard
    }
}
