//
//  AppGridView.swift
//  Cove
//
//  The main window: a header, then the paged grid of installed apps.
//  Edit mode, the Hidden list and the Undo toast live here too.
//

import AppKit
import SwiftUI

struct AppGridView: View {
    /// The shared app list, provided by CoveApp via `.environment(...)`.
    @Environment(AppLibrary.self) private var library
    /// The saved layout (order, folders, hidden apps), also from CoveApp.
    @Environment(LayoutStore.self) private var layoutStore

    /// Edit mode: icons wobble, drag to reorder, minus badges hide apps.
    @State private var isEditing = false
    /// Whether the Hidden apps panel is open.
    @State private var showsHidden = false
    /// The last hidden app, for the Undo toast.
    @State private var undo: HideUndo?
    /// Clears the Undo toast after a few seconds.
    @State private var undoTimer: Task<Void, Never>?

    /// What the Undo toast needs to know.
    private struct HideUndo: Equatable {
        let appID: String
        let name: String
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(minWidth: Theme.windowWidth, minHeight: 480)
        .background(Theme.base)
        .overlay(alignment: .topTrailing) { hiddenPanel }
        .overlay(alignment: .bottom) { undoToast }
        .background(exitEditShortcut)
        // First scan when the window appears.
        .task { library.reload() }
        // Rescan whenever you switch back to Cove, so apps installed or
        // deleted in the meantime show up without restarting.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            library.reload()
        }
        // Keep the saved layout in step with what is installed.
        .onChange(of: library.apps) { _, apps in reconcileLayout(apps) }
        .onChange(of: library.hasScanned) { _, _ in reconcileLayout(library.apps) }
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

            if !layoutStore.layout.hidden.isEmpty {
                headerButton("Hidden \(layoutStore.layout.hidden.count)") {
                    withAnimation(.spring(duration: 0.5, bounce: 0.32)) { showsHidden.toggle() }
                }
            }

            if library.hasScanned, !library.apps.isEmpty {
                headerButton(isEditing ? "Done" : "Edit") {
                    withAnimation(.spring(duration: 0.46, bounce: 0.24)) { isEditing.toggle() }
                }
            }
        }
        .padding(.horizontal, Theme.sidePadding)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    /// A small capsule button for the header.
    private func headerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.hover))
        }
        .buttonStyle(.plain)
    }

    /// Escape leaves Edit mode. It is enabled only while editing, so Escape
    /// does nothing special otherwise.
    private var exitEditShortcut: some View {
        Button("Done editing") {
            withAnimation(.spring(duration: 0.26, bounce: 0)) { isEditing = false }
        }
        .keyboardShortcut(.cancelAction)
        .opacity(0)
        .frame(width: 0, height: 0)
        .disabled(!isEditing)
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
            EditableGridView(
                apps: library.apps,
                isEditing: $isEditing,
                onLaunch: { AppLauncher.launch($0) },
                onHide: { hide($0) }
            )
        }
    }

    /// The Hidden apps list, opened from the header.
    @ViewBuilder
    private var hiddenPanel: some View {
        if showsHidden, !layoutStore.layout.hidden.isEmpty {
            HiddenAppsPanel(rows: hiddenRows, onRestore: restore)
                .padding(.top, 64)
                .padding(.trailing, Theme.sidePadding)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
        }
    }

    /// The Undo toast, shown for a few seconds after an app is hidden.
    @ViewBuilder
    private var undoToast: some View {
        if let undo {
            UndoToast(message: "Hidden \(undo.name)") { restore(undo.appID) }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var hiddenRows: [HiddenAppsPanel.Row] {
        layoutStore.layout.hidden.map { (hidden: HiddenApp) -> HiddenAppsPanel.Row in
            let name = library.apps.first(where: { $0.id == hidden.appID })?.name
                ?? URL(fileURLWithPath: hidden.appID).deletingPathExtension().lastPathComponent
            return HiddenAppsPanel.Row(id: hidden.appID, name: name)
        }
    }

    // MARK: - Actions

    /// Hides an app and shows the Undo toast.
    private func hide(_ app: AppItem) {
        layoutStore.update { $0.hideApp(app.id) }
        undoTimer?.cancel()
        withAnimation(.spring(duration: 0.5, bounce: 0.32)) {
            undo = HideUndo(appID: app.id, name: app.name)
        }
        undoTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.2))
            guard !Task.isCancelled else { return }
            dismissUndo()
        }
    }

    /// Puts a hidden app back where it was.
    private func restore(_ appID: String) {
        layoutStore.update { $0.restoreApp(appID) }
        if undo?.appID == appID { dismissUndo() }
    }

    private func dismissUndo() {
        undoTimer?.cancel()
        undoTimer = nil
        withAnimation(.spring(duration: 0.26, bounce: 0)) { undo = nil }
    }

    /// Makes the saved layout match the installed apps.
    /// Skipped before the first scan, and for an empty scan, so a failed
    /// scan can't wipe the saved layout.
    private func reconcileLayout(_ apps: [AppItem]) {
        guard library.hasScanned, !apps.isEmpty else { return }
        layoutStore.reconcile(with: apps)
    }
}
