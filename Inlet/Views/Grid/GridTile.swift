//
//  GridTile.swift
//  Inlet
//
//  One entry on the paged grid: an app, or a folder of up to nine apps. It is
//  drawn the same way as the search grid's AppIconCell. In Edit mode it
//  wobbles, and apps that can be hidden get a minus badge. The grid handles
//  every touch, so this view has no buttons of its own.
//

import SwiftUI

extension AppItem {
    /// Apple's own apps can't be hidden. Everything else can.
    var isHideable: Bool {
        !(bundleIdentifier?.hasPrefix("com.apple.") ?? false)
    }
}

/// A folder's icon: up to nine app icons in a 3 x 3 grid on a glass tile.
struct FolderIcon: View {
    let apps: [AppItem]

    /// Gap between the mini icons, and the inset from the tile's edge.
    private static let gap: CGFloat = 3
    private static let inset: CGFloat = 6

    var body: some View {
        let mini = (InletSize.gridIcon - 2 * Self.inset - 2 * Self.gap) / 3
        let shape = RoundedRectangle(cornerRadius: InletRadius.icon(InletSize.gridIcon), style: .continuous)

        VStack(spacing: Self.gap) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: Self.gap) {
                    ForEach(0..<3, id: \.self) { column in
                        let index = row * 3 + column
                        if index < apps.count {
                            Image(nsImage: IconCache.shared.icon(for: apps[index]))
                                .resizable()
                                .interpolation(.high)
                                .frame(width: mini, height: mini)
                        } else {
                            Color.clear.frame(width: mini, height: mini)
                        }
                    }
                }
            }
        }
        .padding(Self.inset)
        .frame(width: InletSize.gridIcon, height: InletSize.gridIcon)
        .background(shape.fill(InletColor.gFill))
        .overlay(shape.strokeBorder(InletColor.gEdge, lineWidth: 1))
        .shadow(color: InletColor.gShadow, radius: 6, y: 3)
    }
}

struct GridTile: View {
    /// The name under the icon: the app's name, or the folder's name.
    let title: String
    /// The apps in the icon. One for an app, up to nine for a folder.
    let apps: [AppItem]
    /// True for a folder. Folders draw the 3 x 3 icon and can't be hidden.
    let isFolder: Bool
    let isEditing: Bool
    /// True in Edit mode for apps that can be hidden.
    let showsBadge: Bool
    /// True while this icon is being dragged. It rises a little.
    let isLifted: Bool
    /// True while the mouse is held down on this icon, before a drag starts.
    let isPressed: Bool
    /// True when arrow keys have moved keyboard focus onto this icon.
    let isKeyboardFocused: Bool
    /// The pointer is over the tile. Shown as a hover fill, as in search.
    let isHovered: Bool
    /// A dragged app is over this icon and would merge into it.
    let isMergeTarget: Bool
    /// Opens the app, or opens the folder. Used by VoiceOver only.
    let onOpen: () -> Void
    /// Hides the app. Used by VoiceOver only: the grid handles the badge tap.
    let onHide: () -> Void
    /// Moves the app by a slot offset in the layout. Used by VoiceOver in Edit mode.
    let onMove: (Int) -> Void
    /// Where the icon starts before the grid opens, and when its spring begins.
    let placement: OpenPlacement
    /// True once the overlay is open. Drives the open choreography.
    let isOpen: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Swings between -1.3 and 1.3 degrees while the grid wobbles.
    @State private var wobble = false

    var body: some View {
        VStack(spacing: InletSpace.s) {
            ZStack(alignment: .topLeading) {
                icon
                    .frame(width: InletSize.gridIcon, height: InletSize.gridIcon)
                    .scaleEffect(isMergeTarget ? 1.12 : 1)
                    .overlay {
                        // The merge target ring, as in the folders mockup.
                        if isMergeTarget {
                            RoundedRectangle(cornerRadius: InletRadius.icon(InletSize.gridIcon), style: .continuous)
                                .strokeBorder(InletColor.accent, lineWidth: 3)
                                .padding(-4)
                        }
                    }

                if showsBadge {
                    // Centered on the icon's top-left corner. The fill and glyph
                    // swap with the appearance, so the badge always contrasts.
                    Circle()
                        .fill(InletColor.text)
                        .overlay(
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(InletColor.base)
                        )
                        .frame(width: 24, height: 24)
                        .shadow(color: InletColor.gShadow, radius: 3, y: 1)
                        .offset(x: -12, y: -12)
                }
            }
            .frame(width: InletSize.gridIcon, height: InletSize.gridIcon)

            if ThemeRuntime.showsLabels {
                Text(title)
                    .font(ThemeRuntime.labelFont)
                    .foregroundStyle(InletColor.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: InletSize.gridCell.width - InletSpace.l)
            }
        }
        .padding(.top, InletSpace.s + InletSpace.xxs)
        .frame(width: InletSize.gridCell.width - InletSpace.s, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: InletRadius.row, style: .continuous)
                .fill(isHovered ? InletColor.hover : Color.clear)
        }
        .overlay {
            // Keyboard focus ring (T3.5). Accent is a fill or control state, never text.
            if isKeyboardFocused {
                RoundedRectangle(cornerRadius: InletRadius.row, style: .continuous)
                    .strokeBorder(InletColor.accent, lineWidth: 2)
            }
        }
        .scaleEffect(scale)
        // Open choreography, the same as the search grid: each icon starts 22%
        // toward the center at 0.78 scale, then springs into place in a ripple.
        .scaleEffect(isOpen || reduceMotion ? 1 : 0.78)
        .offset(isOpen || reduceMotion ? .zero : placement.offset)
        .opacity(reduceMotion && !isOpen ? 0 : 1)
        .animation(
            reduceMotion
                ? .inletFade
                : .spring(InletMotion.open).delay(placement.delay),
            value: isOpen
        )
        .shadow(color: InletColor.gShadow.opacity(isLifted ? 1 : 0), radius: 12, y: 8)
        .rotationEffect(.degrees(wobbleAngle))
        .inletAnimation(.inletPress, value: isPressed)
        .inletAnimation(.inletSnap, value: isHovered)
        .inletAnimation(.inletSnap, value: isKeyboardFocused)
        .inletAnimation(.inletSnap, value: isMergeTarget)
        .onChange(of: isEditing, initial: true) { _, editing in
            updateWobble(editing)
        }
        .contentShape(RoundedRectangle(cornerRadius: InletRadius.row, style: .continuous))
        // Mouse input is handled by the grid. VoiceOver gets its own actions here.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isFolder ? "\(apps.count) apps" : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { onOpen() }
        .accessibilityAction(named: Text("Hide")) { onHide() }
        .accessibilityAction(named: Text("Move earlier")) { onMove(-1) }
        .accessibilityAction(named: Text("Move later")) { onMove(1) }
    }

    @ViewBuilder
    private var icon: some View {
        if isFolder {
            FolderIcon(apps: apps)
        } else if let app = apps.first {
            Image(nsImage: IconCache.shared.icon(for: app))
                .resizable()
                .interpolation(.high)
        }
    }

    /// Size for press and lift. Under Reduce Motion nothing scales.
    private var scale: CGFloat {
        if isLifted { return reduceMotion ? 1 : 1.08 }
        if isPressed { return reduceMotion ? 1 : 0.94 }
        return 1
    }

    /// The angle for the current wobble phase. Still under Reduce Motion.
    private var wobbleAngle: Double {
        guard isEditing, !reduceMotion else { return 0 }
        return wobble ? 1.3 : -1.3
    }

    /// Starts the wobble when Edit mode begins and stops it when it ends.
    private func updateWobble(_ editing: Bool) {
        guard editing, !reduceMotion else {
            var stop = Transaction()
            stop.disablesAnimations = true
            withTransaction(stop) { wobble = false }
            return
        }
        withAnimation(.easeInOut(duration: InletMotion.jiggle).repeatForever(autoreverses: true)) {
            wobble = true
        }
    }
}

/// The liquid pull between a dragged icon and the icon it will merge into.
/// Two blobs joined by a neck, softened with a blur. It is drawn in the
/// window's own coordinates and never takes touches.
struct LiquidPull: View {
    /// Centers of the two icons, in the stage's coordinates.
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        Canvas { context, _ in
            let radius = InletSize.gridIcon * 0.5
            let dx = to.x - from.x
            let dy = to.y - from.y
            let length = hypot(dx, dy)
            guard length > 0.5 else { return }

            // Unit vector across the pull, used to place the neck's edges.
            let perp = CGPoint(x: -dy / length, y: dx / length)
            let neck = radius * 0.42
            let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)

            var bridge = Path()
            bridge.move(to: CGPoint(x: from.x + perp.x * radius, y: from.y + perp.y * radius))
            bridge.addQuadCurve(
                to: CGPoint(x: to.x + perp.x * radius, y: to.y + perp.y * radius),
                control: CGPoint(x: mid.x + perp.x * neck, y: mid.y + perp.y * neck)
            )
            bridge.addLine(to: CGPoint(x: to.x - perp.x * radius, y: to.y - perp.y * radius))
            bridge.addQuadCurve(
                to: CGPoint(x: from.x - perp.x * radius, y: from.y - perp.y * radius),
                control: CGPoint(x: mid.x - perp.x * neck, y: mid.y - perp.y * neck)
            )
            bridge.closeSubpath()

            let fill = GraphicsContext.Shading.color(InletColor.accent.opacity(0.4))
            context.fill(bridge, with: fill)
            context.fill(
                Path(ellipseIn: CGRect(x: from.x - radius, y: from.y - radius, width: radius * 2, height: radius * 2)),
                with: fill
            )
            context.fill(
                Path(ellipseIn: CGRect(x: to.x - radius, y: to.y - radius, width: radius * 2, height: radius * 2)),
                with: fill
            )
        }
        .blur(radius: 5)
        .allowsHitTesting(false)
    }
}
