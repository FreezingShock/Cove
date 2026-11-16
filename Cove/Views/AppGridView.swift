//
//  AppGridView.swift
//  Cove
//
//  The main window: a header, the search panel, then every installed app
//  in a 7-column grid. Typing filters the grid. Arrow keys move through it.
//

import AppKit
import SwiftUI

struct AppGridView: View {
    /// The shared app list, provided by CoveApp via `.environment(...)`.
    @Environment(AppLibrary.self) private var library
    /// Read from the system so Increase Contrast applies to secondary text.
    @Environment(\.colorSchemeContrast) private var contrast
    /// Crossfade instead of the scale-in when icons appear in a search.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Closes the main window on Escape.
    @Environment(\.dismissWindow) private var dismissWindow

    /// What the user typed. Empty means "show every app".
    @State private var query = ""
    /// True while the search field has keyboard focus.
    @FocusState private var searchFocused: Bool
    /// The icon that has keyboard focus, if any. Arrow keys move it.
    @FocusState private var focusedApp: AppItem.ID?

    /// Column count from Settings > Grid (5 to 9, default 7).
    @AppStorage(CoveSettings.Key.gridColumns.rawValue) private var gridColumns = 7

    /// Fixed-width columns. Cell width is unchanged, so the count sets the grid width.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(CoveSize.gridCell.width), spacing: 0),
            count: gridColumns
        )
    }

    /// Smallest window that fits the current column count plus side padding.
    private var minimumGridWidth: CGFloat {
        CoveSize.gridCell.width * CGFloat(gridColumns) + CoveSize.gridSidePadding * 2
    }

    /// True when the query has something other than spaces in it.
    private var isSearching: Bool { !AppSearch.normalize(query).isEmpty }
    /// The apps to show: all of them, or the matches best-first.
    private var shownApps: [AppItem] { AppSearch.results(for: query, in: library.apps) }
    /// The best match. Return opens it. Only exists while searching.
    private var topHit: AppItem? { isSearching ? shownApps.first : nil }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header

                SearchPanel(
                    query: $query,
                    isFocused: $searchFocused,
                    topHit: topHit,
                    matchCount: shownApps.count,
                    onOpenTopHit: openTopHit,
                    onDown: enterGrid
                )
                .padding(.bottom, CoveSpace.xl)
                // HOOK (T3.3, categories): CategoryBar goes here, with
                // isFaded: isSearching, so it fades out while typing.

                content
            }
            // Keep the keyboard-focused icon on screen as arrows move it.
            .onChange(of: focusedApp) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
        }
        .frame(minWidth: minimumGridWidth, minHeight: 480)
        .background(CoveColor.base)
        // The field has focus when the window opens, so you can type at once.
        .defaultFocus($searchFocused, true)
        // Typing again returns keyboard focus to the field from the grid.
        .onChange(of: query) { _, _ in
            focusedApp = nil
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
        // First scan when the window appears.
        .task { library.reload() }
        // Rescan whenever you switch back to Cove, so apps installed or
        // deleted in the meantime show up without restarting.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            library.reload()
        }
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
                     : "\(library.apps.count) apps")
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
            ScrollView {
                // `LazyVGrid` only builds the cells that are on screen,
                // so icons load as you scroll instead of all at once.
                LazyVGrid(columns: columns, spacing: CoveSize.gridRowGap) {
                    ForEach(shownApps) { app in
                        AppIconCell(
                            app: app,
                            onLaunch: launch,
                            isTopHit: app.id == topHit?.id,
                            isKeyboardFocused: focusedApp == app.id
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

    /// Launches an app and closes Cove, so the next open starts fresh.
    /// The window hides first, then the app opens (spec: Launch).
    private func launch(_ app: AppItem) {
        query = ""
        focusedApp = nil
        dismissWindow(id: "main")
        AppLauncher.launch(app)
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

    /// Escape clears the field first. With nothing to clear, it closes the window.
    private func handleEscape() -> KeyPress.Result {
        if isSearching {
            query = ""
            focusedApp = nil
            searchFocused = true
        } else {
            dismissWindow(id: "main")
        }
        return .handled
    }
}
