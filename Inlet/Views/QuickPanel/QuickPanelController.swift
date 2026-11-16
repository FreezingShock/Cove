//
//  QuickPanelController.swift
//  Inlet
//
//  Owns the quick panel window. It is a borderless floating panel, built once
//  and then shown and hidden. It rises at the bottom center of the screen the
//  cursor is on, where the Dock normally sits.
//

import AppKit
import SwiftUI

/// A borderless panel that can still take keyboard focus, so Escape works.
@MainActor
final class QuickPanel: NSPanel {
    /// Called on Escape.
    var onCancel: (() -> Void)?

    // Borderless panels can't become key by default. Ours must, for Escape.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class QuickPanelController {
    static let shared = QuickPanelController()

    /// Set by the app delegate: opens the full grid.
    var onShowAll: (() -> Void)?

    private let model = QuickPanelModel()
    private var panel: QuickPanel?

    /// When the panel last closed because it lost focus. A Dock click while the
    /// panel is open can close it first and then send the reopen. This stops
    /// that second step from reopening the panel.
    private var lastFocusLoss: Date?

    private init() {
        model.onLaunchApp = { [weak self] app in
            self?.dismiss()
            AppLauncher.launch(app)
        }
        model.onOpenFile = { [weak self] file in
            self?.dismiss()
            NSWorkspace.shared.open(file.url)
        }
        model.onShowAll = { [weak self] in
            self?.dismiss()
            self?.onShowAll?()
        }
    }

    private var isShowing: Bool {
        model.isPresented
    }

    /// Dock click: open when closed, close when open.
    func toggle() {
        if isShowing {
            dismiss()
            return
        }
        if let lastFocusLoss, Date().timeIntervalSince(lastFocusLoss) < 0.3 {
            // This click is the one that just closed the panel. Do nothing.
            self.lastFocusLoss = nil
            return
        }
        show()
    }

    func show() {
        let panel = self.panel ?? makePanel()
        refreshContents()
        place(panel)

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            // Reduce Motion: no movement, just a short fade.
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            model.isPresented = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().alphaValue = 1
            }
            return
        }

        panel.alphaValue = 1
        model.isPresented = false
        panel.makeKeyAndOrderFront(nil)
        // Draw the starting state first, so the rise has something to animate from.
        panel.displayIfNeeded()
        Task { @MainActor in
            withAnimation(.inletRise) {
                self.model.isPresented = true
            }
        }
    }

    /// Plays the dismiss, then hides the window. Does nothing if already hidden.
    func dismiss() {
        guard let panel, isShowing else { return }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            model.isPresented = false
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, !self.model.isPresented else { return }
                    panel.orderOut(nil)
                    panel.alphaValue = 1
                }
            })
            return
        }

        withAnimation(.inletDismiss) {
            model.isPresented = false
        }
        // Hide the window once the dismiss spring is done (about 0.26 s). If the
        // panel was opened again in the meantime, leave it visible.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !self.model.isPresented else { return }
            self.panel?.orderOut(nil)
        }
    }

    // MARK: - Private

    private func makePanel() -> QuickPanel {
        let panel = QuickPanel(
            contentRect: NSRect(x: 0, y: 0, width: InletSize.quickPanelWidth, height: 300),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Above normal windows, but not above menus or alerts.
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.onCancel = { [weak self] in self?.dismiss() }
        panel.contentView = NSHostingView(rootView: QuickPanelView(model: model))

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleFocusLoss()
            }
        }

        self.panel = panel
        return panel
    }

    /// Clicking elsewhere closes the panel.
    private func handleFocusLoss() {
        guard isShowing else { return }
        lastFocusLoss = Date()
        dismiss()
    }

    /// Loads the recents that the panel shows, right before it opens.
    /// Recent files come from Spotlight, which can take a moment. When they
    /// arrive, the panel grows to fit them.
    private func refreshContents() {
        model.apps = RecentsStore.shared.recentAppItems(limit: InletSettings.quickPanelRecentApps)
        let limit = InletSettings.quickPanelRecentFiles
        Task { @MainActor [weak self] in
            let files = await RecentFiles.recent(limit: limit)
            guard let self else { return }
            self.model.files = files
            if let panel = self.panel, self.isShowing {
                self.place(panel)
            }
        }
    }

    /// Bottom center of the screen the cursor is on, just above the Dock.
    /// `visibleFrame` leaves out the Dock, so its bottom edge is the Dock's top edge.
    private func place(_ panel: NSPanel) {
        // Size to the content first, so the height matches what is shown.
        let fitted = panel.contentView?.fittingSize ?? .zero
        let size = NSSize(width: InletSize.quickPanelWidth, height: max(fitted.height, 1))

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let area = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: area.midX - size.width / 2,
            y: area.minY + InletSpace.s
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
