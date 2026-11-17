//
//  OverlayController.swift
//  Inlet
//
//  The full-screen grid overlay. One borderless panel is created once, in
//  `configure(library:)`, then only shown and hidden. Creating it once keeps
//  the SwiftUI view (and its icons) alive, so opening is a cheap show.
//

import AppKit
import SwiftUI

/// A borderless panel that can still become key, so it receives the
/// keyboard. A plain borderless window refuses key status.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayController {
    /// One controller for the whole app. The grid hotkey, the Dock click and
    /// `AppLauncher` all reach the overlay through it.
    static let shared = OverlayController()

    /// Drives the open choreography inside the SwiftUI view.
    private let motion = OverlayMotion()

    /// Created once in `configure(library:)`, then reused.
    private var panel: OverlayPanel?
    /// Frosted desktop behind the grid, as classic Launchpad had. Fades in on open.
    private var blurView: NSVisualEffectView?

    private init() {}

    /// Builds the panel once. Call this at launch, before the first `show()`.
    func configure(library: AppLibrary, layoutStore: LayoutStore) {
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

        // Escape is handled inside SwiftUI (AppGridView), so it can clear
        // the search first and close only when there is nothing to clear.
        let root = OverlayView(
            motion: motion,
            onDismiss: { [weak self] in self?.hide() }
        )
        .environment(library)
        .environment(layoutStore)

        // Classic Launchpad blurs what is behind it. The blur is a sibling
        // under the SwiftUI view, so the scrim and icons stay crisp on top.
        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.alphaValue = 0
        // Reduce Transparency: keep only the scrim, with no blur behind it.
        blur.isHidden = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

        let host = NSHostingView(rootView: root)
        let container = NSView()
        let layers: [NSView] = [blur, host]
        for layer in layers {
            layer.frame = container.bounds
            layer.autoresizingMask = [.width, .height]
            container.addSubview(layer)
        }

        panel.contentView = container
        self.blurView = blur
        self.panel = panel
    }

    /// True while the overlay is on screen.
    var isVisible: Bool { panel?.isVisible ?? false }

    /// The grid hotkey: opens the overlay, or closes it if it is already open.
    func toggle() {
        if isVisible {
            InletSignpost.cancelHotkeyToVisible()
            hide()
        } else {
            show()
        }
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
        blurView?.alphaValue = 0
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        // The panel is on screen now; close the hotkey timing interval.
        InletSignpost.endHotkeyToVisible()

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.motion.isOpen = true
                // The blur fades in with the icons' spring.
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    self.blurView?.animator().alphaValue = 1
                }
            }
        }
    }

    /// Hides the overlay. Instant on purpose: an app launch should not wait
    /// for an animation.
    func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        motion.isOpen = false
        blurView?.alphaValue = 0
    }
}

/// Holds whether the overlay is in its open state. SwiftUI watches it
/// and runs the open choreography when it changes.
@MainActor
@Observable
final class OverlayMotion {
    var isOpen = false
}
