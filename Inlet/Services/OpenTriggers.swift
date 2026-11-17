//
//  OpenTriggers.swift
//  Inlet
//
//  Two more ways to open the grid, as classic Launchpad had them:
//  - Pinch in opens the grid, and spread out closes it. The pinch only opens
//    the grid while Finder is the front app (you are on the desktop), so a
//    pinch to zoom in Safari never opens Inlet.
//  - A hot corner opens the grid when the pointer rests in that corner. It only
//    opens: it never closes the grid, so reaching a corner mid-use is safe.
//
//  Both are plain NSEvent monitors. Each one is switched in Settings > General.
//

import AppKit

/// The screen corner that opens the grid. Stored as the raw value.
enum HotCorner: String, CaseIterable {
    case off, topLeft, topRight, bottomLeft, bottomRight

    /// Label for the Settings picker.
    var title: String {
        switch self {
        case .off: "Off"
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }

    /// True when `point` is within `zone` points of this corner of `frame`.
    /// Both are in screen coordinates, where the top edge is `frame.maxY`.
    func contains(_ point: CGPoint, in frame: CGRect, zone: CGFloat = 3) -> Bool {
        let nearLeft = point.x <= frame.minX + zone
        let nearRight = point.x >= frame.maxX - zone
        let nearTop = point.y >= frame.maxY - zone
        let nearBottom = point.y <= frame.minY + zone
        switch self {
        case .off: return false
        case .topLeft: return nearLeft && nearTop
        case .topRight: return nearRight && nearTop
        case .bottomLeft: return nearLeft && nearBottom
        case .bottomRight: return nearRight && nearBottom
        }
    }
}

@MainActor
final class OpenTriggers {
    /// One set of monitors for the whole app.
    static let shared = OpenTriggers()

    /// Keeps the monitor tokens alive until the app quits.
    private var monitors: [Any] = []

    /// Sum of the pinch amount in the current gesture.
    private var pinchTotal: CGFloat = 0
    /// True once this pinch has opened or closed the grid, so it fires once.
    private var pinchFired = false

    /// The dwell in a hot corner that is still pending.
    private var cornerTask: Task<Void, Never>?
    /// False after a hot corner opens the grid, until the pointer leaves the corner.
    private var cornerArmed = true

    /// How long the pointer must rest in the corner.
    private static let dwell: Duration = .milliseconds(250)
    /// Pinch amount that counts as a pinch or a spread.
    private static let pinchThreshold: CGFloat = 0.2
    /// Finder is the front app when the desktop is clicked.
    private static let desktopBundleID = "com.apple.finder"

    private init() {}

    /// Installs the monitors. Safe to call more than once.
    func start() {
        guard monitors.isEmpty else { return }

        // Global monitors see gestures aimed at other apps (the desktop).
        // Local monitors see gestures aimed at Inlet (the open overlay).
        let pinchGlobal = NSEvent.addGlobalMonitorForEvents(matching: .magnify) { [weak self] event in
            MainActor.assumeIsolated { self?.handlePinch(event) }
        }
        let pinchLocal = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            MainActor.assumeIsolated { self?.handlePinch(event) }
            return event
        }
        let moveGlobal = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMouseMoved() }
        }
        let moveLocal = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseMoved() }
            return event
        }
        monitors = [pinchGlobal, pinchLocal, moveGlobal, moveLocal].compactMap { $0 }
    }

    // MARK: Pinch

    private func handlePinch(_ event: NSEvent) {
        guard InletSettings.pinchToOpen else { return }

        switch event.phase {
        case .began:
            pinchTotal = 0
            pinchFired = false
        case .ended, .cancelled:
            pinchTotal = 0
            pinchFired = false
            return
        default:
            break
        }
        guard !pinchFired else { return }

        pinchTotal += event.magnification
        let overlay = OverlayController.shared
        if pinchTotal < -Self.pinchThreshold, !overlay.isVisible, isOnDesktop {
            // Pinch in, on the desktop: open the grid.
            pinchFired = true
            overlay.show()
        } else if pinchTotal > Self.pinchThreshold, overlay.isVisible {
            // Spread out with the grid open: close it.
            pinchFired = true
            overlay.dismiss()
        }
    }

    /// True when Finder is the front app, which is the case while the desktop is clicked.
    private var isOnDesktop: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.desktopBundleID
    }

    // MARK: Hot corner

    private func handleMouseMoved() {
        let corner = InletSettings.hotCorner
        let point = NSEvent.mouseLocation

        // Leaving the corner (or having the setting off) disarms it and cancels the wait.
        guard corner != .off,
              let frame = NSScreen.screens.first(where: { $0.frame.contains(point) })?.frame,
              corner.contains(point, in: frame) else {
            cornerTask?.cancel()
            cornerTask = nil
            cornerArmed = true
            return
        }

        // The corner opens the grid only. With the grid already open, it does nothing.
        guard cornerArmed, cornerTask == nil, !OverlayController.shared.isVisible else { return }

        cornerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.dwell)
            guard let self, !Task.isCancelled else { return }
            self.cornerTask = nil
            // Still in the corner after the dwell? Then open.
            guard corner.contains(NSEvent.mouseLocation, in: frame) else { return }
            self.cornerArmed = false
            OverlayController.shared.show()
        }
    }
}
