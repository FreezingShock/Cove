//
//  AppIconCell.swift
//  Cove
//
//  One app in the grid: its icon and name. Click to launch.
//

import SwiftUI

struct AppIconCell: View {
    let app: AppItem

    /// `@State` is private memory that belongs to this one cell.
    @State private var isHovered = false

    var body: some View {
        Button {
            AppLauncher.launch(app)
        } label: {
            VStack(spacing: 8) {
                Image(nsImage: IconCache.shared.icon(for: app))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Theme.iconSize, height: Theme.iconSize)

                Text(app.name)
                    .font(.system(size: Theme.labelSize, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: Theme.cellWidth - 16)
            }
            .padding(.vertical, 10)
            .frame(width: Theme.cellWidth - 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.cellCornerRadius, style: .continuous)
                    .fill(isHovered ? Theme.hover : Color.clear)
            )
            // Make the whole cell clickable, not just the visible pixels.
            .contentShape(RoundedRectangle(cornerRadius: Theme.cellCornerRadius, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .onHover { isHovered = $0 }
        .help(app.name) // tooltip with the full name if it's cut off
        .accessibilityLabel("Open \(app.name)")
    }
}

/// Shrinks the cell slightly while the mouse button is held down,
/// so a click feels like it registered.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
