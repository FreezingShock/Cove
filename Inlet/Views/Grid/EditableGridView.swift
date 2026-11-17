//
//  EditableGridView.swift
//  Inlet
//
//  The paged grid. Swipe between pages, press and hold for Edit mode, then
//  drag icons to reorder them, drop one app on another to make a folder, tap
//  a folder to open it, or tap a minus badge to hide an app.
//
//  One drag gesture covers the whole page and works out what was hit. Each
//  icon is placed by its slot, so a dragged icon can move across pages.
//  Nothing is written to disk until a drag ends.
//

import SwiftUI

struct EditableGridView: View {
    /// Installed apps, from the library.
    let apps: [AppItem]
    /// Column count from Settings > Grid (5 to 9).
    let columns: Int
    /// The entry with keyboard focus, if any: "app:…" or "folder:…".
    /// Its page is shown when focus moves.
    let focusedID: String?
    /// Edit mode. AppGridView owns it, so the header can show Done.
    @Binding var isEditing: Bool
    /// True once the overlay is open. Drives the icons' open ripple.
    let isOpen: Bool
    /// Opens an app.
    let onLaunch: (AppItem) -> Void
    /// Hides an app. The caller shows the Undo toast.
    let onHide: (AppItem) -> Void
    /// Opens a folder, by its id.
    let onOpenFolder: (String) -> Void
    /// Moves an entry (an app or a folder) by a number of slots in the layout. Keyboard and VoiceOver reorder.
    let onMove: (String, Int) -> Void
    /// A tap on empty space outside Edit mode. Closes the overlay.
    let onBlankTap: () -> Void
    /// Moves an app into another group. Offered from the icon's context menu.
    let onMoveToGroup: (AppItem, String) -> Void

    @Environment(LayoutStore.self) private var layoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One entry on the grid, ready to draw: a plain app or a folder.
    private struct Slot: Identifiable, Equatable {
        /// `GridEntry.id`: "app:…" or "folder:…".
        let id: String
        let entry: GridEntry
        /// The apps the icon shows. One for an app, up to nine for a folder.
        let apps: [AppItem]
    }

    /// The page the user is on. Clamped to the page count when drawn.
    @State private var page = 0
    /// Live horizontal drag, in points, while swiping between pages.
    @State private var swipeOffset: CGFloat = 0
    /// The press in progress, if any.
    @State private var press: Press?
    /// The entry being dragged in Edit mode, if any.
    @State private var drag: Drag?
    /// The order while an entry is dragged. Saved only when the drag ends.
    @State private var draft: [Slot]?
    /// The entry under the pointer, if any. Drawn with the hover fill.
    @State private var hoveredID: String?
    /// The entry a dragged app would merge into, if any.
    @State private var mergeTarget: String?
    /// The liquid pull between the dragged app and `mergeTarget`, if any.
    @State private var liquid: LiquidLink?
    /// Counts down the hold that turns a press into Edit mode.
    @State private var holdTask: Task<Void, Never>?
    /// Counts down the pause that flips the page at a window edge.
    @State private var edgeTask: Task<Void, Never>?
    /// Watches trackpad scrolls, so a two-finger swipe turns the page.
    @State private var trackpad = TrackpadPaging()
    /// Horizontal total of the trackpad swipe in progress.
    @State private var trackpadTotal: CGFloat = 0
    /// Geometry and page count from the latest layout. The trackpad handler reads them.
    @State private var pagingGeo: GridGeometry?
    @State private var pagingCount = 0

    /// What a press has done so far.
    private struct Press {
        /// Where the press began, in grid space.
        var start: CGPoint
        /// The entry under the press, if any.
        var hitID: String?
        /// True once the pointer has moved past the tap slop.
        var moved = false
        /// True once the hold has switched on Edit mode during this press.
        var enteredEdit = false
    }

    /// An entry being dragged.
    private struct Drag {
        var id: String
        /// From the pointer to the entry's center, fixed when the drag began.
        var grab: CGSize
        /// The entry's center in grid space, so it stays under the pointer when the page flips.
        var center: CGPoint
    }

    /// Where the liquid pull runs, in window coordinates of the grid.
    private struct LiquidLink: Equatable {
        var from: CGPoint
        var to: CGPoint
    }

    private static let space = "grid"
    /// Movement under this many points still counts as a tap.
    private static let tapSlop: CGFloat = 6
    /// How long a press must last to enter Edit mode.
    private static let holdTime: Duration = .milliseconds(480)
    /// How long a drag must rest at a window edge before the page flips.
    private static let edgeDwell: Duration = .milliseconds(520)
    /// Radius of the minus badge's tap target.
    private static let badgeRadius: CGFloat = 18
    /// Within this distance of another icon, a dragged app merges into it.
    /// The spec: 0.55 of an icon radius, about 40 pt at 72 pt.
    private static let mergeRadius: CGFloat = InletSize.gridIcon * 0.55
    /// Within this distance the liquid pull starts. The spec: 0.9 radii.
    private static let pullRadius: CGFloat = InletSize.gridIcon * 0.9

    /// Wraps a Inlet spring. Under Reduce Motion it becomes a short crossfade.
    private func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .inletFade : animation
    }

    /// Entries in grid order, with the saved layout applied. A drag shows its draft order instead.
    private var displaySlots: [Slot] {
        draft ?? visibleSlots
    }

    /// The saved layout, as slots. Apps that are not installed are skipped.
    private var visibleSlots: [Slot] {
        let byID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return layoutStore.layout.entries.compactMap { entry -> Slot? in
            switch entry {
            case .app(let appID):
                guard let app = byID[appID] else { return nil }
                return Slot(id: entry.id, entry: entry, apps: [app])
            case .folder(let folder):
                let members = folder.appIDs.compactMap { byID[$0] }
                guard !members.isEmpty else { return nil }
                return Slot(id: entry.id, entry: entry, apps: members)
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let stageHeight = max(1, proxy.size.height - GridMetrics.dotsHeight)
            let geo = GridGeometry.make(
                pageSize: CGSize(width: max(1, proxy.size.width), height: stageHeight),
                columns: columns,
                cellSize: InletSize.gridCell,
                rowSpacing: InletSize.gridRowGap
            )
            let items = displaySlots
            let pages = geo.pageCount(itemCount: items.count)
            let current = min(page, pages - 1)

            VStack(spacing: 0) {
                stage(items: items, geo: geo, height: stageHeight, current: current)
                pageDots(current: current, pages: pages)
                    .frame(height: GridMetrics.dotsHeight)
            }
            .onChange(of: geo, initial: true) { _, newGeo in pagingGeo = newGeo }
            .onChange(of: items.count, initial: true) { _, count in pagingCount = count }
        }
        // Leaving Edit mode cancels any drag still in progress.
        .onChange(of: isEditing) { _, editing in
            if !editing { cancelDrag() }
        }
        .onAppear { startTrackpadPaging() }
        .onDisappear { trackpad.stop() }
    }

    // MARK: - Drawing

    /// The icons, placed by slot and shifted to show the current page.
    private func stage(items: [Slot], geo: GridGeometry, height: CGFloat, current: Int) -> some View {
        let track = -CGFloat(current) * geo.pageWidth + swipeOffset
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, slot in
                tile(for: slot, index: index, total: items.count, geo: geo, track: track)
            }
            .frame(width: geo.pageWidth, height: height, alignment: .topLeading)
            .offset(x: track)

            // Drawn in window coordinates, so it stays put while the page moves.
            if let liquid {
                LiquidPull(from: liquid.from, to: liquid.to)
            }
        }
        .frame(width: geo.pageWidth, height: height)
        .clipped()
        .contentShape(Rectangle())
        .coordinateSpace(name: Self.space)
        .gesture(pressGesture(geo: geo))
        .onContinuousHover(coordinateSpace: .named(Self.space)) { phase in
            updateHover(phase, geo: geo)
        }
        // Keyboard focus moves to another page: show that page.
        .onChange(of: focusedID) { _, id in
            revealPage(of: id, geo: geo)
        }
        // Reorders and page changes animate. Ids only, so a swipe doesn't re-animate.
        .animation(motion(.inletSettle), value: items.map(\.id))
    }

    /// One entry on the page, placed at its slot. Kept out of the ForEach closure,
    /// so the compiler checks its modifier chain on its own.
    private func tile(for slot: Slot, index: Int, total: Int, geo: GridGeometry, track: CGFloat) -> some View {
        let placement = openPlacement(forIndex: index, total: total, geo: geo)
        let center = tilePosition(for: slot, index: index, geo: geo, track: track)
        let dragging = isDragging(slot)

        // Arguments follow the order of GridTile's stored properties.
        return GridTile(
            title: title(for: slot),
            apps: slot.apps,
            isFolder: isFolder(slot),
            isEditing: isEditing,
            showsBadge: showsBadge(for: slot),
            isLifted: dragging,
            isPressed: isPressed(slot),
            isKeyboardFocused: slot.id == focusedID,
            isHovered: isHoverTarget(slot),
            isMergeTarget: mergeTarget == slot.id,
            onOpen: { open(slot) },
            onHide: { if let app = plainApp(slot), app.isHideable { onHide(app) } },
            onMove: { onMove(slot.id, $0) },
            placement: placement,
            isOpen: isOpen
        )
        .contextMenu {
            if let app = plainApp(slot) {
                MoveToGroupMenu(
                    groups: layoutStore.layout.groups,
                    currentGroupID: layoutStore.layout.groupID(containing: app.id),
                    onSelect: { onMoveToGroup(app, $0) }
                )
            }
        }
        .frame(width: InletSize.gridCell.width, height: GridMetrics.cellHeight, alignment: .top)
        .position(center)
        // The dragged icon follows the pointer exactly, so it doesn't animate.
        .transaction { transaction in
            if dragging { transaction.animation = nil }
        }
    }

    /// True while this entry is the one being dragged.
    private func isDragging(_ slot: Slot) -> Bool {
        drag?.id == slot.id
    }

    /// True in Edit mode for an app that can be hidden. Shows its minus badge.
    private func showsBadge(for slot: Slot) -> Bool {
        guard isEditing else { return false }
        return plainApp(slot)?.isHideable ?? false
    }

    /// True when the pointer is over this entry and no drag is running.
    private func isHoverTarget(_ slot: Slot) -> Bool {
        guard drag == nil else { return false }
        return hoveredID == slot.id
    }

    /// True while the press is on this entry and hasn't turned into a swipe or drag.
    private func isPressed(_ slot: Slot) -> Bool {
        guard drag == nil, let press else { return false }
        return press.hitID == slot.id && !press.moved
    }

    /// Where an entry's center sits, in the stage's own coordinates.
    private func tilePosition(for slot: Slot, index: Int, geo: GridGeometry, track: CGFloat) -> CGPoint {
        if let drag, drag.id == slot.id {
            return CGPoint(x: drag.center.x - track, y: drag.center.y)
        }
        return geo.center(ofIndex: index)
    }

    /// Page dots. Tapping one jumps to that page. Hidden when there is only one page.
    private func pageDots(current: Int, pages: Int) -> some View {
        HStack(spacing: InletSpace.xs) {
            ForEach(0..<pages, id: \.self) { index in
                Button {
                    withAnimation(motion(.inletSettle)) { page = index }
                } label: {
                    Capsule()
                        .fill(index == current ? InletColor.accent : InletColor.track)
                        .frame(width: index == current ? 16 : 7, height: 7)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(index + 1) of \(pages)")
            }
        }
        .inletAnimation(.inletSnap, value: current)
        .opacity(pages > 1 ? 1 : 0)
        .allowsHitTesting(pages > 1)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Slot helpers

    private func isFolder(_ slot: Slot) -> Bool {
        if case .folder = slot.entry { return true }
        return false
    }

    /// The app behind a plain icon. Nil for a folder.
    private func plainApp(_ slot: Slot) -> AppItem? {
        guard case .app = slot.entry else { return nil }
        return slot.apps.first
    }

    /// The name under an icon: the folder's name, or the app's name.
    private func title(for slot: Slot) -> String {
        if case .folder(let folder) = slot.entry { return folder.name }
        return slot.apps.first?.name ?? ""
    }

    /// Launches an app, or opens a folder.
    private func open(_ slot: Slot) {
        switch slot.entry {
        case .app:
            if let app = slot.apps.first { onLaunch(app) }
        case .folder(let folder):
            onOpenFolder(folder.id)
        }
    }

    /// A dragged plain app may merge into an app, or into a folder with room.
    /// Folders are only reordered, never dropped into a folder.
    private func canMerge(_ dragged: Slot, into target: Slot) -> Bool {
        guard plainApp(dragged) != nil else { return false }
        if case .folder(let folder) = target.entry {
            return folder.appIDs.count < GridFolder.maxApps
        }
        return true
    }

    /// The name for a new folder: the apps' shared category, or "New Folder".
    private func folderName(for apps: [AppItem]) -> String {
        let categories = Set(apps.map(\.category))
        if categories.count == 1, let only = categories.first { return only.title }
        return "New Folder"
    }

    // MARK: - Gestures

    private func pressGesture(geo: GridGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in changed(value, geo: geo) }
            .onEnded { value in ended(value, geo: geo) }
    }

    /// Every movement of the press. Decides between a hold, a swipe and a drag.
    private func changed(_ value: DragGesture.Value, geo: GridGeometry) {
        if press == nil {
            let hitID = slot(at: value.startLocation, geo: geo)?.id
            press = Press(start: value.startLocation, hitID: hitID)
            if !isEditing { startHold() }
        }
        guard var state = press else { return }

        let dx = value.translation.width
        let dy = value.translation.height
        if !state.moved, hypot(dx, dy) > Self.tapSlop {
            state.moved = true
            cancelHold()
        }
        press = state

        if drag != nil {
            updateDrag(to: value.location, geo: geo)
            return
        }
        guard state.moved else { return }

        if isEditing, let hitID = state.hitID {
            beginDrag(id: hitID, start: state.start, geo: geo)
            updateDrag(to: value.location, geo: geo)
            return
        }

        // Anything else that moves sideways swipes the pages.
        if abs(dx) > abs(dy) {
            swipeOffset = rubberBand(dx, geo: geo, count: displaySlots.count)
        }
    }

    /// The press ended. Settles a swipe, drops a drag, or treats the press as a tap.
    private func ended(_ value: DragGesture.Value, geo: GridGeometry) {
        defer {
            press = nil
            cancelHold()
        }
        guard let state = press else { return }

        if drag != nil {
            finishDrag()
            return
        }

        if state.moved {
            // A swipe settles on the next or previous page when it is long or quick enough.
            settleSwipe(predicted: value.predictedEndTranslation.width, geo: geo, count: displaySlots.count)
            return
        }

        // A tap. A press that just entered Edit mode is not a tap.
        if state.enteredEdit { return }

        if isEditing {
            guard let hitID = state.hitID, let slot = displaySlots.first(where: { $0.id == hitID }) else {
                // A tap on empty space leaves Edit mode.
                withAnimation(motion(.inletDismiss)) { isEditing = false }
                return
            }
            if let app = plainApp(slot), app.isHideable, isOnBadge(state.start, id: slot.id, geo: geo) {
                onHide(app)
                return
            }
            // A tap on a folder still opens it, so folders work in Edit mode too.
            open(slot)
            return
        }

        if let hitID = state.hitID, let slot = displaySlots.first(where: { $0.id == hitID }) {
            open(slot)
        } else {
            // A tap on empty space closes the overlay, as classic Launchpad did.
            onBlankTap()
        }
    }

    // MARK: - Hit testing

    /// Horizontal offset of the whole stage: the current page, plus any live swipe.
    private func trackOffset(_ geo: GridGeometry) -> CGFloat {
        -CGFloat(currentPage(geo)) * geo.pageWidth + swipeOffset
    }

    /// The page on screen, clamped to the page count.
    private func currentPage(_ geo: GridGeometry) -> Int {
        min(page, geo.pageCount(itemCount: displaySlots.count) - 1)
    }

    /// The entry under a point on screen (window coordinates of the grid), if any.
    private func slot(at point: CGPoint, geo: GridGeometry) -> Slot? {
        let items = displaySlots
        let stagePoint = CGPoint(x: point.x - trackOffset(geo), y: point.y)
        guard let index = geo.index(at: stagePoint), index < items.count else { return nil }
        return items[index]
    }

    /// True when a point on screen is on an app's minus badge.
    private func isOnBadge(_ point: CGPoint, id: String, geo: GridGeometry) -> Bool {
        guard let index = displaySlots.firstIndex(where: { $0.id == id }) else { return false }
        let slot = geo.center(ofIndex: index)
        // The icon's top-left corner, where the badge sits. The icon is centered
        // in its cell and sits 10 pt below the cell's top edge (see GridTile).
        let badge = CGPoint(
            x: slot.x + trackOffset(geo) - InletSize.gridIcon / 2,
            y: slot.y - GridMetrics.cellHeight / 2 + InletSpace.s + InletSpace.xxs
        )
        return hypot(point.x - badge.x, point.y - badge.y) <= Self.badgeRadius
    }

    /// Tracks the entry under the pointer for the hover fill.
    private func updateHover(_ phase: HoverPhase, geo: GridGeometry) {
        switch phase {
        case .active(let point):
            let id = slot(at: point, geo: geo)?.id
            if hoveredID != id { hoveredID = id }
        case .ended:
            hoveredID = nil
        }
    }

    // MARK: - Edit mode

    /// Starts the hold timer. If the press hasn't moved after 480 ms, Edit mode turns on.
    private func startHold() {
        cancelHold()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: Self.holdTime)
            guard !Task.isCancelled, press?.moved == false else { return }
            press?.enteredEdit = true
            withAnimation(motion(.inletOpen)) { isEditing = true }
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
    }

    /// Starts dragging an entry. The draft starts as the current order.
    private func beginDrag(id: String, start: CGPoint, geo: GridGeometry) {
        let items = displaySlots
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let slot = geo.center(ofIndex: index)
        let center = CGPoint(x: slot.x + trackOffset(geo), y: slot.y)
        draft = items
        drag = Drag(
            id: id,
            grab: CGSize(width: center.x - start.x, height: center.y - start.y),
            center: center
        )
    }

    /// Follows the pointer. Near another icon, a dragged app arms a merge and
    /// the liquid pull starts. Otherwise the entry moves to the nearest slot
    /// on the page. Resting near a window edge flips the page.
    private func updateDrag(to location: CGPoint, geo: GridGeometry) {
        guard var active = drag, var order = draft else { return }
        active.center = CGPoint(x: location.x + active.grab.width, y: location.y + active.grab.height)

        // The entry's center in stage coordinates, where the slots are measured.
        let track = trackOffset(geo)
        let pointer = CGPoint(x: active.center.x - track, y: active.center.y)

        var mergeID: String?
        var link: LiquidLink?

        if let from = order.firstIndex(where: { $0.id == active.id }) {
            let first = currentPage(geo) * geo.perPage
            let last = min(order.count, first + geo.perPage)
            var nearest = from
            var nearestDistance = CGFloat.greatestFiniteMagnitude
            if first < last {
                for index in first..<last {
                    let slot = geo.center(ofIndex: index)
                    let distance = hypot(slot.x - pointer.x, slot.y - pointer.y)
                    if distance < nearestDistance {
                        nearestDistance = distance
                        nearest = index
                    }
                }
            }

            if nearest != from, nearestDistance < Self.mergeRadius,
               canMerge(order[from], into: order[nearest]) {
                // Merging holds the position: the icon waits over its target.
                mergeID = order[nearest].id
                if nearestDistance < Self.pullRadius {
                    let target = geo.center(ofIndex: nearest)
                    link = LiquidLink(
                        from: active.center,
                        to: CGPoint(x: target.x + track, y: target.y)
                    )
                }
            } else if nearest != from {
                let moving = order.remove(at: from)
                order.insert(moving, at: nearest)
                draft = order
            }
        }

        if mergeTarget != mergeID { mergeTarget = mergeID }
        if liquid != link { liquid = link }

        // Resting near a window edge flips the page after a short pause.
        let direction: Int
        if location.x < GridMetrics.edgeZone {
            direction = -1
        } else if location.x > geo.pageWidth - GridMetrics.edgeZone {
            direction = 1
        } else {
            direction = 0
        }
        let target = currentPage(geo) + direction
        let pages = geo.pageCount(itemCount: order.count)
        if direction != 0, target >= 0, target < pages {
            scheduleEdgeFlip(to: target)
        } else {
            cancelEdge()
        }

        drag = active
    }

    private func scheduleEdgeFlip(to target: Int) {
        guard edgeTask == nil else { return }
        edgeTask = Task { @MainActor in
            try? await Task.sleep(for: Self.edgeDwell)
            guard !Task.isCancelled, drag != nil else { return }
            withAnimation(motion(.inletSettle)) { page = target }
            edgeTask = nil
        }
    }

    private func cancelEdge() {
        edgeTask?.cancel()
        edgeTask = nil
    }

    /// Drops the dragged entry. A merge target combines the two into one folder.
    /// Otherwise the new order is saved once, and the entry settles into its slot.
    private func finishDrag() {
        cancelEdge()
        let order = draft ?? displaySlots
        let entries = order.map(\.entry)

        if let dragID = drag?.id,
           let target = mergeTarget,
           let dragged = order.first(where: { $0.id == dragID }),
           let app = plainApp(dragged) {
            let members = order.first(where: { $0.id == target })?.apps ?? []
            let name = folderName(for: [app] + members)
            layoutStore.update { layout in
                // Save the dragged order first, then merge on top of it.
                layout.entries = entries
                layout.merge(appID: app.id, ontoEntryID: target, folderName: name)
            }
        } else {
            layoutStore.update { $0.entries = entries }
        }

        withAnimation(motion(.inletPress)) {
            drag = nil
            draft = nil
            mergeTarget = nil
            liquid = nil
        }
    }

    /// Ends a drag without saving. Used when Edit mode is left mid-drag.
    private func cancelDrag() {
        cancelEdge()
        drag = nil
        draft = nil
        mergeTarget = nil
        liquid = nil
    }

    /// Shows the page that holds the focused entry, when keyboard focus moves to another page.
    private func revealPage(of id: String?, geo: GridGeometry) {
        guard let id, let index = displaySlots.firstIndex(where: { $0.id == id }) else { return }
        let target = index / geo.perPage
        guard target != currentPage(geo) else { return }
        withAnimation(motion(.inletSettle)) { page = target }
    }

    /// Past the first or last page the swipe is pulled back, like a rubber band.
    private func rubberBand(_ raw: CGFloat, geo: GridGeometry, count: Int) -> CGFloat {
        let last = geo.pageCount(itemCount: count) - 1
        let current = min(page, last)
        let pastEnd = (current == 0 && raw > 0) || (current == last && raw < 0)
        return pastEnd ? raw * 0.3 : raw
    }

    /// Settles a swipe on the next or previous page when it is long or quick
    /// enough. `predicted` is where the swipe would end, with its momentum.
    private func settleSwipe(predicted: CGFloat, geo: GridGeometry, count: Int) {
        let last = geo.pageCount(itemCount: count) - 1
        let current = min(page, last)
        let width = geo.pageWidth
        var target = current
        if swipeOffset < -width * 0.2 || predicted < -width / 2 {
            target = current + 1
        } else if swipeOffset > width * 0.2 || predicted > width / 2 {
            target = current - 1
        }
        withAnimation(motion(.inletSettle)) {
            page = min(max(target, 0), last)
            swipeOffset = 0
        }
    }

    /// Starts the trackpad handler. Each scroll moves the pages with the fingers,
    /// and lifting them settles the page. A mouse drag already in progress wins.
    private func startTrackpadPaging() {
        trackpad.onScroll = { dx in
            guard let geo = pagingGeo, pagingCount > 1, drag == nil else { return }
            trackpadTotal += dx
            swipeOffset = rubberBand(trackpadTotal, geo: geo, count: pagingCount)
        }
        trackpad.onEnd = {
            let total = trackpadTotal
            trackpadTotal = 0
            guard let geo = pagingGeo, pagingCount > 1 else { return }
            settleSwipe(predicted: total, geo: geo, count: pagingCount)
        }
        trackpad.start()
    }

    /// Open-animation placement for an icon. It is measured within its own
    /// page, so the ripple starts from that page's center.
    private func openPlacement(forIndex index: Int, total: Int, geo: GridGeometry) -> OpenPlacement {
        let pageStart = (index / geo.perPage) * geo.perPage
        let pageTotal = min(geo.perPage, total - pageStart)
        return OpenPlacement.forCell(at: index - pageStart, total: pageTotal, columns: geo.columns)
    }
}
