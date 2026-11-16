//
//  GridGeometry.swift
//  Inlet
//
//  Where each icon sits on the paged grid. This is plain math with no views,
//  so the page and hit-test rules can be checked by reading the code.
//

import CoreGraphics
import Foundation

/// Sizes the paged grid needs, on top of `InletSize`.
enum GridMetrics {
    /// One grid cell: the icon, then its name. Same as the search grid.
    static let cellHeight: CGFloat = InletSize.gridCell.height
    /// Room under the icons for the page dots.
    static let dotsHeight: CGFloat = 56
    /// How close to a window edge a drag has to get before the page flips.
    static let edgeZone: CGFloat = 48
}

/// Slot positions for a grid that holds `columns` x `rows` icons per page.
///
/// Pages sit side by side: page `n` starts at `n * pageWidth`. Everything is
/// measured in "grid space", where the first page starts at x = 0.
struct GridGeometry {
    let columns: Int
    let rows: Int
    let cellSize: CGSize
    let rowSpacing: CGFloat
    /// Top-left of the first slot on a page.
    let origin: CGPoint
    /// Width of one page, which is the width of the visible area.
    let pageWidth: CGFloat

    /// How many icons fit on one page.
    var perPage: Int { columns * rows }

    /// Fits as many whole rows as the page height allows (at least one), and
    /// centers the block of icons left to right and top to bottom.
    static func make(
        pageSize: CGSize,
        columns: Int,
        cellSize: CGSize,
        rowSpacing: CGFloat
    ) -> GridGeometry {
        let rowHeight = cellSize.height + rowSpacing
        let rows = max(1, Int((pageSize.height + rowSpacing) / rowHeight))
        let blockWidth = CGFloat(columns) * cellSize.width
        let blockHeight = CGFloat(rows) * cellSize.height + CGFloat(rows - 1) * rowSpacing
        let origin = CGPoint(
            x: max(0, (pageSize.width - blockWidth) / 2),
            y: max(0, (pageSize.height - blockHeight) / 2)
        )
        return GridGeometry(
            columns: columns,
            rows: rows,
            cellSize: cellSize,
            rowSpacing: rowSpacing,
            origin: origin,
            pageWidth: pageSize.width
        )
    }

    /// Number of pages needed for `itemCount` icons. Always at least one.
    func pageCount(itemCount: Int) -> Int {
        max(1, (itemCount + perPage - 1) / perPage)
    }

    /// Center of the slot for item `index` (0-based, across all pages).
    func center(ofIndex index: Int) -> CGPoint {
        let page = index / perPage
        let local = index % perPage
        let column = local % columns
        let row = local / columns
        return CGPoint(
            x: CGFloat(page) * pageWidth + origin.x + CGFloat(column) * cellSize.width + cellSize.width / 2,
            y: origin.y + CGFloat(row) * (cellSize.height + rowSpacing) + cellSize.height / 2
        )
    }

    /// The item index under `point` (grid space), or nil when the point is
    /// in a gap between cells or outside the grid. The caller still checks
    /// that the index is less than the number of items.
    func index(at point: CGPoint) -> Int? {
        guard pageWidth > 0 else { return nil }
        let page = max(0, Int(floor(point.x / pageWidth)))
        let x = point.x - CGFloat(page) * pageWidth - origin.x
        let y = point.y - origin.y
        guard x >= 0, y >= 0 else { return nil }

        let rowHeight = cellSize.height + rowSpacing
        let column = Int(x / cellSize.width)
        let row = Int(y / rowHeight)
        guard column < columns, row < rows else { return nil }
        // A point in the gap under a row is not on a cell.
        guard y - CGFloat(row) * rowHeight <= cellSize.height else { return nil }

        return page * perPage + row * columns + column
    }
}
