//
//  HotkeyManager.swift
//  Inlet
//
//  Global hotkeys for the full grid and the quick panel. Inlet uses the
//  KeyboardShortcuts package (sindresorhus, MIT), which registers the
//  shortcut with the system and stores the user's choice in UserDefaults.
//
//  How other code uses this file:
//  - The overlay sets `HotkeyManager.shared.onGridHotkey` and
//    `onQuickPanelHotkey`. Each press calls the closure; the overlay decides
//    whether that means open, close or toggle.
//  - The app calls `HotkeyManager.shared.start()` once at launch.
//  - The Keyboard settings pane uses `HotkeyRecorderRow` (see
//    Views/HotkeyRecorderRow.swift), or `KeyboardShortcuts.Recorder(for:)`
//    with the names below, and `HotkeyManager.resetToDefaults()`.
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Opens the full-screen app grid. Default: Option + Space.
    static let showGrid = Self(
        "showGrid",
        initial: KeyboardShortcuts.Shortcut(.space, modifiers: [.option])
    )

    /// Opens the compact quick panel. Default: Control + Option + Space.
    static let showQuickPanel = Self(
        "showQuickPanel",
        initial: KeyboardShortcuts.Shortcut(.space, modifiers: [.control, .option])
    )

    /// The classic Launchpad key. Same action as `showGrid`, switched in
    /// Settings > General ("F4 opens the grid"), so it has no recorder row.
    static let showGridF4 = Self(
        "showGridF4",
        initial: KeyboardShortcuts.Shortcut(.f4, modifiers: [])
    )
}

/// Owns Inlet's two global hotkeys.
///
/// Handlers run on the main thread, because the package delivers hotkey
/// events through Carbon on the main run loop. Keep the closures quick, and
/// do any slow work after they return.
///
/// The class is `@MainActor` because the KeyboardShortcuts calls it makes
/// are main-actor isolated in the package's current version.
@MainActor
final class HotkeyManager {
    /// The one manager for the whole app.
    static let shared = HotkeyManager()

    /// Called on every press of the grid hotkey.
    var onGridHotkey: (() -> Void)?

    /// Called on every press of the quick panel hotkey.
    var onQuickPanelHotkey: (() -> Void)?

    /// Called when the grid hotkey is let go. Only Hold mode uses it.
    var onGridHotkeyReleased: (() -> Void)?

    /// Called when the quick panel hotkey is let go. Only Hold mode uses it.
    var onQuickPanelHotkeyReleased: (() -> Void)?

    private var isStarted = false

    private init() {}

    /// Registers the key handlers. Safe to call more than once; only the
    /// first call does anything.
    ///
    /// The package re-registers a shortcut by itself when the user records a
    /// new one, so this only needs to run once at launch.
    func start() {
        guard !isStarted else { return }
        isStarted = true

        // keyDown rather than keyUp: the overlay should respond as soon as
        // the key goes down, which matters for the 100 ms target.
        KeyboardShortcuts.onKeyDown(for: .showGrid) { [weak self] in
            self?.onGridHotkey?()
        }
        KeyboardShortcuts.onKeyDown(for: .showQuickPanel) { [weak self] in
            self?.onQuickPanelHotkey?()
        }
        KeyboardShortcuts.onKeyDown(for: .showGridF4) { [weak self] in
            self?.onGridHotkey?()
        }

        // keyUp is only used by Hold mode, which closes a surface on release.
        // Tap mode ignores these handlers because the owner's release closure
        // does nothing unless it opened the surface by holding.
        KeyboardShortcuts.onKeyUp(for: .showGrid) { [weak self] in
            self?.onGridHotkeyReleased?()
        }
        KeyboardShortcuts.onKeyUp(for: .showQuickPanel) { [weak self] in
            self?.onQuickPanelHotkeyReleased?()
        }
        KeyboardShortcuts.onKeyUp(for: .showGridF4) { [weak self] in
            self?.onGridHotkeyReleased?()
        }
        setF4Enabled(InletSettings.f4Opens)
    }

    /// Turns the F4 key on or off, from Settings > General.
    func setF4Enabled(_ enabled: Bool) {
        if enabled {
            KeyboardShortcuts.enable(.showGridF4)
        } else {
            KeyboardShortcuts.disable(.showGridF4)
        }
    }

    /// True when the hotkey for `surface` should peek: open while held, close
    /// on release. Onboarding stores one press mode and one surface. Hold
    /// applies only to the surface that onboarding set up, and the other
    /// hotkey stays a tap.
    static func isHoldMode(for surface: OnboardingSurface) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: OnboardingKeys.pressMode) == OnboardingPress.hold.rawValue else {
            return false
        }
        let chosen = defaults.string(forKey: OnboardingKeys.surface)
            .flatMap(OnboardingSurface.init(rawValue:)) ?? .grid
        return chosen == surface
    }

    /// Puts both hotkeys back to their defaults.
    static func resetToDefaults() {
        KeyboardShortcuts.reset(.showGrid, .showQuickPanel)
    }

    /// Checks a shortcut the user just recorded for `name`.
    ///
    /// The recorder already warns about shortcuts that macOS or the app's
    /// menu uses. This adds the check that is specific to Inlet: the two Inlet
    /// hotkeys must not share a shortcut, because a shared shortcut would
    /// open both surfaces at once.
    static func validate(
        _ shortcut: KeyboardShortcuts.Shortcut,
        for name: KeyboardShortcuts.Name
    ) -> KeyboardShortcuts.ValidationResult {
        for (other, label) in inletHotkeys where other != name {
            if KeyboardShortcuts.getShortcut(for: other) == shortcut {
                return .disallow(reason: "That shortcut is already used for \(label).")
            }
        }
        return .allow
    }

    /// The Inlet hotkeys with the labels used in messages.
    private static let inletHotkeys: [(KeyboardShortcuts.Name, String)] = [
        (.showGrid, "the full grid"),
        (.showQuickPanel, "the quick panel"),
    ]
}
