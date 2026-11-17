//
//  LayoutStoreTests.swift
//  InletTests
//
//  Checks that the grid layout saves to disk, loads back after a relaunch,
//  and that a damaged file is moved aside instead of being lost or crashing.
//  Each test uses its own temporary folder.
//

import XCTest
@testable import Inlet

@MainActor
final class LayoutStoreTests: XCTestCase {

    private var directory: URL!

    private var fileURL: URL {
        directory.appendingPathComponent("layout.json")
    }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InletLayoutTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testFirstRunStartsWithAnEmptyLayout() {
        let store = LayoutStore(fileURL: fileURL)

        XCTAssertEqual(store.layout, GridLayout())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testChangesSurviveARelaunch() {
        let appID = "/Applications/Mail.app"
        let first = LayoutStore(fileURL: fileURL)
        first.update { $0.entries = [.app(appID)] }

        let relaunched = LayoutStore(fileURL: fileURL)

        XCTAssertEqual(relaunched.layout.entries, [.app(appID)])
    }

    func testUpdateThatChangesNothingWritesNothing() {
        let store = LayoutStore(fileURL: fileURL)

        store.update { _ in }

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testReconcileSavesTheTrimmedLayout() {
        let mail = AppItem(name: "Mail", url: URL(fileURLWithPath: "/Applications/Mail.app"), bundleIdentifier: nil, categoryType: nil)
        let gone = AppItem(name: "Gone", url: URL(fileURLWithPath: "/Applications/Gone.app"), bundleIdentifier: nil, categoryType: nil)
        let store = LayoutStore(fileURL: fileURL)
        store.update { $0 = GridLayout.makeDefault(for: [mail, gone]) }

        store.reconcile(with: [mail])

        XCTAssertEqual(store.layout.entries, [.app(mail.id)])
        XCTAssertEqual(LayoutStore(fileURL: fileURL).layout.entries, [.app(mail.id)])
    }

    func testUnreadableFileIsMovedAsideAndLayoutStartsFresh() throws {
        try Data("this is not json".utf8).write(to: fileURL)

        let store = LayoutStore(fileURL: fileURL)

        XCTAssertEqual(store.layout, GridLayout())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let aside = directory.appendingPathComponent("layout.unreadable.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: aside.path))
    }

    func testFileFromAnotherFormatVersionIsMovedAside() throws {
        let future = GridLayout(version: GridLayout.currentVersion + 1, entries: [.app("/Applications/X.app")])
        try JSONEncoder().encode(future).write(to: fileURL)

        let store = LayoutStore(fileURL: fileURL)

        XCTAssertEqual(store.layout, GridLayout())
        let aside = directory.appendingPathComponent("layout.unreadable.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: aside.path))
    }

    func testVersion1FileLoadsAndGainsGroupsOnReconcile() throws {
        // A layout saved before groups existed: the file has no groups key.
        let v1 = GridLayout(version: 1, entries: [.app("/Applications/Mail.app")])
        let encoded = try JSONEncoder().encode(v1)
        var object = (try JSONSerialization.jsonObject(with: encoded) as? [String: Any]) ?? [:]
        object.removeValue(forKey: "groups")
        try JSONSerialization.data(withJSONObject: object).write(to: fileURL)

        let store = LayoutStore(fileURL: fileURL)
        XCTAssertEqual(store.layout.entries, [.app("/Applications/Mail.app")])
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("layout.unreadable.json").path
        ), "A version 1 file must load, not be moved aside")

        let mail = AppItem(
            name: "Mail",
            url: URL(fileURLWithPath: "/Applications/Mail.app"),
            bundleIdentifier: nil,
            categoryType: "public.app-category.productivity"
        )
        store.reconcile(with: [mail])
        XCTAssertEqual(store.layout.version, GridLayout.currentVersion)
        XCTAssertEqual(store.layout.groups.count, 6)
        XCTAssertEqual(store.layout.groupID(containing: mail.id), "everyday")
    }
}
