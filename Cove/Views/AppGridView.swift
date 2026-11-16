//
//  AppGridView.swift
//  Cove
//
//  The main window: a header, then every installed app in a 7-column grid.
//

import AppKit
import SwiftUI

struct AppGridView: View {
    /// The shared app list, provided by CoveApp via `.environment(...)`.
    @Environment(AppLibrary.self) private var library
    /// Read from the system so Increase Contrast applies to secondary text.
    @Environment(\.colorSchemeContrast) private var contrast

    /// Seven fixed-width columns, per the spec.
    private let columns = Array(
        repeating: GridItem(.fixed(CoveSize.gridCell.width), spacing: 0),
        count: CoveSize.gridColumns
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(minWidth: CoveSize.gridWindowWidth, minHeight: 480)
        .background(CoveColor.base)
        // First scan when the window appears.
        .task { library.reload() }
        // Rescan whenever you switch back to Cove, so apps installed or
        // deleted in the meantime show up without restarting.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            library.reload()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Cove")
                .font(CoveFont.wordmark)
                .tracking(CoveTracking.display)
                .foregroundStyle(CoveColor.text)

            Spacer()

            if library.hasScanned {
                Text("\(library.apps.count) apps")
                    .font(CoveFont.section)
                    .foregroundStyle(CoveText.secondary(contrast))
            }
        }
        .padding(.horizontal, CoveSize.gridSidePadding)
        .padding(.top, CoveSpace.xxl)
        .padding(.bottom, CoveSpace.xl)
    }

    @ViewBuilder
    private var content: some View {
        if !library.hasScanned {
            // Before the first scan finishes.
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if library.apps.isEmpty {
            Text("No apps found.")
                .font(CoveFont.subhead)
                .foregroundStyle(CoveText.secondary(contrast))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                // `LazyVGrid` only builds the cells that are on screen,
                // so icons load as you scroll instead of all at once.
                LazyVGrid(columns: columns, spacing: CoveSize.gridRowGap) {
                    ForEach(library.apps) { app in
                        AppIconCell(app: app)
                    }
                }
                .padding(.horizontal, CoveSize.gridSidePadding)
                .padding(.bottom, CoveSpace.xxxl)
            }
        }
    }
}
