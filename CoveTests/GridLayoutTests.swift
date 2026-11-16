//
//  GridLayoutTests.swift
//  CoveTests
//
//  Checks the grid's layout rules: default order, reconciling with the apps
//  installed right now, folder limits, hiding and restoring apps. All of it
//  is plain data, so no window or disk access is needed.
//

import XCTest
@testable import Cove

final class GridLayoutTests: XCTestCase {

    // MARK: - Helpers

    /// An app whose ID is `/Applications/<name>.app`, matching `AppItem.id`.
    private func app(_ name: String) -> AppItem {
        AppItem(
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: "com.example.\(name)",
            categoryType: nil
        )
    }

    private func appID(_ name: String) -> String {
        "/Applications/\(name).app"
    }

    private func folder(_ id: String, _ name: String, apps: [String]) -> GridFolder {
        GridFolder(id: id, name: name, appIDs: apps.map(appID))
    }

    // MARK: - Default layout

    func testDefaultLayoutKeepsGivenOrderAndHidesNothing() {
        let apps = [app("Calendar"), app("Mail"), app("Notes")]

        let layout = GridLayout.makeDefault(for: apps)

        XCTAssertEqual(layout.version, GridLayout.currentVersion)
        XCTAssertEqual(layout.entries, [
            .app(appID("Calendar")),
            .app(appID("Mail")),
            .app(appID("Notes")),
        ])
        XCTAssertTrue(layout.hidden.isEmpty)
    }

    // MARK: - Reconciling with installed apps

    func testReconcileDropsUninstalledApps() {
        let layout = GridLayout(entries: [
            .app(appID("Calendar")),
            .app(appID("Mail")),
            .app(appID("Notes")),
        ])

        let result = layout.reconciled(with: [app("Calendar"), app("Notes")])

        XCTAssertEqual(result.entries, [.app(appID("Calendar")), .app(appID("Notes"))])
    }

    func testReconcileAppendsNewAppsAtTheEnd() {
        let layout = GridLayout(entries: [.app(appID("Mail"))])

        let result = layout.reconciled(with: [app("Calendar"), app("Mail"), app("Notes")])

        XCTAssertEqual(result.entries, [
            .app(appID("Mail")),
            .app(appID("Calendar")),
            .app(appID("Notes")),
        ])
    }

    func testFolderWithOneInstalledAppTurnsBackIntoAPlainApp() {
        let layout = GridLayout(entries: [
            .folder(folder("f1", "Work", apps: ["Mail", "Slack"])),
        ])

        let result = layout.reconciled(with: [app("Mail")])

        XCTAssertEqual(result.entries, [.app(appID("Mail"))])
    }

    func testFolderWithNoInstalledAppsIsRemoved() {
        let layout = GridLayout(entries: [
            .folder(folder("f1", "Old", apps: ["Gone"])),
            .app(appID("Mail")),
        ])

        let result = layout.reconciled(with: [app("Mail")])

        XCTAssertEqual(result.entries, [.app(appID("Mail"))])
    }

    func testAppAlreadyOnGridIsNotDuplicatedByAFolder() {
        let layout = GridLayout(entries: [
            .app(appID("Mail")),
            .folder(folder("f1", "Work", apps: ["Mail", "Slack"])),
        ])

        let result = layout.reconciled(with: [app("Mail"), app("Slack")])

        // Mail stays on the grid once. Slack is left alone in the folder,
        // which now holds one app, so it becomes a plain app.
        XCTAssertEqual(result.entries, [.app(appID("Mail")), .app(appID("Slack"))])
    }

    func testFolderOverflowMovesOntoTheGridAfterTheFolder() {
        let names = (0..<10).map { "App\($0)" }
        let layout = GridLayout(entries: [
            .folder(folder("f1", "Big", apps: names)),
        ])

        let result = layout.reconciled(with: names.map { app($0) })

        XCTAssertEqual(result.entries.count, 2)
        guard case .folder(let kept) = result.entries[0] else {
            return XCTFail("First entry should still be the folder")
        }
        XCTAssertEqual(kept.appIDs.count, GridFolder.maxApps)
        XCTAssertEqual(result.entries[1], .app(appID("App9")))
    }

    func testReconcileRemovesHiddenAppsFromHiddenListIfUninstalled() {
        let layout = GridLayout(
            entries: [.app(appID("Mail"))],
            hidden: [
                HiddenApp(appID: appID("Gone"), position: 0),
                HiddenApp(appID: appID("Slack"), position: 1),
            ]
        )

        let result = layout.reconciled(with: [app("Mail"), app("Slack")])

        XCTAssertEqual(result.hidden, [HiddenApp(appID: appID("Slack"), position: 1)])
    }

    func testHiddenAppsStayOffTheGrid() {
        let layout = GridLayout(
            entries: [.app(appID("Mail")), .app(appID("Slack"))],
            hidden: [HiddenApp(appID: appID("Mail"), position: 0)]
        )

        let result = layout.reconciled(with: [app("Mail"), app("Slack")])

        XCTAssertEqual(result.entries, [.app(appID("Slack"))])
    }

    // MARK: - Moving

    func testMoveEntryClampsIndexToTheGrid() {
        var layout = GridLayout.makeDefault(for: [app("A"), app("B"), app("C")])

        layout.moveEntry(withID: GridEntry.app(appID("A")).id, to: 99)

        XCTAssertEqual(layout.entries, [.app(appID("B")), .app(appID("C")), .app(appID("A"))])
    }

    func testMoveEntryWithUnknownIDChangesNothing() {
        var layout = GridLayout.makeDefault(for: [app("A"), app("B")])
        let before = layout

        layout.moveEntry(withID: "app:/Applications/Nope.app", to: 0)

        XCTAssertEqual(layout, before)
    }

    // MARK: - Hiding and restoring

    func testHideThenRestoreReturnsTheAppToItsSpot() {
        var layout = GridLayout.makeDefault(for: [app("A"), app("B"), app("C")])

        layout.hideApp(appID("B"))
        XCTAssertEqual(layout.entries, [.app(appID("A")), .app(appID("C"))])
        XCTAssertEqual(layout.hidden, [HiddenApp(appID: appID("B"), position: 1)])

        layout.restoreApp(appID("B"))
        XCTAssertEqual(layout.entries, [.app(appID("A")), .app(appID("B")), .app(appID("C"))])
        XCTAssertTrue(layout.hidden.isEmpty)
    }

    func testRestoreClampsSavedPositionToTheGrid() {
        var layout = GridLayout(
            entries: [.app(appID("A"))],
            hidden: [HiddenApp(appID: appID("B"), position: 50)]
        )

        layout.restoreApp(appID("B"))

        XCTAssertEqual(layout.entries, [.app(appID("A")), .app(appID("B"))])
    }

    // MARK: - Entry identity

    func testAppAndFolderEntriesHaveDistinctIDs() {
        let plain = GridEntry.app("x")
        let folderEntry = GridEntry.folder(GridFolder(id: "x", name: "X", appIDs: []))

        XCTAssertNotEqual(plain.id, folderEntry.id)
    }
}
