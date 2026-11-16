//
//  GridTile.swift
//  Cove
//
//  One app on the grid: its icon and name. In Edit mode it wobbles, and
//  apps that can be hidden get a minus badge. The grid handles every touch,
//  so this view has no buttons of its own.
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
    let onOpen: () -> Void
    let onHide: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Swings between -1.3 and 1.3 degrees while the grid wobbles.
    @State private var wobble = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                Image(nsImage: IconCache.shared.icon(for: app))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Theme.iconSize, height: Theme.iconSize)

                if showsBadge {
                    // Centered on the icon's top-left corner.
                    Circle()
                        .fill(Color.white)
                        .overlay(
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.black)
                        )
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .offset(x: -12, y: -12)
                }
            }
            .frame(width: Theme.iconSize, height: Theme.iconSize)

            Text(app.name)
                .font(.system(size: Theme.labelSize, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: Theme.cellWidth - 16)
        }
        .padding(.top, 4)
        .scaleEffect(isLifted ? 1.08 : 1)
        .shadow(color: .black.opacity(isLifted ? 0.35 : 0), radius: 12, y: 8)
        .rotationEffect(.degrees(wobbleAngle))
        .animation(.spring(duration: 0.26, bounce: 0.42), value: isLifted)
        .onChange(of: isEditing, initial: true) { _, editing in
            updateWobble(editing)
        }
        .contentShape(Rectangle())
        // Mouse input is handled by the grid. VoiceOver gets its own actions here.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { onOpen() }
        .accessibilityAction(named: Text("Hide")) { onHide() }
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
