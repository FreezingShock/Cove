//
//  OverlayView.swift
//  Inlet
//
//  What the overlay panel shows: a scrim over the desktop, with the app
//  grid on top. A click on the scrim (anywhere the grid isn't) closes it.
//

import SwiftUI

/// Lets any view in the overlay close it (Escape, or after an app opens).
private struct DismissOverlayKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Closes the overlay. Set by `OverlayView`, read by `AppGridView`.
    var dismissOverlay: () -> Void {
        get { self[DismissOverlayKey.self] }
        set { self[DismissOverlayKey.self] = newValue }
    }
}

struct OverlayView: View {
    /// Open state, set by `OverlayController`.
    let motion: OverlayMotion
    /// Closes the overlay. Used by the scrim and by the grid.
    let onDismiss: () -> Void

    /// Read from the system, so the overlay follows Reduce Motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // The scrim dims the desktop. Clicking it closes the overlay.
            Rectangle()
                .fill(InletColor.scrim)
                .opacity(motion.isOpen ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
                .animation(reduceMotion ? .inletFade : .inletSnap, value: motion.isOpen)

            // Keyed by session: each open builds a fresh grid, so the search
            // field takes focus again and no state carries over.
            AppGridView(isOpen: motion.isOpen)
                .id(motion.session)
        }
        .ignoresSafeArea()
        .environment(\.dismissOverlay, onDismiss)
        .inletAppearance()  // Light, Dark or Auto, from Settings > Appearance
        .inletThemeRefresh()  // Redraws when the Supporter theme changes
    }
}
