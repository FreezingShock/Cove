//
//  GridTile.swift
//  Cove
//
//  One app on the paged grid: its icon and name, drawn the same way as the
//  search grid's AppIconCell. In Edit mode it wobbles, and apps that can be
//  hidden get a minus badge. The grid handles every touch, so this view has
//  no buttons of its own.
//

import SwiftUI

extension AppItem {
    /// Apple's own apps can't be hidden. Everything else can.
    var isHideable: Bool {
        !(bundleIdentifier?.hasPrefix("com.apple.") ?? false)
    }
}

struct GridTile: View {
    let app: AppItem
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
    /// Opens the app. Used by VoiceOver only: the grid handles mouse taps.
    let onOpen: () -> Void
    /// Hides the app. Used by VoiceOver only: the grid handles the badge tap.
    let onHide: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Swings between -1.3 and 1.3 degrees while the grid wobbles.
    @State private var wobble = false

    var body: some View {
        VStack(spacing: CoveSpace.s) {
            ZStack(alignment: .topLeading) {
                Image(nsImage: IconCache.shared.icon(for: app))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: CoveSize.gridIcon, height: CoveSize.gridIcon)

                if showsBadge {
                    // Centered on the icon's top-left corner. The fill and glyph
                    // swap with the appearance, so the badge always contrasts.
                    Circle()
                        .fill(CoveColor.text)
                        .overlay(
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(CoveColor.base)
                        )
                        .frame(width: 24, height: 24)
                        .shadow(color: CoveColor.gShadow, radius: 3, y: 1)
                        .offset(x: -12, y: -12)
                }
            }
            .frame(width: CoveSize.gridIcon, height: CoveSize.gridIcon)

            Text(app.name)
                .font(CoveFont.iconLabel)
                .foregroundStyle(CoveColor.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: CoveSize.gridCell.width - CoveSpace.l)
        }
        .padding(.top, CoveSpace.s + CoveSpace.xxs)
        .frame(width: CoveSize.gridCell.width - CoveSpace.s, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous)
                .fill(isHovered ? CoveColor.hover : Color.clear)
        }
        .overlay {
            // Keyboard focus ring (T3.5). Accent is a fill or control state, never text.
            if isKeyboardFocused {
                RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous)
                    .strokeBorder(CoveColor.accent, lineWidth: 2)
            }
        }
        .scaleEffect(scale)
        .shadow(color: CoveColor.gShadow.opacity(isLifted ? 1 : 0), radius: 12, y: 8)
        .rotationEffect(.degrees(wobbleAngle))
        .coveAnimation(.covePress, value: isPressed)
        .coveAnimation(.coveSnap, value: isHovered)
        .coveAnimation(.coveSnap, value: isKeyboardFocused)
        .onChange(of: isEditing, initial: true) { _, editing in
            updateWobble(editing)
        }
        .contentShape(RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous))
        // Mouse input is handled by the grid. VoiceOver gets its own actions here.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { onOpen() }
        .accessibilityAction(named: Text("Hide")) { onHide() }
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
        withAnimation(.easeInOut(duration: 0.19).repeatForever(autoreverses: true)) {
            wobble = true
        }
    }
}
