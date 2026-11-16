//
//  AppIconCell.swift
//  Inlet
//
//  One app in the grid: its icon and name. Click to launch.
//

import SwiftUI

struct AppIconCell: View {
    let app: AppItem
    /// Called on click. The grid uses it to close the overlay and launch the app.
    let onLaunch: (AppItem) -> Void
    /// The best match while searching. Gets the top-hit lozenge; Return opens it.
    var isTopHit = false
    /// True when arrow keys have moved keyboard focus onto this icon.
    var isKeyboardFocused = false
    /// Where this cell starts and when its open animation begins.
    let placement: OpenPlacement
    /// True once the overlay is open.
    let isOpen: Bool

    /// `@State` is private memory that belongs to this one cell.
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            onLaunch(app)
        } label: {
            VStack(spacing: InletSpace.s) {
                Image(nsImage: IconCache.shared.icon(for: app))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: InletSize.gridIcon, height: InletSize.gridIcon)

                Text(app.name)
                    .font(InletFont.iconLabel)
                    .foregroundStyle(InletColor.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: InletSize.gridCell.width - InletSpace.l)
            }
            .padding(.vertical, InletSpace.s + InletSpace.xxs)
            .frame(width: InletSize.gridCell.width - InletSpace.s)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: InletRadius.row, style: .continuous)
                        .fill(isHovered ? InletColor.hover : Color.clear)
                    // The top-hit lozenge. It fades rather than slides,
                    // because each cell draws its own.
                    Color.clear
                        .inletLozenge(cornerRadius: InletRadius.row)
                        .opacity(isTopHit ? 1 : 0)
                }
            }
            // Keyboard focus ring (T3.5). Accent is a fill or control state, never text.
            .overlay {
                if isKeyboardFocused {
                    RoundedRectangle(cornerRadius: InletRadius.row, style: .continuous)
                        .strokeBorder(InletColor.accent, lineWidth: 2)
                }
            }
            .inletAnimation(.inletSnap, value: isHovered)
            .inletAnimation(.inletSnap, value: isTopHit)
            .inletAnimation(.inletSnap, value: isKeyboardFocused)
            // Make the whole cell clickable, not just the visible pixels.
            .contentShape(RoundedRectangle(cornerRadius: InletRadius.row, style: .continuous))
        }
        .buttonStyle(InletPressButtonStyle())
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
                : .spring(InletMotion.open).delay(placement.delay),
            value: isOpen
        )
    }
}

/// Press feedback from the spec: scale to 0.9 with `snap` on mouse down,
/// spring back with `press` on release. Under Reduce Motion nothing scales.
private struct InletPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InletPressedLabel(configuration: configuration)
    }
}

/// A view, not just a style, so it can read the Reduce Motion setting.
private struct InletPressedLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .inletAnimation(configuration.isPressed ? .inletSnap : .inletPress, value: configuration.isPressed)
    }
}
