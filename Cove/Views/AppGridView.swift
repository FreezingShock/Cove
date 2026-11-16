//
//  AppGridView.swift
//  Cove
//
//  The full grid: a header, then every installed app in a 7-column grid.
//  It sits on the overlay's scrim, so it has no background of its own.
//

import AppKit
import SwiftUI

/// Where one grid cell starts and when it begins its open animation.
/// The grid ripples outward from the middle: cells farther from the
/// center wait longer, up to a cap.
struct OpenPlacement {
    /// Starting offset: 22% of the way from the cell toward the grid center.
    let offset: CGSize
    /// Seconds before this cell's open spring starts.
    let delay: Double

    /// Spec: 0.6 ms of delay per point of distance, capped at 520 ms.
    private static let delayPerPoint = 0.0006
    private static let maxDelay = 0.52
    /// Spec: each icon starts 22% of the way toward the center.
    private static let startFraction: CGFloat = 0.22

    /// Placement for the cell at `index` in a grid of `total` cells.
    static func forCell(at index: Int, total: Int) -> OpenPlacement {
        let columns = CoveSize.gridColumns
        let rows = Int((Double(total) / Double(columns)).rounded(.up))

        // Center of the grid, in cell units (column and row indexes).
        let centerColumn = Double(columns - 1) / 2
        let centerRow = Double(max(rows - 1, 0)) / 2

        // This cell's position from the center, in points.
        let column = Double(index % columns)
        let row = Double(index / columns)
        let dx = (column - centerColumn) * Double(CoveSize.gridCell.width)
        let dy = (row - centerRow) * Double(CoveSize.gridCell.height + CoveSize.gridRowGap)

        let distance = (dx * dx + dy * dy).squareRoot()
        let delay = min(distance * delayPerPoint, maxDelay)
        let offset = CGSize(
            width: -CGFloat(dx) * startFraction,
            height: -CGFloat(dy) * startFraction
        )
        return OpenPlacement(offset: offset, delay: delay)
    }
}

struct AppGridView: View {
    /// The shared app list, provided by the overlay via `.environment(...)`.
    @Environment(AppLibrary.self) private var library
    /// Read from the system so Increase Contrast applies to secondary text.
    @Environment(\.colorSchemeContrast) private var contrast

    /// True once the overlay is open. Drives the open choreography.
    let isOpen: Bool

    /// Seven fixed-width columns, per the spec.
    private let columns = Array(
        repeating: GridItem(.fixed(CoveSize.gridCell.width), spacing: 0),
        count: CoveSize.gridColumns
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Cove")
                .font(CoveFont.wordmark)
                .tracking(CoveTracking.display)
                .foregroundStyle(CoveColor.text)

            Spacer()

            if library.hasScanned {
                Text("\(library.apps.count) apps")
                    .font(CoveFont.section)
                    .foregroundStyle(CoveText.secondary(contrast))
            }
        }
        .padding(.horizontal, CoveSize.gridSidePadding)
        .padding(.top, CoveSpace.xxl)
        .padding(.bottom, CoveSpace.xl)
    }

    @ViewBuilder
    private var content: some View {
        if !library.hasScanned {
            // Before the first scan finishes.
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if library.apps.isEmpty {
            Text("No apps found.")
                .font(CoveFont.subhead)
                .foregroundStyle(CoveText.secondary(contrast))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                // `LazyVGrid` only builds the cells that are on screen,
                // so icons load as you scroll instead of all at once.
                LazyVGrid(columns: columns, spacing: CoveSize.gridRowGap) {
                    ForEach(library.apps.indices, id: \.self) { index in
                        AppIconCell(
                            app: library.apps[index],
                            placement: OpenPlacement.forCell(at: index, total: library.apps.count),
                            isOpen: isOpen
                        )
                    }
                }
                .padding(.horizontal, CoveSize.gridSidePadding)
                .padding(.bottom, CoveSpace.xxxl)
            }
        }
    }
}
