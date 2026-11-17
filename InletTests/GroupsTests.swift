//
//  GroupsTests.swift
//  InletTests
//
//  Checks the group rules: the presets on a fresh install, auto-sorting new
//  apps, moving and deleting groups, and reading a version 1 layout file.
//  All of it is plain data, so no window or disk access is needed.
//

import XCTest
@testable import Inlet

final class GroupsTests: XCTestCase {

    // MARK: - Helpers

    private func app(_ name: String, category: String? = nil) -> AppItem {
        AppItem(
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: "com.example.\(name)",
            categoryType: category
        )
    }

    private func appID(_ name: String) -> String {
        "/Applications/\(name).app"
    }

    private func group(_ layout: GridLayout, _ id: String) -> AppGroup? {
        layout.groups.first { $0.id == id }
    }

    private var sampleApps: [AppItem] {
        [
            app("Affinity Photo", category: "public.app-category.photography"),
            app("Xcode", category: "public.app-category.developer-tools"),
            app("Notes", category: "public.app-category.productivity"),
            app("Chess", category: "public.app-category.strategy-games"),
            app("Khan Academy", category: "public.app-category.education"),
            app("Mystery Tool"),
        ]
    }

    // MARK: - Presets

    func testFreshInstallStartsWithSixPresetGroupsInBarOrder() {
        let layout = GridLayout.makeDefault(for: sampleApps)
        XCTAssertEqual(layout.groups.map(\.name), ["Create", "Build", "School", "Everyday", "Games", "Other"])
        XCTAssertEqual(layout.groups.map(\.id), ["create", "build", "school", "everyday", "games", "other"])
    }

    func testNewAppsAutoSortIntoTheirPresetGroup() {
        let layout = GridLayout.makeDefault(for: sampleApps)
        XCTAssertEqual(group(layout, "create")?.appIDs, [appID("Affinity Photo")])
        XCTAssertEqual(group(layout, "build")?.appIDs, [appID("Xcode")])
        XCTAssertEqual(group(layout, "everyday")?.appIDs, [appID("Notes")])
        XCTAssertEqual(group(layout, "games")?.appIDs, [appID("Chess")])
        XCTAssertEqual(group(layout, "school")?.appIDs, [appID("Khan Academy")])
        XCTAssertEqual(group(layout, "other")?.appIDs, [appID("Mystery Tool")])
    }

    func testEveryAppIsInExactlyOneGroup() {
        let layout = GridLayout.makeDefault(for: sampleApps)
        let members = layout.groups.flatMap(\.appIDs)
        XCTAssertEqual(members.count, sampleApps.count)
        XCTAssertEqual(Set(members), Set(sampleApps.map(\.id)))
    }

    // MARK: - Reconciling with installed apps

    func testUninstalledAppLeavesItsGroup() {
        let layout = GridLayout.makeDefault(for: sampleApps)
        let result = layout.reconciled(with: sampleApps.filter { $0.name != "Xcode" })
        XCTAssertEqual(group(result, "build")?.appIDs, [])
        XCTAssertNil(result.groupID(containing: appID("Xcode")))
    }

    func testNewAppJoinsItsSuggestedGroupAfterTheExistingMembers() {
        let layout = GridLayout.makeDefault(for: sampleApps)
        let installed = sampleApps + [
            app("Figma", category: "public.app-category.graphics-design"),
            app("Terminal", category: "public.app-category.developer-tools"),
        ]
        let result = layout.reconciled(with: installed)
        XCTAssertEqual(group(result, "create")?.appIDs, [appID("Affinity Photo"), appID("Figma")])
        XCTAssertEqual(group(result, "build")?.appIDs, [appID("Xcode"), appID("Terminal")])
    }

    func testReconcileIsIdempotent() {
        let once = GridLayout.makeDefault(for: sampleApps).reconciled(with: sampleApps)
        XCTAssertEqual(once.reconciled(with: sampleApps), once)
    }

    func testHiddenAppKeepsItsGroup() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.hideApp(appID("Notes"))
        let result = layout.reconciled(with: sampleApps)
        XCTAssertEqual(group(result, "everyday")?.appIDs, [appID("Notes")])
        XCTAssertEqual(result.hidden.map(\.appID), [appID("Notes")])
    }

    func testSuggestedGroupFallsBackToOtherWhenItsPresetIsGone() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.deleteGroup(withID: "create")
        let result = layout.reconciled(with: sampleApps)
        XCTAssertTrue(group(result, "other")?.appIDs.contains(appID("Affinity Photo")) == true)
        XCTAssertNil(group(result, "create"))
    }

    // MARK: - Adding and editing

    func testAddGroupAppendsACustomGroupWithTrimmedName() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        let id = layout.addGroup(name: "  Work  ", color: .teal, symbol: "briefcase")
        XCTAssertEqual(layout.groups.count, 7)
        XCTAssertEqual(layout.groups.last?.id, id)
        XCTAssertEqual(layout.groups.last?.name, "Work")
        XCTAssertNil(layout.groups.last?.suggestedCategory)
    }

    func testAddGroupRejectsAnEmptyName() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        XCTAssertNil(layout.addGroup(name: "   ", color: .teal, symbol: "star"))
        XCTAssertEqual(layout.groups.count, 6)
    }

    func testGroupNameIsCappedAtTheLimit() {
        let long = String(repeating: "x", count: AppGroup.maxNameLength + 10)
        XCTAssertEqual(AppGroup.cleanName(long)?.count, AppGroup.maxNameLength)
    }

    func testEditGroupChangesOnlyTheFieldsGiven() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.editGroup(withID: "build", color: .red)
        let build = group(layout, "build")
        XCTAssertEqual(build?.color, .red)
        XCTAssertEqual(build?.name, "Build")
        XCTAssertEqual(build?.symbol, "hammer")
    }

    func testEditGroupIgnoresAnEmptyName() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.editGroup(withID: "build", name: "  ")
        XCTAssertEqual(group(layout, "build")?.name, "Build")
    }

    func testMoveGroupClampsToTheBar() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.moveGroup(withID: "create", to: 99)
        XCTAssertEqual(layout.groups.last?.id, "create")
        layout.moveGroup(withID: "create", to: -4)
        XCTAssertEqual(layout.groups.first?.id, "create")
    }

    // MARK: - Moving apps and deleting groups

    func testMoveAppTakesItOutOfItsOldGroup() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.moveApp(appID("Xcode"), toGroup: "games")
        XCTAssertEqual(group(layout, "build")?.appIDs, [])
        XCTAssertEqual(group(layout, "games")?.appIDs, [appID("Chess"), appID("Xcode")])
        XCTAssertEqual(layout.groups.flatMap(\.appIDs).filter { $0 == appID("Xcode") }.count, 1)
    }

    func testMoveAppToAnUnknownGroupChangesNothing() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        let before = layout
        layout.moveApp(appID("Xcode"), toGroup: "nope")
        XCTAssertEqual(layout, before)
    }

    func testDeletingAGroupMovesItsAppsToOther() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.deleteGroup(withID: "games")
        XCTAssertNil(group(layout, "games"))
        XCTAssertEqual(group(layout, "other")?.appIDs, [appID("Mystery Tool"), appID("Chess")])
    }

    func testDeletingOtherMovesItsAppsToTheFirstGroupLeft() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.deleteGroup(withID: "other")
        XCTAssertEqual(group(layout, "create")?.appIDs, [appID("Affinity Photo"), appID("Mystery Tool")])
    }

    func testTheLastGroupCannotBeDeleted() {
        var layout = GridLayout(groups: [
            AppGroup(id: "solo", name: "Solo", color: .blue, symbol: "star", suggestedCategory: nil, appIDs: []),
        ])
        layout.deleteGroup(withID: "solo")
        XCTAssertEqual(layout.groups.map(\.id), ["solo"])
    }

    // MARK: - Group icons

    func testIconChoicesAreUniqueAndFillWholeRows() {
        let choices = AppGroup.symbolChoices
        XCTAssertEqual(Set(choices).count, choices.count)
        XCTAssertEqual(choices.count % 6, 0)
    }

    func testEveryPresetIconIsOfferedInThePicker() {
        for preset in AppGroup.presets {
            XCTAssertTrue(AppGroup.symbolChoices.contains(preset.symbol), preset.symbol)
        }
    }

    func testEveryIconChoiceHasAReadableName() {
        for symbol in AppGroup.symbolChoices {
            XCTAssertNotEqual(AppGroup.name(forSymbol: symbol), symbol, symbol)
        }
    }

    // MARK: - Setup choices

    private var allPresets: Set<AppCategory> { Set(AppCategory.allCases) }

    func testTurningOffAPresetMovesItsAppsToOther() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.setPresetGroups(allPresets.subtracting([.games]), apps: sampleApps)
        XCTAssertNil(group(layout, "games"))
        XCTAssertEqual(group(layout, "other")?.appIDs, [appID("Mystery Tool"), appID("Chess")])
    }

    func testTurningAPresetBackOnPullsItsAppsOutOfOther() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.setPresetGroups(allPresets.subtracting([.games]), apps: sampleApps)
        layout.setPresetGroups(allPresets, apps: sampleApps)
        XCTAssertEqual(layout.groups.map(\.id), ["create", "build", "school", "everyday", "other", "games"])
        XCTAssertEqual(group(layout, "games")?.appIDs, [appID("Chess")])
        XCTAssertEqual(group(layout, "other")?.appIDs, [appID("Mystery Tool")])
    }

    func testEveryAppStaysInExactlyOneGroupWhenPresetsChange() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.setPresetGroups([.create, .games], apps: sampleApps)
        let grouped = layout.groups.flatMap(\.appIDs)
        XCTAssertEqual(grouped.count, sampleApps.count)
        XCTAssertEqual(Set(grouped), Set(sampleApps.map { appID($0.name) }))
    }

    func testAtLeastOneGroupStaysWhenEveryPresetIsOff() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        let before = layout
        layout.setPresetGroups([], apps: sampleApps)
        XCTAssertEqual(layout, before)
    }

    func testCustomGroupsSurviveAPresetChange() {
        var layout = GridLayout.makeDefault(for: sampleApps)
        layout.groups.append(AppGroup(id: "custom-work", name: "Work", color: .blue, symbol: "star", suggestedCategory: nil, appIDs: []))
        layout.setPresetGroups([], apps: sampleApps)
        XCTAssertEqual(layout.groups.map(\.id), ["custom-work"])
        XCTAssertEqual(Set(layout.groups.flatMap(\.appIDs)), Set(sampleApps.map { appID($0.name) }))
    }

    // MARK: - Saved files

    func testVersion1FileWithoutGroupsDecodesAndGainsPresets() throws {
        let v2 = GridLayout(version: 1, entries: [.app(appID("Notes"))])
        let encoded = try JSONEncoder().encode(v2)
        var object = (try JSONSerialization.jsonObject(with: encoded) as? [String: Any]) ?? [:]
        object.removeValue(forKey: "groups")
        let v1Data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(GridLayout.self, from: v1Data)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertTrue(decoded.groups.isEmpty)
        XCTAssertEqual(decoded.entries, [.app(appID("Notes"))])

        let migrated = decoded.reconciled(with: sampleApps)
        XCTAssertEqual(migrated.version, GridLayout.currentVersion)
        XCTAssertEqual(migrated.groups.count, 6)
        XCTAssertEqual(group(migrated, "everyday")?.appIDs, [appID("Notes")])
        XCTAssertEqual(migrated.entries.count, sampleApps.count)
    }

    func testGroupsSurviveAJSONRoundTrip() throws {
        var layout = GridLayout.makeDefault(for: sampleApps)
        guard let workID = layout.addGroup(name: "Work", color: .teal, symbol: "briefcase") else {
            return XCTFail("Could not add a group")
        }
        layout.moveApp(appID("Notes"), toGroup: workID)

        let data = try JSONEncoder().encode(layout)
        let back = try JSONDecoder().decode(GridLayout.self, from: data)
        XCTAssertEqual(back, layout)
    }
}
