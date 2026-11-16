//
//  AppGridView.swift
//  Inlet
//
//  The full grid, shown on the overlay: a header, the search panel, the
//  category bar, then the grid. Typing filters the grid. Arrow keys move
//  through it. With no search and no category, the grid is paged and can be
//  edited: reorder, merge apps into folders, hide an app, and Undo. Tapping a
//  folder opens it. It sits on the overlay's scrim, so it has no background
//  of its own.
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
        let columns = InletSize.gridColumns
        let rows = Int((Double(total) / Double(columns)).rounded(.up))

        // Center of the grid, in cell units (column and row indexes).
        let centerColumn = Double(columns - 1) / 2
        let centerRow = Double(max(rows - 1, 0)) / 2

        // This cell's position from the center, in points.
        let column = Double(index % columns)
        let row = Double(index / columns)
        let dx = (column - centerColumn) * Double(InletSize.gridCell.width)
        let dy = (row - centerRow) * Double(InletSize.gridCell.height + InletSize.gridRowGap)

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
    /// The saved layout (order, folders, hidden apps), also provided by the overlay.
    @Environment(LayoutStore.self) private var layoutStore
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
    /// The grid item that has keyboard focus, if any. Arrow keys move it.
    /// In the paged grid this is an entry id ("app:…" or "folder:…"); in the
    /// search and category grids it is an app id.
    @FocusState private var focusedApp: AppItem.ID?

    /// The bucket the grid is filtered to. Nil shows every app.
    /// Starts on the last bucket used when "Remember last category" is on.
    @State private var category: AppCategory? = InletSettings.startingCategory
    /// Spotlight file matches for the query, shown under the search field.
    @State private var fileSearch = FileSearch()

    /// Edit mode: icons wobble, drag to reorder, minus badges hide apps.
    /// Only the paged grid has it (no search, no category).
    @State private var isEditing = false
    /// Whether the Hidden apps panel is open.
    @State private var showsHidden = false
    /// The last hidden app, for the Undo toast.
    @State private var undo: HideUndo?
    /// Clears the Undo toast after a few seconds.
    @State private var undoTimer: Task<Void, Never>?
    /// The id of the folder that is open, if any.
    @State private var openFolderID: String?

    /// What the Undo toast needs to know.
    private struct HideUndo: Equatable {
        let appID: String
        let name: String
    }

    /// Column count from Settings > Grid (5 to 9, default 7).
    @AppStorage(InletSettings.Key.gridColumns.rawValue) private var gridColumns = 7
    /// Settings > General and Search. Read here so each change applies at once.
    @AppStorage(InletSettings.Key.rememberLastCategory.rawValue) private var rememberLastCategory = true
    @AppStorage(InletSettings.Key.escapeClearsSearchFirst.rawValue) private var escapeClearsSearchFirst = true
    @AppStorage(InletSettings.Key.closeAfterLaunch.rawValue) private var closeAfterLaunch = true
    @AppStorage(InletSettings.Key.searchIncludesFiles.rawValue) private var searchIncludesFiles = true
    @AppStorage(InletSettings.Key.searchFileResultCount.rawValue) private var fileResultCount = 5

    /// Fixed-width columns. Cell width is unchanged, so the count sets the grid width.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(InletSize.gridCell.width), spacing: 0),
            count: gridColumns
        )
    }

    /// Smallest width that fits the current column count plus side padding.
    private var minimumGridWidth: CGFloat {
        InletSize.gridCell.width * CGFloat(gridColumns) + InletSize.gridSidePadding * 2
    }

    /// True when the query has something other than spaces in it.
    private var isSearching: Bool { !AppSearch.normalize(query).isEmpty }

    /// The paged, editable grid: no search and no category filter.
    private var isPaged: Bool { !isSearching && category == nil }

    /// The apps to show. Searching looks through every app, since the category
    /// bar is hidden then. Otherwise the grid shows the selected bucket.
    /// Matches come back best-first.
    private var shownApps: [AppItem] {
        let pool = isSearching ? library.apps : AppCategory.filter(library.apps, by: category)
        return AppSearch.results(for: query, in: pool)
    }

    /// The entries of the paged grid, in layout order. Apps that are not
    /// installed are left out, as the grid leaves them out.
    private var pagedEntries: [GridEntry] {
        let installed = Set(library.apps.map(\.id))
        return layoutStore.layout.entries.filter { entry in
            switch entry {
            case .app(let appID):
                return installed.contains(appID)
            case .folder(let folder):
                return folder.appIDs.contains { installed.contains($0) }
            }
        }
    }

    /// The ids arrow keys move through, in the order the grid draws them.
    private var navIDs: [String] {
        isPaged ? pagedEntries.map(\.id) : shownApps.map(\.id)
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
                .padding(.bottom, InletSpace.xl)

                // Fades out while typing, so the search results take its place.
                // It keeps its space, so the grid below does not jump.
                CategoryBar(selection: $category, isFaded: isSearching)
                    .padding(.bottom, InletSpace.l)

                content
            }
            // Keep the keyboard-focused icon on screen as arrows move it.
            .onChange(of: focusedApp) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
        }
        .frame(minWidth: minimumGridWidth, maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) { hiddenPanel }
        .overlay(alignment: .bottom) { undoToast }
        .overlay { folderOverlay }
        // The field has focus when the overlay opens, so you can type at once.
        .defaultFocus($searchFocused, true)
        // Typing again returns keyboard focus to the field from the grid.
        .onChange(of: query) { _, newQuery in
            focusedApp = nil
            // Searching and editing don't mix, since search isn't paged.
            if isSearching { isEditing = false }
            // Zero when the setting is off, which clears the file rows.
            fileSearch.update(
                query: newQuery,
                resultCount: searchIncludesFiles ? fileResultCount : 0
            )
        }
        .onChange(of: category) { _, newCategory in
            // Focus ids differ between the paged and the filtered grids.
            focusedApp = nil
            // A category filter is not paged, so leave Edit mode with it.
            if newCategory != nil { isEditing = false }
            if rememberLastCategory {
                InletSettings.saveLastCategory(newCategory)
            }
        }
        // Keep the saved layout in step with what is installed.
        .onChange(of: library.apps) { _, apps in reconcileLayout(apps) }
        .onChange(of: library.hasScanned) { _, _ in reconcileLayout(library.apps) }
        .onAppear { reconcileLayout(library.apps) }
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
            Text("Inlet")
                .font(InletFont.wordmark)
                .tracking(InletTracking.display)
                .foregroundStyle(InletColor.text)

            Spacer()

            if library.hasScanned {
                // The paged grid counts every app on it, folder members included.
                let visibleCount = isPaged
                    ? max(0, library.apps.count - layoutStore.layout.hidden.count)
                    : shownApps.count
                Text(isSearching
                     ? "\(shownApps.count) of \(library.apps.count)"
                     : "\(visibleCount) apps")
                    .font(InletFont.section)
                    .foregroundStyle(InletText.secondary(contrast))
            }

            if isPaged, !layoutStore.layout.hidden.isEmpty {
                headerButton("Hidden \(layoutStore.layout.hidden.count)") {
                    withAnimation(.inletOpen) { showsHidden.toggle() }
                }
            }

            if isPaged, library.hasScanned, !library.apps.isEmpty {
                headerButton(isEditing ? "Done" : "Edit") {
                    withAnimation(.inletOpen) { isEditing.toggle() }
                }
            }
        }
        .padding(.horizontal, InletSize.gridSidePadding)
        .padding(.top, InletSpace.xxl)
        .padding(.bottom, InletSpace.xl)
    }

    /// A small capsule button for the header.
    private func headerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(InletFont.section)
                .foregroundStyle(InletColor.text)
                .padding(.horizontal, InletSpace.l)
                .padding(.vertical, InletSpace.s)
                .background(Capsule().fill(InletColor.hover))
        }
        .buttonStyle(.plain)
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
                .font(InletFont.subhead)
                .foregroundStyle(InletText.secondary(contrast))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isSearching && shownApps.isEmpty {
            Text("Nothing matches that search.")
                .font(InletFont.subhead)
                .foregroundStyle(InletText.secondary(contrast))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isPaged {
            // Paged and editable, in the saved layout order.
            // Arrow keys still move the focus ring here.
            EditableGridView(
                apps: library.apps,
                columns: gridColumns,
                focusedID: focusedApp,
                isEditing: $isEditing,
                onLaunch: launch,
                onHide: hide,
                onOpenFolder: openFolder
            )
        } else {
            scrollGrid
        }
    }

    /// The search results and category views: one scrolling grid, keyboard-navigable.
    private var scrollGrid: some View {
        let placements = openPlacements
        return ScrollView {
            // `LazyVGrid` only builds the cells that are on screen,
            // so icons load as you scroll instead of all at once.
            LazyVGrid(columns: columns, spacing: InletSize.gridRowGap) {
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
            .padding(.horizontal, InletSize.gridSidePadding)
            .padding(.bottom, InletSpace.xxxl)
            // Reflow when the matches change: the `settle` spring.
            .inletAnimation(.inletSettle, value: shownApps.map(\.id))
        }
    }

    /// The Hidden apps list, opened from the header.
    @ViewBuilder
    private var hiddenPanel: some View {
        if showsHidden, !layoutStore.layout.hidden.isEmpty {
            HiddenAppsPanel(rows: hiddenRows, onRestore: restore)
                .padding(.top, 64)
                .padding(.trailing, InletSize.gridSidePadding)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
        }
    }

    /// The Undo toast, shown for a few seconds after an app is hidden.
    @ViewBuilder
    private var undoToast: some View {
        if let undo {
            UndoToast(message: "Hidden \(undo.name)") { restore(undo.appID) }
                .padding(.bottom, InletSpace.xxl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// The open folder, drawn over the grid with a scrim. Tapping the scrim closes it.
    @ViewBuilder
    private var folderOverlay: some View {
        if let folder = openedFolder {
            ZStack {
                Rectangle()
                    .fill(InletColor.scrim)
                    .contentShape(Rectangle())
                    .onTapGesture { closeFolder() }

                FolderPanel(
                    folder: folder,
                    apps: apps(in: folder),
                    onRename: { renameFolder(folder.id, to: $0) },
                    onLaunch: launch,
                    onTakeOut: { takeOut($0, from: folder.id) },
                    onClose: closeFolder
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
            .coordinateSpace(name: FolderPanel.coordinateSpace)
        }
    }

    private var hiddenRows: [HiddenAppsPanel.Row] {
        layoutStore.layout.hidden.map { (hidden: HiddenApp) -> HiddenAppsPanel.Row in
            let name = library.apps.first(where: { $0.id == hidden.appID })?.name
                ?? URL(fileURLWithPath: hidden.appID).deletingPathExtension().lastPathComponent
            return HiddenAppsPanel.Row(id: hidden.appID, name: name)
        }
    }

    // MARK: Folders

    /// The folder that is open, if it still exists in the layout.
    private var openedFolder: GridFolder? {
        guard let openFolderID else { return nil }
        for entry in layoutStore.layout.entries {
            if case .folder(let folder) = entry, folder.id == openFolderID {
                return folder
            }
        }
        return nil
    }

    /// The apps in a folder, in its order. Apps that are not installed are skipped.
    private func apps(in folder: GridFolder) -> [AppItem] {
        folder.appIDs.compactMap { id in library.apps.first(where: { $0.id == id }) }
    }

    private func openFolder(_ id: String) {
        withAnimation(.inletOpen) { openFolderID = id }
    }

    private func closeFolder() {
        withAnimation(.inletDismiss) { openFolderID = nil }
    }

    private func renameFolder(_ id: String, to name: String) {
        layoutStore.update { $0.renameFolder(withID: id, to: name) }
    }

    /// Takes an app out of its folder. The folder closes so the app can be
    /// seen on the grid, right after the folder.
    private func takeOut(_ app: AppItem, from folderID: String) {
        layoutStore.update { $0.removeFromFolder(appID: app.id, folderID: folderID) }
        closeFolder()
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

    /// Return while an item has keyboard focus: open the app, or open the folder.
    /// Ignored while a folder is open, so typing a name can't launch an app.
    private func openFocusedApp() -> KeyPress.Result {
        guard openFolderID == nil, let id = focusedApp else { return .ignored }

        if isPaged {
            guard let entry = pagedEntries.first(where: { $0.id == id }) else { return .ignored }
            switch entry {
            case .app(let appID):
                guard let app = library.apps.first(where: { $0.id == appID }) else { return .ignored }
                launch(app)
            case .folder(let folder):
                openFolder(folder.id)
            }
            return .handled
        }

        guard let app = shownApps.first(where: { $0.id == id }) else { return .ignored }
        launch(app)
        return .handled
    }

    /// Down arrow in the field: focus the first item in the grid.
    private func enterGrid() -> KeyPress.Result {
        guard let first = navIDs.first else { return .ignored }
        focusedApp = first
        searchFocused = false
        return .handled
    }

    /// Arrow keys while an item has focus. Moves by `offset` positions in the
    /// shown list, so Left and Right stop at the row edges and Up from the top
    /// row hands focus back to the field.
    private func moveFocus(by offset: Int) -> KeyPress.Result {
        guard openFolderID == nil, let current = focusedApp else { return .ignored }
        let ids = navIDs
        guard let index = ids.firstIndex(of: current) else { return .ignored }

        let columns = gridColumns
        let target = index + offset

        if target < 0 {
            // Up from the top row goes back to the field. Left at the very
            // first item just stays put.
            if offset < -1 {
                focusedApp = nil
                searchFocused = true
            }
            return .handled
        }
        guard target < ids.count else { return .handled }

        // Left and Right must stay on the same row.
        if abs(offset) == 1 && target / columns != index / columns {
            return .handled
        }
        focusedApp = ids[target]
        return .handled
    }

    /// Escape closes an open folder first. Then it leaves Edit mode, then it
    /// clears the field when the setting is on. With nothing to clear, it
    /// closes the overlay.
    private func handleEscape() -> KeyPress.Result {
        if openFolderID != nil {
            closeFolder()
        } else if isEditing {
            withAnimation(.inletDismiss) { isEditing = false }
        } else if isSearching && escapeClearsSearchFirst {
            query = ""
            focusedApp = nil
            searchFocused = true
        } else {
            dismissOverlay()
        }
        return .handled
    }

    /// Hides an app and shows the Undo toast.
    private func hide(_ app: AppItem) {
        layoutStore.update { $0.hideApp(app.id) }
        undoTimer?.cancel()
        withAnimation(.inletRise) {
            undo = HideUndo(appID: app.id, name: app.name)
        }
        undoTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.2))
            guard !Task.isCancelled else { return }
            dismissUndo()
        }
    }

    /// Puts a hidden app back where it was.
    private func restore(_ appID: String) {
        layoutStore.update { $0.restoreApp(appID) }
        if undo?.appID == appID { dismissUndo() }
    }

    private func dismissUndo() {
        undoTimer?.cancel()
        undoTimer = nil
        withAnimation(.inletDismiss) { undo = nil }
    }

    /// Makes the saved layout match the installed apps.
    /// Skipped before the first scan, and for an empty scan, so a failed
    /// scan can't wipe the saved layout.
    private func reconcileLayout(_ apps: [AppItem]) {
        guard library.hasScanned, !apps.isEmpty else { return }
        layoutStore.reconcile(with: apps)
    }
}
