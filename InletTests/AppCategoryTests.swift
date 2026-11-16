//
//  AppCategoryTests.swift
//  InletTests
//
//  Checks the LSApplicationCategoryType to bucket mapping and the filter
//  the category bar uses. Pure logic, so no UI or disk access.
//

import XCTest
@testable import Inlet

final class AppCategoryTests: XCTestCase {

    // MARK: - Mapping

    func testEveryDocumentedValueLandsInTheSpecBucket() {
        let expected: [String: AppCategory] = [
            // Create
            "public.app-category.graphics-design": .create,
            "public.app-category.photography": .create,
            "public.app-category.video": .create,
            "public.app-category.music": .create,
            // Build
            "public.app-category.developer-tools": .build,
            // School
            "public.app-category.education": .school,
            "public.app-category.reference": .school,
            "public.app-category.educational-games": .games,
            // Everyday
            "public.app-category.business": .everyday,
            "public.app-category.entertainment": .everyday,
            "public.app-category.finance": .everyday,
            "public.app-category.games": .games,
            "public.app-category.healthcare-fitness": .everyday,
            "public.app-category.lifestyle": .everyday,
            "public.app-category.medical": .everyday,
            "public.app-category.news": .everyday,
            "public.app-category.productivity": .everyday,
            "public.app-category.social-networking": .everyday,
            "public.app-category.sports": .everyday,
            "public.app-category.travel": .everyday,
            "public.app-category.utilities": .everyday,
            "public.app-category.weather": .everyday,
            "public.app-category.action-games": .games,
            "public.app-category.adventure-games": .games,
            "public.app-category.arcade-games": .games,
            "public.app-category.board-games": .games,
            "public.app-category.card-games": .games,
            "public.app-category.casino-games": .games,
            "public.app-category.dice-games": .games,
            "public.app-category.family-games": .games,
            "public.app-category.kids-games": .games,
            "public.app-category.music-games": .games,
            "public.app-category.puzzle-games": .games,
            "public.app-category.racing-games": .games,
            "public.app-category.role-playing-games": .games,
            "public.app-category.simulation-games": .games,
            "public.app-category.sports-games": .games,
            "public.app-category.strategy-games": .games,
            "public.app-category.trivia-games": .games,
            "public.app-category.word-games": .games,
        ]

        for (value, bucket) in expected {
            XCTAssertEqual(AppCategory.bucket(forCategoryType: value), bucket, value)
        }
    }

    func testMissingOrEmptyCategoryGoesToOther() {
        XCTAssertEqual(AppCategory.bucket(forCategoryType: nil), .other)
        XCTAssertEqual(AppCategory.bucket(forCategoryType: ""), .other)
        XCTAssertEqual(AppCategory.bucket(forCategoryType: "   "), .other)
        XCTAssertEqual(AppCategory.bucket(forCategoryType: "public.app-category."), .other)
    }

    func testUnknownCategoryGoesToOther() {
        XCTAssertEqual(AppCategory.bucket(forCategoryType: "public.app-category.nonsense"), .other)
        XCTAssertEqual(AppCategory.bucket(forCategoryType: "not-a-uti"), .other)
        XCTAssertEqual(AppCategory.bucket(forCategoryType: "public.app-category.zebra-games"), .other)
    }

    func testPrefixAndCaseAreOptional() {
        XCTAssertEqual(AppCategory.bucket(forCategoryType: "developer-tools"), .build)
        XCTAssertEqual(AppCategory.bucket(forCategoryType: "Public.App-Category.Developer-Tools"), .build)
        XCTAssertEqual(AppCategory.bucket(forCategoryType: "  graphics-design  "), .create)
    }

    // MARK: - Bucket set

    func testSixBucketsInBarOrder() {
        XCTAssertEqual(AppCategory.allCases, [.create, .build, .school, .everyday, .games, .other])
        XCTAssertEqual(AppCategory.allCases.map(\.title), ["Create", "Build", "School", "Everyday", "Games", "Other"])
    }

    // MARK: - Filtering

    func testNilFilterReturnsEveryAppInOrder() {
        let apps = sampleApps()
        XCTAssertEqual(AppCategory.filter(apps, by: nil).map(\.name), apps.map(\.name))
    }

    func testFilterKeepsOnlyTheChosenBucket() {
        let apps = sampleApps()
        let builds = AppCategory.filter(apps, by: .build)
        XCTAssertEqual(builds.map(\.name), ["Xcode"])
    }

    func testGamesBucketCollectsEveryGame() {
        let apps = sampleApps()
        XCTAssertEqual(AppCategory.filter(apps, by: .games).map(\.name), ["Chess"])
    }

    func testEveryAppLandsInExactlyOneBucket() {
        let apps = sampleApps()
        let counts = AppCategory.allCases.map { AppCategory.filter(apps, by: $0).count }
        XCTAssertEqual(counts.reduce(0, +), apps.count)

        for app in apps {
            let owners = AppCategory.allCases.filter { category in
                AppCategory.filter([app], by: category).isEmpty == false
            }
            XCTAssertEqual(owners.count, 1, "\(app.name) is in \(owners.count) buckets")
        }
    }

    func testAppItemCategoryReadsItsCategoryType() {
        let app = makeApp(name: "Xcode", categoryType: "public.app-category.developer-tools")
        XCTAssertEqual(app.category, .build)
        XCTAssertEqual(makeApp(name: "Mystery", categoryType: nil).category, .other)
    }

    // MARK: - Helpers

    private func sampleApps() -> [AppItem] {
        [
            makeApp(name: "Affinity Photo", categoryType: "public.app-category.photography"),
            makeApp(name: "Xcode", categoryType: "public.app-category.developer-tools"),
            makeApp(name: "Notes", categoryType: "public.app-category.productivity"),
            makeApp(name: "Chess", categoryType: "public.app-category.strategy-games"),
            makeApp(name: "Khan Academy", categoryType: "public.app-category.education"),
            makeApp(name: "Mystery Tool", categoryType: nil),
            makeApp(name: "Odd Thing", categoryType: "public.app-category.nonsense"),
        ]
    }

    private func makeApp(name: String, categoryType: String?) -> AppItem {
        AppItem(
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: "test.\(name.replacingOccurrences(of: " ", with: "-"))",
            categoryType: categoryType
        )
    }
}
