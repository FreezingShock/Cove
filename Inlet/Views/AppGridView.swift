//
//  AppGridView.swift
//  Inlet
//
//  The full grid, shown on the overlay: a header, the search panel, the
//  group bar, then the grid. Typing filters the grid. Arrow keys move
//  through it. With no search and no group, the grid is paged and can be
//  edited: reorder, hide an app, and Undo. It sits on the overlay's scrim, so
//  it has no background of its own.
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
    /// The saved layout (order, hidden apps), also provided by the overlay.
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
    /// The icon that has keyboard focus, if any. Arrow keys move it.
    @FocusState private var focusedApp: AppItem.ID?

    /// The group the grid is filtered to, by group id. Nil shows every app.
    /// Starts on the last group used when "Remember the last group" is on.
    @State private var groupID: String? = InletSettings.startingGroupID
    /// Spotlight file matches for the query, shown under the search field.
    @State private var fileSearch = FileSearch()

    /// Edit mode: icons wobble, drag to reorder, minus badges hide apps.
    /// Only the paged grid has it (no search, no group).
    @State private var isEditing = false
    /// Whether the Hidden apps panel is open.
    @State private var showsHidden = false
    /// Whether the Groups panel is open.
    @State private var showsGroups = false
    /// The last hidden app, for the Undo toast.
    @State private var undo: HideUndo?
    /// Clears the Undo toast after a few seconds.
    @State private var undoTimer: Task<Void, Never>?

    /// What the Undo toast needs to know.
    private struct HideUndo: Equatable {
        let appID: String
        let name: String
    }

    /// Column count from Settings > Grid (5 to 9, default 7).
    @AppStorage(InletSettings.Key.gridColumns.rawValue) private var gridColumns = 7
    /// Settings > General and Search. Read here so each change applies at once.
    @AppStorage(InletSettings.Key.rememberLastGroup.rawValue) private var rememberLastGroup = true
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

    /// The paged, editable grid: no search and no group filter.
    private var isPaged: Bool { !isSearching && groupID == nil }

    /// The apps to show. Searching looks through every app, since the group
    /// bar is faded then. Otherwise the grid shows the selected group.
    /// Matches come back best-first.
    private var shownApps: [AppItem] {
        let pool = isSearching ? library.apps : groupApps
        return AppSearch.results(for: query, in: pool)
    }

    /// The apps in the selected group, in the group's order. Hidden apps are
    /// left out, as they are everywhere except the Hidden list.
    private var groupApps: [AppItem] {
        guard let groupID, let group = layoutStore.layout.groups.first(where: { $0.id == groupID }) else {
            return library.apps
        }
        let byID = Dictionary(library.apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let hiddenIDs = Set(layoutStore.layout.hidden.map(\.appID))
        return group.appIDs.compactMap { byID[$0] }.filter { !hiddenIDs.contains($0.id) }
    }

    /// The apps in the order the grid draws them, which arrow keys follow.
    /// The paged grid uses the saved layout order; everything else uses `shownApps`.
    private var navApps: [AppItem] {
        isPaged ? layoutApps : shownApps
    }

    /// Apps from the saved layout, in grid order. Hidden apps are not here.
    /// Until the folders change lands, every entry in the layout is an app.
    private var layoutApps: [AppItem] {
        let byID = Dictionary(library.apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return layoutStore.layout.entries.compactMap { entry -> AppItem? in
            guard case .app(let appID) = entry else { return nil }
            return byID[appID]
        }
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
                if !layoutStore.layout.groups.isEmpty {
                    GroupBar(
                        groups: layoutStore.layout.groups,
                        selection: $groupID,
                        isFaded: isSearching,
                        onDrop: dropApps
                    )
                    .padding(.bottom, InletSpace.l)
                }

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
        .overlay(alignment: .topTrailing) { groupsPanel }
        .overlay(alignment: .bottom) { undoToast }
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
        .onChange(of: groupID) { _, newGroupID in
            // A group filter is not paged, so leave Edit mode with it.
            if newGroupID != nil { isEditing = false }
            if rememberLastGroup {
                InletSettings.saveLastGroup(newGroupID)
            }
        }
        // A deleted group can't stay selected.
        .onChange(of: layoutStore.layout.groups.map(\.id)) { _, ids in
            if let groupID, !ids.contains(groupID) { self.groupID = nil }
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
        .onKeyPress(.leftArrow, phases: .down) { arrow($0, by: -1) }
        .onKeyPress(.rightArrow, phases: .down) { arrow($0, by: 1) }
        .onKeyPress(.upArrow, phases: .down) { arrow($0, by: -gridColumns) }
        .onKeyPress(.downArrow, phases: .down) { arrow($0, by: gridColumns) }
        .onKeyPress(.delete, phases: .down) { _ in deleteFocusedApp() }
        // No scan here: the app scans once at launch (spec: never scan on open).
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Inlet")
                .font(InletFont.wordmark)
                .tracking(InletTracking.display)
                .foregroundStyle(InletColor.text)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if library.hasScanned {
                Text(isSearching
                     ? "\(shownApps.count) of \(library.apps.count)"
                     : "\(navApps.count) apps")
                    .font(InletFont.section)
                    .foregroundStyle(InletText.secondary(contrast))
            }

            if isPaged, !layoutStore.layout.hidden.isEmpty {
                headerButton("Hidden \(layoutStore.layout.hidden.count)") {
                    withAnimation(motion(.inletOpen)) {
                        showsGroups = false
                        showsHidden.toggle()
                    }
                }
            }

            if library.hasScanned, !library.apps.isEmpty {
                headerButton("Groups") {
                    withAnimation(motion(.inletOpen)) {
                        showsHidden = false
                        showsGroups.toggle()
                    }
                }
            }

            if isPaged, library.hasScanned, !library.apps.isEmpty {
                headerButton(isEditing ? "Done" : "Edit") {
                    withAnimation(motion(.inletOpen)) { isEditing.toggle() }
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
        } else if !isPaged && shownApps.isEmpty {
            // A group with nothing in it yet. Say how to fill it.
            Text("No apps in \(selectedGroupName) yet. Drag an icon onto its name in the bar, or right-click an icon to move it here.")
                .font(InletFont.subhead)
                .foregroundStyle(InletText.secondary(contrast))
                .multilineTextAlignment(.center)
                .padding(.horizontal, InletSize.gridSidePadding)
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
                onMove: move,
                onMoveToGroup: moveToGroup
            )
        } else {
            scrollGrid
        }
    }

    /// The search results and group views: one scrolling grid, keyboard-navigable.
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
                    .contextMenu {
                        MoveToGroupMenu(
                            groups: layoutStore.layout.groups,
                            currentGroupID: layoutStore.layout.groupID(containing: app.id),
                            onSelect: { moveToGroup(app, $0) }
                        )
                    }
                    // Drag an icon onto a group segment on the bar to move it there.
                    .draggable(app.id)
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
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
        }
    }

    /// The Groups panel, opened from the header.
    @ViewBuilder
    private var groupsPanel: some View {
        if showsGroups {
            GroupsPanel(
                groups: layoutStore.layout.groups,
                onAdd: addGroup,
                onRename: { id, name in
                    layoutStore.update { $0.editGroup(withID: id, name: name) }
                },
                onRecolor: { id, color in
                    layoutStore.update { $0.editGroup(withID: id, color: color) }
                },
                onSetSymbol: { id, symbol in
                    layoutStore.update { $0.editGroup(withID: id, symbol: symbol) }
                },
                onMove: { id, index in
                    withAnimation(motion(.inletSettle)) {
                        layoutStore.update { $0.moveGroup(withID: id, to: index) }
                    }
                },
                onDelete: { id in
                    withAnimation(motion(.inletSettle)) {
                        layoutStore.update { $0.deleteGroup(withID: id) }
                    }
                }
            )
            .padding(.top, 64)
            .padding(.trailing, InletSize.gridSidePadding)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
        }
    }

    /// The Undo toast, shown for a few seconds after an app is hidden.
    @ViewBuilder
    private var undoToast: some View {
        if let undo {
            UndoToast(message: "Hidden \(undo.name)") { restore(undo.appID) }
                .padding(.bottom, InletSpace.xxl)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var hiddenRows: [HiddenAppsPanel.Row] {
        layoutStore.layout.hidden.map { (hidden: HiddenApp) -> HiddenAppsPanel.Row in
            let name = library.apps.first(where: { $0.id == hidden.appID })?.name
                ?? URL(fileURLWithPath: hidden.appID).deletingPathExtension().lastPathComponent
            return HiddenAppsPanel.Row(id: hidden.appID, name: name)
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
              let app = navApps.first(where: { $0.id == id }) else { return .ignored }
        launch(app)
        return .handled
    }

    /// Down arrow in the field: focus the first icon in the grid.
    private func enterGrid() -> KeyPress.Result {
        guard let first = navApps.first else { return .ignored }
        focusedApp = first.id
        searchFocused = false
        return .handled
    }

    /// Arrow keys while an icon has focus. Moves by `offset` positions in the
    /// shown list, so Left and Right stop at the row edges and Up from the top
    /// row hands focus back to the field.
    private func moveFocus(by offset: Int) -> KeyPress.Result {
        guard let current = focusedApp else { return .ignored }
        let apps = navApps
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

    /// Spring when Reduce Motion is off, a 0.2 s crossfade when it is on.
    private func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .inletFade : animation
    }

    /// Left, right, up and down. Option + arrow in Edit mode moves the focused
    /// icon in the saved layout. A plain arrow moves the focus ring.
    private func arrow(_ press: KeyPress, by offset: Int) -> KeyPress.Result {
        if isEditing, press.modifiers.contains(.option) {
            guard let id = focusedApp, let app = navApps.first(where: { $0.id == id }) else { return .ignored }
            move(app, by: offset)
            return .handled
        }
        return moveFocus(by: offset)
    }

    /// Moves an app `offset` slots in the saved layout, clamped at the ends.
    /// Edit mode only. VoiceOver's Move earlier and Move later call this too.
    private func move(_ app: AppItem, by offset: Int) {
        guard isEditing else { return }
        let entryID = GridEntry.app(app.id).id
        let entries = layoutStore.layout.entries
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let target = min(max(index + offset, 0), entries.count - 1)
        guard target != index else { return }
        withAnimation(motion(.inletSettle)) {
            layoutStore.update { $0.moveEntry(withID: entryID, to: target) }
        }
    }

    /// Edit mode: Delete hides the focused icon, the keyboard path to the minus
    /// badge. Focus moves to the icon that takes its place.
    private func deleteFocusedApp() -> KeyPress.Result {
        guard isEditing, let id = focusedApp,
              let app = navApps.first(where: { $0.id == id }), app.isHideable else { return .ignored }
        let index = navApps.firstIndex(where: { $0.id == id }) ?? 0
        hide(app)
        let remaining = navApps
        focusedApp = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        return .handled
    }

    /// Escape leaves Edit mode first. Then it clears the field when the setting
    /// is on. With nothing to clear, it closes the overlay.
    private func handleEscape() -> KeyPress.Result {
        if showsGroups {
            withAnimation(motion(.inletDismiss)) { showsGroups = false }
        } else if isEditing {
            withAnimation(motion(.inletDismiss)) { isEditing = false }
        } else if isSearching && escapeClearsSearchFirst {
            query = ""
            focusedApp = nil
            searchFocused = true
        } else {
            dismissOverlay()
        }
        return .handled
    }

    /// Adds a group named "New Group" at the end of the bar. Rename it in the panel.
    private func addGroup() {
        layoutStore.update { layout in
            _ = layout.addGroup(name: "New Group", color: layout.unusedColor, symbol: "star")
        }
    }

    /// Moves dropped icons into a group. One change, so the group bar's
    /// selection and the saved file update together.
    private func dropApps(_ targetGroupID: String, _ appIDs: [String]) {
        layoutStore.update { layout in
            for appID in appIDs {
                layout.moveApp(appID, toGroup: targetGroupID)
            }
        }
    }

    /// The name of the selected group, for empty-group messages.
    private var selectedGroupName: String {
        layoutStore.layout.groups.first(where: { $0.id == groupID })?.name ?? "this group"
    }

    /// Moves an app into another group. Works from every view, so the group bar
    /// and the grid stay in step.
    private func moveToGroup(_ app: AppItem, _ targetGroupID: String) {
        layoutStore.update { $0.moveApp(app.id, toGroup: targetGroupID) }
    }

    /// Hides an app and shows the Undo toast.
    private func hide(_ app: AppItem) {
        layoutStore.update { $0.hideApp(app.id) }
        undoTimer?.cancel()
        withAnimation(motion(.inletRise)) {
            undo = HideUndo(appID: app.id, name: app.name)
        }
        // The toast is visual only, so say it out loud for VoiceOver.
        AccessibilityNotification.Announcement("Hidden \(app.name). Undo is available for a few seconds.").post()
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
        withAnimation(motion(.inletDismiss)) { undo = nil }
    }

    /// Makes the saved layout match the installed apps.
    /// Skipped before the first scan, and for an empty scan, so a failed
    /// scan can't wipe the saved layout.
    private func reconcileLayout(_ apps: [AppItem]) {
        guard library.hasScanned, !apps.isEmpty else { return }
        layoutStore.reconcile(with: apps)
    }
}
