//
//  OverlayController.swift
//  Cove
//
//  The full-screen grid overlay. One borderless panel is created the first
//  time it is needed, then only shown and hidden. Creating it once keeps
//  the SwiftUI view (and its icons) alive, so opening is a cheap show.
//

import AppKit
import SwiftUI

/// A borderless panel that can still become key, so it receives the
/// keyboard (Escape). A plain borderless window refuses key status.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayController {
    /// One controller for the whole app. `AppLauncher` uses it to hide
    /// the overlay before it opens an app.
    static let shared = OverlayController()

    /// Drives the open choreography inside the SwiftUI view.
    private let motion = OverlayMotion()

    /// Created once in `configure(library:)`, then reused.
    private var panel: OverlayPanel?
    /// Watches for the Escape key while the overlay is open.
    private var keyMonitor: Any?

    private init() {}

    /// Builds the panel once. Call this at launch, before the first `show()`.
    func configure(library: AppLibrary) {
        guard panel == nil else { return }

        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        // Above normal windows, including floating ones.
        panel.level = .popUpMenu
        // Clear background, so the desktop shows through the scrim.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Stay up when another app takes focus, and don't disappear on
        // deactivate. Hiding is always explicit.
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Use the screen's animation settings only where we ask for them.
        panel.animationBehavior = .none
        // Appear on every Space, and over full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let root = OverlayView(
            motion: motion,
            onDismiss: { [weak self] in self?.hide() }
        )
        .environment(library)

        panel.contentView = NSHostingView(rootView: root)
        self.panel = panel
    }

    /// Shows the overlay on the screen under the cursor.
    func show() {
        guard let panel, !panel.isVisible else { return }

        // Cover the whole screen that holds the cursor, menu bar included.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let frame = screen?.frame {
            panel.setFrame(frame, display: false)
        }

        // Start from the closed state, then open on the next turn so the
        // open animation has a starting point to animate from.
        motion.isOpen = false
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()

        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.motion.isOpen = true }
        }
    }

    /// Hides the overlay. Instant on purpose: an app launch should not wait
    /// for an animation.
    func hide() {
        guard let panel, panel.isVisible else { return }
        removeKeyMonitor()
        panel.orderOut(nil)
        motion.isOpen = false
    }

    // MARK: Escape

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Keycode 53 is Escape. Only handle keys sent to our panel.
            guard event.keyCode == 53, event.window === self?.panel else { return event }
            MainActor.assumeIsolated { self?.hide() }
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }
}

/// Holds whether the overlay is in its open state. SwiftUI watches it
/// and runs the open choreography when it changes.
@MainActor
@Observable
final class OverlayMotion {
    var isOpen = false
}
