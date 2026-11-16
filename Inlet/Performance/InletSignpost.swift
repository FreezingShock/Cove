//
//  InletSignpost.swift
//  Inlet
//
//  Timing marks for the speed targets in the v1 spec. Each interval is an
//  os_signpost event, so Instruments can show it without changing the app.
//  Read PERFORMANCE.md for how to record and read them.
//

import OSLog

@MainActor
enum InletSignpost {
    /// Subsystem and category are what Instruments and Console filter on.
    static let signposter = OSSignposter(
        subsystem: "com.freezingshock.Inlet",
        category: "Performance"
    )

    /// The interval name the grid hotkey press is timed under.
    private static let hotkeyToVisible: StaticString = "Hotkey to visible"

    /// The interval started by the last grid hotkey press. It is ended once
    /// the overlay is on screen, or cancelled if the press closes the overlay.
    private static var pendingHotkey: OSSignpostIntervalState?

    /// Starts timing a grid hotkey press. Call it when the key goes down.
    static func beginHotkeyToVisible() {
        pendingHotkey = signposter.beginInterval(
            hotkeyToVisible,
            id: signposter.makeSignpostID()
        )
    }

    /// Ends the open interval, if there is one. Call it right after the
    /// overlay panel has been ordered onto the screen.
    static func endHotkeyToVisible() {
        guard let state = pendingHotkey else { return }
        pendingHotkey = nil
        signposter.endInterval(hotkeyToVisible, state)
    }

    /// Drops the open interval without recording it. Used when the press
    /// closes the overlay, which is not the open path the target measures.
    static func cancelHotkeyToVisible() {
        pendingHotkey = nil
    }
}
