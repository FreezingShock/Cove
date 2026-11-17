//
//  ZoneCanvas.swift
//  Inlet
//
//  The band of zones above the paged grid. Each zone is a tile at its grid
//  position and size, holding the apps of the groups it was given.
//

import SwiftUI

struct ZoneCanvas: View {
    /// Zones already fitted to the grid's columns.
    let zones: [GridZone]
    /// The apps each zone shows, from `ZoneLayout.contents`.
    let contents: [String: [AppItem]]
    /// Columns in the grid. Sets the band's width, so it lines up with the icons below.
    let columns: Int
    /// True in the grid's Edit mode, when each zone shows its Edit button.
    let isEditing: Bool
    let onLaunch: (AppItem) -> Void
    let onEdit: (GridZone) -> Void

    /// Same row pitch as the paged grid, so zones and icons share rows.
    private var rowPitch: CGFloat { InletSize.gridCell.height + InletSize.gridRowGap }

    private var bandHeight: CGFloat {
        let rows = CGFloat(ZoneLayout.bandRows(zones))
        return max(0, rows * rowPitch - InletSize.gridRowGap)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(zones) { zone in
                ZoneTile(
                    zone: zone,
                    apps: contents[zone.id] ?? [],
                    isEditing: isEditing,
                    onLaunch: onLaunch,
                    onEdit: { onEdit(zone) }
                )
                .frame(
                    width: CGFloat(zone.width) * InletSize.gridCell.width,
                    height: CGFloat(zone.height) * rowPitch - InletSize.gridRowGap
                )
                .offset(
                    x: CGFloat(zone.column) * InletSize.gridCell.width,
                    y: CGFloat(zone.row) * rowPitch
                )
            }
        }
        .frame(width: CGFloat(columns) * InletSize.gridCell.width, height: bandHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity)
    }
}

/// One zone: its name, then its apps in a small grid that scrolls when full.
private struct ZoneTile: View {
    let zone: GridZone
    let apps: [AppItem]
    let isEditing: Bool
    let onLaunch: (AppItem) -> Void
    let onEdit: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: InletSpace.s) {
            HStack(spacing: InletSpace.s) {
                Text(zone.name)
                    .font(InletFont.section)
                    .foregroundStyle(InletColor.text)
                    .lineLimit(1)
                Text("\(apps.count)")
                    .font(InletFont.caption)
                    .foregroundStyle(InletText.tertiary(contrast))
                Spacer(minLength: InletSpace.s)
                if isEditing {
                    Button("Edit Zone", action: onEdit)
                        .font(InletFont.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(InletColor.text)
                }
            }

            if apps.isEmpty {
                Text("No apps yet. Apps from the groups this zone holds appear here.")
                    .font(InletFont.caption)
                    .foregroundStyle(InletText.secondary(contrast))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            AppIconCell(
                                app: app,
                                onLaunch: onLaunch,
                                placement: OpenPlacement.forCell(at: index, total: apps.count),
                                isOpen: true
                            )
                        }
                    }
                }
            }
        }
        .padding(InletSpace.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
                .fill(InletColor.hover)
        )
        .overlay(
            RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
                .strokeBorder(InletText.hairline(contrast), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(zone.name))
    }

    /// Flexible columns share the zone's width, so icons stay inside its edges.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 0), count: zone.width)
    }
}
