//
//  QuickPanelView.swift
//  Cove
//
//  The Dock quick panel: recent apps in a 4 x 2 grid, recent files,
//  and a Show All Apps button. 372 pt wide, on the same glass as the grid.
//

import AppKit
import SwiftUI

/// What the quick panel shows, and the actions it can take. The controller
/// owns one of these and fills it each time the panel opens.
@MainActor
@Observable
final class QuickPanelModel {
    /// Flips to true to play the rise and back to false for the dismiss.
    var isPresented = false
    var apps: [AppItem] = []
    var files: [RecentFile] = []

    // Closures are not observed, so SwiftUI doesn't track them.
    @ObservationIgnored var onLaunchApp: (AppItem) -> Void = { _ in }
    @ObservationIgnored var onOpenFile: (RecentFile) -> Void = { _ in }
    @ObservationIgnored var onShowAll: () -> Void = {}
}

struct QuickPanelView: View {
    let model: QuickPanelModel

    /// Read from the system, so Reduce Motion skips the drop-from-Dock transform.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Read from the system so Increase Contrast applies to secondary text.
    @Environment(\.colorSchemeContrast) private var contrast

    /// Four columns: 4 x 2 recent apps, per the spec.
    private let tileColumns = Array(repeating: GridItem(.flexible(), spacing: CoveSpace.s), count: 4)

    /// True once the panel has finished rising. Reduce Motion always counts as
    /// finished, because the window fades instead of moving.
    private var entered: Bool { model.isPresented || reduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: CoveSpace.l) {
            appsSection
            if !model.files.isEmpty {
                filesSection
            }
            showAllButton
        }
        .padding(CoveSpace.panelPad)
        .frame(width: CoveSize.quickPanelWidth)
        .covePanelGlass(cornerRadius: CoveRadius.panel)
        // The rise: starts small, low and blurred, so it looks like it forms
        // at the Dock icon. Anchored at the bottom so it grows upward.
        .scaleEffect(x: entered ? 1 : 0.32, y: entered ? 1 : 0.18, anchor: .bottom)
        .offset(y: entered ? 0 : 60)
        .blur(radius: entered ? 0 : 10)
    }

    // MARK: - Recent apps

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: CoveSpace.s) {
            sectionLabel("Recent apps")
            if model.apps.isEmpty {
                Text("Apps you open with Cove show up here.")
                    .font(CoveFont.caption)
                    .foregroundStyle(CoveText.secondary(contrast))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, CoveSpace.s)
            } else {
                LazyVGrid(columns: tileColumns, spacing: CoveSpace.s) {
                    ForEach(model.apps) { app in
                        QuickAppTile(app: app) {
                            model.onLaunchApp(app)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent files

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: CoveSpace.xs) {
            sectionLabel("Recent files")
            ForEach(model.files) { file in
                Button {
                    model.onOpenFile(file)
                } label: {
                    HStack(spacing: CoveSpace.m) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                            .resizable()
                            .interpolation(.high)
                            .frame(width: CoveSize.rowIcon, height: CoveSize.rowIcon)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(file.name)
                                .font(CoveFont.subhead)
                                .foregroundStyle(CoveColor.text)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(file.url.deletingLastPathComponent().lastPathComponent)
                                .font(CoveFont.caption)
                                .foregroundStyle(CoveText.secondary(contrast))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, CoveSpace.s)
                    .padding(.vertical, CoveSpace.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: CoveRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(file.name)")
            }
        }
    }

    // MARK: - Show All Apps

    /// Accent is a fill, never text, so the label is the accent's ink color.
    private var showAllButton: some View {
        Button(action: model.onShowAll) {
            Text("Show All Apps")
                .font(CoveFont.headline)
                .foregroundStyle(CoveColor.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.md, style: .continuous)
                        .fill(CoveColor.accent)
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the full grid of apps")
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(CoveFont.label)
            .textCase(.uppercase)
            .tracking(CoveTracking.label)
            .foregroundStyle(CoveText.secondary(contrast))
    }
}

/// One recent app: icon over name, with a soft hover highlight.
private struct QuickAppTile: View {
    let app: AppItem
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: CoveSpace.xs) {
                Image(nsImage: IconCache.shared.icon(for: app))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: CoveSize.quickIcon, height: CoveSize.quickIcon)
                Text(app.name)
                    .font(CoveFont.iconLabel)
                    .foregroundStyle(CoveColor.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, CoveSpace.xs)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous)
                    .fill(isHovered ? CoveColor.hover : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous))
            .coveAnimation(.coveSnap, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(app.name)
        .accessibilityLabel("Open \(app.name)")
    }
}
