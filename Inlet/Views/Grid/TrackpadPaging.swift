//
//  TrackpadPaging.swift
//  Inlet
//
//  Two-finger swipes turn the pages of the paged grid, as classic Launchpad
//  did. A mouse drag already works through EditableGridView's gesture, but a
//  trackpad scroll is not a mouse drag: it arrives as a scroll-wheel event.
//  This class watches those events while the grid is on screen. It only
//  reads them, so nothing else in the overlay loses its input.
//

import AppKit

@MainActor
final class TrackpadPaging {
    /// Horizontal movement in points, from each scroll event of a swipe.
    /// Positive means the content should move right, as a finger does.
    var onScroll: ((CGFloat) -> Void)?
    /// The fingers lifted at the end of a horizontal swipe.
    var onEnd: (() -> Void)?

    private var monitor: Any?
    /// Decided by the first movement of a swipe. Vertical swipes are ignored.
    private var isHorizontal: Bool?

    /// Starts watching scroll events for the overlay window.
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            // Never consume the event: it still goes to whatever view is under the pointer.
            return event
        }
    }

    /// Stops watching. Called when the paged grid leaves the screen.
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isHorizontal = nil
    }

    private func handle(_ event: NSEvent) {
        // Only the overlay counts, and only trackpad swipes, which report
        // precise deltas. Mouse wheels are left alone, and so is momentum,
        // which keeps going after the fingers lift.
        guard event.window is OverlayPanel,
              event.hasPreciseScrollingDeltas,
              event.momentumPhase == [] else { return }

        if event.phase == .began {
            isHorizontal = nil
        }

        if event.phase == .ended || event.phase == .cancelled {
            if isHorizontal == true { onEnd?() }
            isHorizontal = nil
            return
        }

        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        if isHorizontal == nil {
            // Wait for a movement big enough to tell the two axes apart.
            guard abs(dx) + abs(dy) > 0.5 else { return }
            isHorizontal = abs(dx) > abs(dy)
        }
        guard isHorizontal == true else { return }
        onScroll?(dx)
    }
}
