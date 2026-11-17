//
//  EditableGridView.swift
//  Inlet
//
//  The paged grid. Swipe between pages, press and hold for Edit mode, then
//  drag icons to reorder them, or tap a minus badge to hide an app.
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
    /// The icon with keyboard focus, if any. Its page is shown when focus moves.
    let focusedID: String?
    /// Edit mode. AppGridView owns it, so the header can show Done.
    @Binding var isEditing: Bool
    /// Opens an app.
    let onLaunch: (AppItem) -> Void
    /// Hides an app. The caller shows the Undo toast.
    let onHide: (AppItem) -> Void
    /// Moves an app by a number of slots in the layout. Keyboard and VoiceOver reorder.
    let onMove: (AppItem, Int) -> Void

    @Environment(LayoutStore.self) private var layoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The page the user is on. Clamped to the page count when drawn.
    @State private var page = 0
    /// Live horizontal drag, in points, while swiping between pages.
    @State private var swipeOffset: CGFloat = 0
    /// The press in progress, if any.
    @State private var press: Press?
    /// The icon being dragged in Edit mode, if any.
    @State private var drag: Drag?
    /// The order while an icon is dragged. Saved only when the drag ends.
    @State private var draft: [AppItem]?
    /// The icon under the pointer, if any. Drawn with the hover fill.
    @State private var hoveredID: String?
    /// Counts down the hold that turns a press into Edit mode.
    @State private var holdTask: Task<Void, Never>?
    /// Counts down the pause that flips the page at a window edge.
    @State private var edgeTask: Task<Void, Never>?
    /// The window edge a drag is resting on: -1 left, 1 right, 0 neither.
    @State private var edgeDirection = 0

    /// What a press has done so far.
    private struct Press {
        /// Where the press began, in grid space.
        var start: CGPoint
        /// The app under the press, if any.
        var hitID: String?
        /// True once the pointer has moved past the tap slop.
        var moved = false
        /// True once the hold has switched on Edit mode during this press.
        var enteredEdit = false
    }

    /// An icon being dragged.
    private struct Drag {
        var id: String
        /// From the pointer to the icon's center, fixed when the drag began.
        var grab: CGSize
        /// The icon's center in grid space, so it stays under the pointer when the page flips.
        var center: CGPoint
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

    /// Wraps a Inlet spring. Under Reduce Motion it becomes a short crossfade.
    private func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .inletFade : animation
    }

    /// Apps in grid order, with the saved layout applied. A drag shows its draft order instead.
    private var displayItems: [AppItem] {
        draft ?? visibleItems
    }

    /// Apps from the saved layout, in order. Until the folders change lands,
    /// every entry in the layout is an app.
    private var visibleItems: [AppItem] {
        let byID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return layoutStore.layout.entries.compactMap { entry -> AppItem? in
            guard case .app(let appID) = entry else { return nil }
            return byID[appID]
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
            let items = displayItems
            let pages = geo.pageCount(itemCount: items.count)
            let current = min(page, pages - 1)

            VStack(spacing: 0) {
                stage(items: items, geo: geo, height: stageHeight, current: current)
                pageDots(current: current, pages: pages)
                    .frame(height: GridMetrics.dotsHeight)
            }
        }
        // Leaving Edit mode cancels any drag still in progress.
        .onChange(of: isEditing) { _, editing in
            if !editing { cancelDrag() }
        }
    }

    // MARK: - Drawing

    /// The icons, placed by slot and shifted to show the current page.
    private func stage(items: [AppItem], geo: GridGeometry, height: CGFloat, current: Int) -> some View {
        let track = -CGFloat(current) * geo.pageWidth + swipeOffset
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, app in
                GridTile(
                    app: app,
                    isEditing: isEditing,
                    showsBadge: isEditing && app.isHideable,
                    isLifted: drag?.id == app.id,
                    isPressed: isPressed(app),
                    isKeyboardFocused: app.id == focusedID,
                    isHovered: drag == nil && hoveredID == app.id,
                    onOpen: { onLaunch(app) },
                    onHide: { if app.isHideable { onHide(app) } },
                    onMove: { onMove(app, $0) }
                )
                .frame(width: InletSize.gridCell.width, height: GridMetrics.cellHeight, alignment: .top)
                .position(tilePosition(for: app, index: index, geo: geo, track: track))
                // The dragged icon follows the pointer exactly, so it doesn't animate.
                .transaction { transaction in
                    if drag?.id == app.id { transaction.animation = nil }
                }
            }
        }
        .frame(width: geo.pageWidth, height: height, alignment: .topLeading)
        .offset(x: track)
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

    /// True while the press is on this icon and hasn't turned into a swipe or drag.
    private func isPressed(_ app: AppItem) -> Bool {
        guard drag == nil, let press else { return false }
        return press.hitID == app.id && !press.moved
    }

    /// Where an icon's center sits, in the stage's own coordinates.
    private func tilePosition(for app: AppItem, index: Int, geo: GridGeometry, track: CGFloat) -> CGPoint {
        if let drag, drag.id == app.id {
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

    // MARK: - Gestures

    private func pressGesture(geo: GridGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in changed(value, geo: geo) }
            .onEnded { value in ended(value, geo: geo) }
    }

    /// Every movement of the press. Decides between a hold, a swipe and a drag.
    private func changed(_ value: DragGesture.Value, geo: GridGeometry) {
        if press == nil {
            let hitID = item(at: value.startLocation, geo: geo)?.id
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
            swipeOffset = rubberBand(dx, geo: geo)
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
            let current = currentPage(geo)
            let last = geo.pageCount(itemCount: displayItems.count) - 1
            let width = geo.pageWidth
            let predicted = value.predictedEndTranslation.width
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
            return
        }

        // A tap. A press that just entered Edit mode is not a tap.
        if state.enteredEdit { return }

        if isEditing {
            guard let hitID = state.hitID, let app = displayItems.first(where: { $0.id == hitID }) else {
                // A tap on empty space leaves Edit mode.
                withAnimation(motion(.inletDismiss)) { isEditing = false }
                return
            }
            if app.isHideable, isOnBadge(state.start, id: app.id, geo: geo) {
                onHide(app)
            }
            return
        }

        if let hitID = state.hitID, let app = displayItems.first(where: { $0.id == hitID }) {
            onLaunch(app)
        }
    }

    // MARK: - Hit testing

    /// Horizontal offset of the whole stage: the current page, plus any live swipe.
    private func trackOffset(_ geo: GridGeometry) -> CGFloat {
        -CGFloat(currentPage(geo)) * geo.pageWidth + swipeOffset
    }

    /// The page on screen, clamped to the page count.
    private func currentPage(_ geo: GridGeometry) -> Int {
        min(page, geo.pageCount(itemCount: displayItems.count) - 1)
    }

    /// The app under a point on screen (window coordinates of the grid), if any.
    private func item(at point: CGPoint, geo: GridGeometry) -> AppItem? {
        let items = displayItems
        let stagePoint = CGPoint(x: point.x - trackOffset(geo), y: point.y)
        guard let index = geo.index(at: stagePoint), index < items.count else { return nil }
        return items[index]
    }

    /// True when a point on screen is on an app's minus badge.
    private func isOnBadge(_ point: CGPoint, id: String, geo: GridGeometry) -> Bool {
        guard let index = displayItems.firstIndex(where: { $0.id == id }) else { return false }
        let slot = geo.center(ofIndex: index)
        // The icon's top-left corner, where the badge sits. The icon is centered
        // in its cell and sits 10 pt below the cell's top edge (see GridTile).
        let badge = CGPoint(
            x: slot.x + trackOffset(geo) - InletSize.gridIcon / 2,
            y: slot.y - GridMetrics.cellHeight / 2 + InletSpace.s + InletSpace.xxs
        )
        return hypot(point.x - badge.x, point.y - badge.y) <= Self.badgeRadius
    }

    /// Tracks the icon under the pointer for the hover fill.
    private func updateHover(_ phase: HoverPhase, geo: GridGeometry) {
        switch phase {
        case .active(let point):
            let id = item(at: point, geo: geo)?.id
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

    /// Starts dragging an icon. The draft starts as the current order.
    private func beginDrag(id: String, start: CGPoint, geo: GridGeometry) {
        let items = displayItems
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

    /// Follows the pointer. Moves the icon to the nearest slot on the page,
    /// and flips the page if the pointer rests at a window edge.
    private func updateDrag(to location: CGPoint, geo: GridGeometry) {
        guard var active = drag, var order = draft else { return }
        active.center = CGPoint(x: location.x + active.grab.width, y: location.y + active.grab.height)

        // The icon's center in stage coordinates, where the slots are measured.
        let track = trackOffset(geo)
        let pointer = CGPoint(x: active.center.x - track, y: active.center.y)

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
            if nearest != from {
                let moving = order.remove(at: from)
                order.insert(moving, at: nearest)
                draft = order
            }
        }

        // Resting near a window edge turns the page after a short pause, then
        // keeps turning one page per pause while the pointer stays there.
        let direction = GridMetrics.edgeDirection(x: location.x, pageWidth: geo.pageWidth)
        let target = currentPage(geo) + direction
        let pages = geo.pageCount(itemCount: order.count)
        if direction != 0, target >= 0, target < pages {
            // A new edge starts a new pause. Staying on the same edge keeps the running one.
            if direction != edgeDirection || edgeTask == nil {
                scheduleEdgeFlip(direction: direction, geo: geo)
            }
        } else {
            cancelEdge()
        }

        drag = active
    }

    /// Starts the pause for `direction`. The task turns one page each time the
    /// pause ends, and stops as soon as the pointer leaves that edge or the drag ends.
    private func scheduleEdgeFlip(direction: Int, geo: GridGeometry) {
        edgeTask?.cancel()
        edgeDirection = direction
        edgeTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.edgeDwell)
                guard !Task.isCancelled, drag != nil, edgeDirection == direction else { return }
                let next = currentPage(geo) + direction
                guard next >= 0, next < geo.pageCount(itemCount: displayItems.count) else { return }
                withAnimation(motion(.inletSettle)) { page = next }
            }
        }
    }

    private func cancelEdge() {
        edgeTask?.cancel()
        edgeTask = nil
        edgeDirection = 0
    }

    /// Drops the dragged icon. Saves the new order once, then settles the icon into its slot.
    private func finishDrag() {
        cancelEdge()
        let appEntries = (draft ?? displayItems).map { GridEntry.app($0.id) }
        layoutStore.update { layout in
            // Folders aren't drawn on the paged grid, so they keep their slot.
            // App slots take the dragged order, and any apps left over go last.
            var next = 0
            var merged = layout.entries.compactMap { entry -> GridEntry? in
                guard case .app = entry else { return entry }
                guard next < appEntries.count else { return nil }
                defer { next += 1 }
                return appEntries[next]
            }
            merged += appEntries[next...]
            layout.entries = merged
        }
        withAnimation(motion(.inletPress)) {
            drag = nil
            draft = nil
        }
    }

    /// Ends a drag without saving. Used when Edit mode is left mid-drag.
    private func cancelDrag() {
        cancelEdge()
        drag = nil
        draft = nil
    }

    /// Shows the page that holds the focused icon, when keyboard focus moves to another page.
    private func revealPage(of id: String?, geo: GridGeometry) {
        guard let id, let index = displayItems.firstIndex(where: { $0.id == id }) else { return }
        let target = index / geo.perPage
        guard target != currentPage(geo) else { return }
        withAnimation(motion(.inletSettle)) { page = target }
    }

    /// Past the first or last page the swipe is pulled back, like a rubber band.
    private func rubberBand(_ raw: CGFloat, geo: GridGeometry) -> CGFloat {
        let current = currentPage(geo)
        let last = geo.pageCount(itemCount: displayItems.count) - 1
        let pastEnd = (current == 0 && raw > 0) || (current == last && raw < 0)
        return pastEnd ? raw * 0.3 : raw
    }
}
