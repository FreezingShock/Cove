//
//  GridZone.swift
//  Inlet
//
//  A zone is a named, resizable block in the band above the paged grid. It
//  holds the apps of the groups you pick, and those apps leave the paged
//  grid. Zones are a Supporter feature. This file is plain data and rules,
//  with no UI, so the placement logic can be checked by unit tests.
//

import Foundation

struct GridZone: Codable, Equatable, Identifiable, Sendable {
    /// The tallest a zone can be, in rows.
    static let maxHeight = 4
    /// The lowest a zone can start, in rows, from the top of the band.
    static let maxRow = 12

    var id: String
    var name: String
    /// Left-most column, counted from 0.
    var column: Int
    /// Top row in the zone band, counted from 0.
    var row: Int
    /// Width in grid columns.
    var width: Int
    /// Height in grid rows.
    var height: Int
    /// The IDs of the groups this zone holds (`AppGroup.id`). Presets use
    /// their category's raw value as the ID, so older zones still match.
    var groupIDs: [String]

    /// A new zone, two columns wide, placed at `row`.
    static func new(columns: Int, row: Int) -> GridZone {
        GridZone(
            id: UUID().uuidString,
            name: "New Zone",
            column: 0,
            row: min(max(row, 0), maxRow),
            width: min(2, max(columns, 1)),
            height: 1,
            groupIDs: []
        )
    }

    /// The same zone squeezed inside `columns` and the height limits. Used
    /// when the grid's column count changes under a saved zone.
    func fitted(columns: Int) -> GridZone {
        var copy = self
        copy.width = min(max(width, 1), max(columns, 1))
        copy.column = min(max(column, 0), max(columns - copy.width, 0))
        copy.height = min(max(height, 1), GridZone.maxHeight)
        copy.row = min(max(row, 0), GridZone.maxRow)
        return copy
    }

    /// True when the two zones share at least one cell.
    func overlaps(_ other: GridZone) -> Bool {
        column < other.column + other.width
            && other.column < column + width
            && row < other.row + other.height
            && other.row < row + height
    }
}

enum ZoneLayout {
    /// Whether `zone` sits inside the grid, within the size limits, and clear of `others`.
    static func fits(_ zone: GridZone, columns: Int, among others: [GridZone]) -> Bool {
        guard zone.width >= 1,
              zone.height >= 1, zone.height <= GridZone.maxHeight,
              zone.row >= 0, zone.row <= GridZone.maxRow,
              zone.column >= 0, zone.column + zone.width <= columns
        else { return false }
        return !others.contains { zone.overlaps($0) }
    }

    /// Rows the zone band needs, counting from the top of the band.
    static func bandRows(_ zones: [GridZone]) -> Int {
        zones.map { $0.row + $0.height }.max() ?? 0
    }

    /// The apps each zone shows, keyed by zone id. An app goes to the first
    /// zone, in order, that holds its group. Hidden apps never appear.
    static func contents(
        of zones: [GridZone],
        apps: [AppItem],
        hidden: Set<String>,
        groupOf: (AppItem) -> String
    ) -> [String: [AppItem]] {
        var result: [String: [AppItem]] = [:]
        var taken = Set<String>()
        for zone in zones {
            let groups = Set(zone.groupIDs)
            let members = apps.filter { app in
                !hidden.contains(app.id) && !taken.contains(app.id) && groups.contains(groupOf(app))
            }
            for app in members { taken.insert(app.id) }
            result[zone.id] = members
        }
        return result
    }
}
