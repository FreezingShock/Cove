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

    /// Seven fixed-width columns, per the design system.
    private let columns = Array(
        repeating: GridItem(.fixed(Theme.cellWidth), spacing: 0),
        count: Theme.columns
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(minWidth: Theme.windowWidth, minHeight: 480)
        .background(Theme.base)
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
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)

            Spacer()

            if library.hasScanned {
                Text("\(library.apps.count) apps")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Theme.sidePadding)
        .padding(.top, 24)
        .padding(.bottom, 20)
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
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                // `LazyVGrid` only builds the cells that are on screen,
                // so icons load as you scroll instead of all at once.
                LazyVGrid(columns: columns, spacing: Theme.rowSpacing) {
                    ForEach(library.apps) { app in
                        AppIconCell(app: app)
                    }
                }
                .padding(.horizontal, Theme.sidePadding)
                .padding(.bottom, 40)
            }
        }
    }
}
