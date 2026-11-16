//
//  AppIconCell.swift
//  Cove
//
//  One app in the grid: its icon and name. Click to launch.
//

import SwiftUI

struct AppIconCell: View {
    let app: AppItem
    /// Where this cell starts and when it begins its open animation.
    let placement: OpenPlacement
    /// True once the overlay is open.
    let isOpen: Bool

    /// `@State` is private memory that belongs to this one cell.
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            AppLauncher.launch(app)
        } label: {
            VStack(spacing: CoveSpace.s) {
                Image(nsImage: IconCache.shared.icon(for: app))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: CoveSize.gridIcon, height: CoveSize.gridIcon)

                Text(app.name)
                    .font(CoveFont.iconLabel)
                    .foregroundStyle(CoveColor.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: CoveSize.gridCell.width - CoveSpace.l)
            }
            .padding(.vertical, CoveSpace.s + CoveSpace.xxs)
            .frame(width: CoveSize.gridCell.width - CoveSpace.s)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous)
                    .fill(isHovered ? CoveColor.hover : Color.clear)
            )
            .coveAnimation(.coveSnap, value: isHovered)
            // Make the whole cell clickable, not just the visible pixels.
            .contentShape(RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous))
        }
        .buttonStyle(CovePressButtonStyle())
        .onHover { isHovered = $0 }
        .help(app.name) // tooltip with the full name if it's cut off
        .accessibilityLabel("Open \(app.name)")
        // Open choreography (theme spec, "Grid opens"). Before opening, each
        // cell sits 22% toward the center at 0.78 scale. Opening springs it
        // into place with `open`, delayed by distance so the grid ripples.
        // Reduce Motion: no movement, just a 0.2 s crossfade.
        .scaleEffect(isOpen || reduceMotion ? 1 : 0.78)
        .offset(isOpen || reduceMotion ? .zero : placement.offset)
        .opacity(reduceMotion && !isOpen ? 0 : 1)
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.2)
                : .spring(CoveMotion.open).delay(placement.delay),
            value: isOpen
        )
    }
}

/// Press feedback from the spec: scale to 0.9 with `snap` on mouse down,
/// spring back with `press` on release. Under Reduce Motion nothing scales.
private struct CovePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CovePressedLabel(configuration: configuration)
    }
}

/// A view, not just a style, so it can read the Reduce Motion setting.
private struct CovePressedLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .coveAnimation(configuration.isPressed ? .coveSnap : .covePress, value: configuration.isPressed)
    }
}
