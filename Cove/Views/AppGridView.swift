//
//  AppGridView.swift
//  Cove
//
//  The full grid, shown on the overlay: a header, the search panel, then
//  every installed app in a 7-column grid. Typing filters the grid. Arrow
//  keys move through it. It sits on the overlay's scrim, so it has no
//  background of its own.
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

    /// No movement and no delay. Used when a cell has no known position.
    static let none = OpenPlacement(offset: .zero, delay: 0)

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
    /// Crossfade instead of the scale-in when icons appear in a search.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Closes the overlay on Escape, and after an app opens.
    @Environment(\.dismissOverlay) private var dismissOverlay

    /// True once the overlay is open. Drives the open choreography.
    let isOpen: Bool

    /// What the user typed. Empty means "show every app".
    @State private var query = ""
    /// True while the search field has keyboard focus.
    @FocusState private var searchFocused: Bool
    /// The icon that has keyboard focus, if any. Arrow keys move it.
    @FocusState private var focusedApp: AppItem.ID?

    /// The bucket the grid is filtered to. Nil shows every app.
    /// Starts on the last bucket used when "Remember last category" is on.
    @State private var category: AppCategory? = CoveSettings.startingCategory
    /// Spotlight file matches for the query, shown under the search field.
    @State private var fileSearch = FileSearch()

    /// Column count from Settings > Grid (5 to 9, default 7).
    @AppStorage(CoveSettings.Key.gridColumns.rawValue) private var gridColumns = 7
    /// Settings > General and Search. Read here so each change applies at once.
    @AppStorage(CoveSettings.Key.rememberLastCategory.rawValue) private var rememberLastCategory = true
    @AppStorage(CoveSettings.Key.escapeClearsSearchFirst.rawValue) private var escapeClearsSearchFirst = true
    @AppStorage(CoveSettings.Key.closeAfterLaunch.rawValue) private var closeAfterLaunch = true
    @AppStorage(CoveSettings.Key.searchIncludesFiles.rawValue) private var searchIncludesFiles = true
    @AppStorage(CoveSettings.Key.searchFileResultCount.rawValue) private var fileResultCount = 5

    /// Fixed-width columns. Cell width is unchanged, so the count sets the grid width.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(CoveSize.gridCell.width), spacing: 0),
            count: gridColumns
        )
    }

    /// Smallest width that fits the current column count plus side padding.
    private var minimumGridWidth: CGFloat {
        CoveSize.gridCell.width * CGFloat(gridColumns) + CoveSize.gridSidePadding * 2
    }

    /// True when the query has something other than spaces in it.
    private var isSearching: Bool { !AppSearch.normalize(query).isEmpty }
    /// The apps to show. Searching looks through every app, since the category
    /// bar is hidden then. Otherwise the grid shows the selected bucket.
    /// Matches come back best-first.
    private var shownApps: [AppItem] {
        let pool = isSearching ? library.apps : AppCategory.filter(library.apps, by: category)
        return AppSearch.results(for: query, in: pool)
    }
    /// The best match. Return opens it. Only exists while searching.
    private var topHit: AppItem? { isSearching ? shownApps.first : nil }

    /// Open-animation placement for each shown app. Positions follow the
    /// shown order, so a search reflows the ripple around the new center.
    private var openPlacements: [AppItem.ID: OpenPlacement] {
        let total = shownApps.count
        var result: [AppItem.ID: OpenPlacement] = [:]
        for (index, app) in shownApps.enumerated() {
            result[app.id] = OpenPlacement.forCell(at: index, total: total)
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header

                SearchPanel(
                    query: $query,
                    isFocused: $searchFocused,
                    topHit: topHit,
                    matchCount: shownApps.count,
                    files: fileSearch.results,
                    onOpenTopHit: openTopHit,
                    onOpenFile: openFile,
                    onRevealFile: revealFile,
                    onDown: enterGrid
                )
                .padding(.bottom, CoveSpace.xl)

                // Fades out while typing, so the search results take its place.
                // It keeps its space, so the grid below does not jump.
                CategoryBar(selection: $category, isFaded: isSearching)
                    .padding(.bottom, CoveSpace.l)

                content
            }
            // Keep the keyboard-focused icon on screen as arrows move it.
            .onChange(of: focusedApp) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
        }
        .frame(minWidth: minimumGridWidth, maxWidth: .infinity, maxHeight: .infinity)
        // The field has focus when the overlay opens, so you can type at once.
        .defaultFocus($searchFocused, true)
        // Typing again returns keyboard focus to the field from the grid.
        .onChange(of: query) { _, newQuery in
            focusedApp = nil
            // Zero when the setting is off, which clears the file rows.
            fileSearch.update(
                query: newQuery,
                resultCount: searchIncludesFiles ? fileResultCount : 0
            )
        }
        .onChange(of: category) { _, newCategory in
            if rememberLastCategory {
                CoveSettings.saveLastCategory(newCategory)
            }
        }
        // Keys are handled here on the root so they work from the field and
        // from any icon. Each handler returns .ignored when it doesn't apply,
        // so the field keeps its normal typing and cursor keys.
        .onKeyPress(.escape) { handleEscape() }
        .onKeyPress(.return) { openFocusedApp() }
        .onKeyPress(.leftArrow) { moveFocus(by: -1) }
        .onKeyPress(.rightArrow) { moveFocus(by: 1) }
        .onKeyPress(.upArrow) { moveFocus(by: -gridColumns) }
        .onKeyPress(.downArrow) { moveFocus(by: gridColumns) }
        // No scan here: the app scans once at launch (spec: never scan on open).
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Cove")
                .font(CoveFont.wordmark)
                .tracking(CoveTracking.display)
                .foregroundStyle(CoveColor.text)

            Spacer()

            if library.hasScanned {
                Text(isSearching
                     ? "\(shownApps.count) of \(library.apps.count)"
                     : "\(shownApps.count) apps")
                    .font(CoveFont.section)
                    .foregroundStyle(CoveText.secondary(contrast))
            }
        }
        .padding(.horizontal, CoveSize.gridSidePadding)
        .padding(.top, CoveSpace.xxl)
        .padding(.bottom, CoveSpace.xl)
    }

    // MARK: Grid

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
        } else if isSearching && shownApps.isEmpty {
            Text("Nothing matches that search.")
                .font(CoveFont.subhead)
                .foregroundStyle(CoveText.secondary(contrast))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let placements = openPlacements
            ScrollView {
                // `LazyVGrid` only builds the cells that are on screen,
                // so icons load as you scroll instead of all at once.
                LazyVGrid(columns: columns, spacing: CoveSize.gridRowGap) {
                    ForEach(shownApps) { app in
                        AppIconCell(
                            app: app,
                            onLaunch: launch,
                            isTopHit: app.id == topHit?.id,
                            isKeyboardFocused: focusedApp == app.id,
                            placement: placements[app.id] ?? .none,
                            isOpen: isOpen
                        )
                        .focused($focusedApp, equals: app.id)
                        .id(app.id)
                        // New matches scale in from 0.6 (crossfade under Reduce Motion).
                        .transition(reduceMotion
                                    ? .opacity
                                    : .scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, CoveSize.gridSidePadding)
                .padding(.bottom, CoveSpace.xxxl)
                // Reflow when the matches change: the `settle` spring.
                .coveAnimation(.coveSettle, value: shownApps.map(\.id))
            }
        }
    }

    // MARK: Actions

    /// Clears the search and closes the overlay, when "Close after launch" is on.
    /// The overlay hides first, then the app or file opens (spec: Launch).
    private func closeAfterAction() {
        guard closeAfterLaunch else { return }
        query = ""
        focusedApp = nil
        dismissOverlay()
    }

    /// Launches an app. The overlay closes first if the setting is on, so the
    /// next open starts fresh.
    private func launch(_ app: AppItem) {
        closeAfterAction()
        AppLauncher.launch(app)
    }

    /// A tap on a file row: open the file with its default app.
    private func openFile(_ file: FileItem) {
        closeAfterAction()
        file.open()
    }

    /// Cmd+Return in the field: select the file in a Finder window.
    private func revealFile(_ file: FileItem) {
        closeAfterAction()
        file.revealInFinder()
    }

    /// Return in the field, or a tap on the top-hit row: open the top hit.
    private func openTopHit() {
        guard let app = topHit else { return }
        launch(app)
    }

    /// Return while an icon has keyboard focus: open that icon.
    private func openFocusedApp() -> KeyPress.Result {
        guard let id = focusedApp,
              let app = shownApps.first(where: { $0.id == id }) else { return .ignored }
        launch(app)
        return .handled
    }

    /// Down arrow in the field: focus the first icon in the grid.
    private func enterGrid() -> KeyPress.Result {
        guard let first = shownApps.first else { return .ignored }
        focusedApp = first.id
        searchFocused = false
        return .handled
    }

    /// Arrow keys while an icon has focus. Moves by `offset` positions in the
    /// shown list, so Left and Right stop at the row edges and Up from the top
    /// row hands focus back to the field.
    private func moveFocus(by offset: Int) -> KeyPress.Result {
        guard let current = focusedApp else { return .ignored }
        let apps = shownApps
        guard let index = apps.firstIndex(where: { $0.id == current }) else { return .ignored }

        let columns = gridColumns
        let target = index + offset

        if target < 0 {
            // Up from the top row goes back to the field. Left at the very
            // first icon just stays put.
            if offset < -1 {
                focusedApp = nil
                searchFocused = true
            }
            return .handled
        }
        guard target < apps.count else { return .handled }

        // Left and Right must stay on the same row.
        if abs(offset) == 1 && target / columns != index / columns {
            return .handled
        }
        focusedApp = apps[target].id
        return .handled
    }

    /// Escape clears the field first. With nothing to clear, it closes the overlay.
    private func handleEscape() -> KeyPress.Result {
        if isSearching && escapeClearsSearchFirst {
            query = ""
            focusedApp = nil
            searchFocused = true
        } else {
            dismissOverlay()
        }
        return .handled
    }
}
