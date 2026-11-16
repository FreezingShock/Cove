//
//  OverlayView.swift
//  Cove
//
//  What the overlay panel shows: a scrim over the desktop, with the app
//  grid on top. A click on the scrim (anywhere the grid isn't) closes it.
//

import SwiftUI

struct OverlayView: View {
    /// Open state, set by `OverlayController`.
    let motion: OverlayMotion
    /// Called when the user clicks the empty scrim.
    let onDismiss: () -> Void

    /// Read from the system, so the overlay follows Reduce Motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // The scrim dims the desktop. Clicking it closes the overlay.
            Rectangle()
                .fill(CoveColor.scrim)
                .opacity(motion.isOpen ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .coveSnap, value: motion.isOpen)

            AppGridView(isOpen: motion.isOpen)
        }
        .ignoresSafeArea()
    }
}
