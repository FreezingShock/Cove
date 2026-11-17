//
//  OnboardingModel.swift
//  Inlet
//
//  State for the first-run setup window. The screens in OnboardingView.swift,
//  OnboardingSteps.swift and OnboardingShortcutSteps.swift read and change
//  this model. The model draws nothing.
//
//  Where each answer goes:
//  - Habit: only suggests a starting shortcut. Nothing is stored.
//  - Files and Folders: InletSettings.Key.searchIncludesFiles, written at once.
//  - Open at Login: SMAppService.mainApp, changed at once.
//  - Shortcut: the KeyboardShortcuts name of the chosen surface. Saved when the
//    user moves forward from the shortcut step, because the try step needs it.
//  - Try it: borrows HotkeyManager's two handlers while the step is on screen,
//    so the real hotkey opens the practice desk instead of the real overlay.
//    The old handlers are put back when the step ends.
//

import AppKit
import KeyboardShortcuts
import Observation
import ServiceManagement
import SwiftUI

/// UserDefaults keys that only onboarding uses. Move them into InletSettings.Key
/// once PR #8 is on integration, so every key lives in one list.
enum OnboardingKeys {
    /// Bool. True after the user finishes setup, so it stays closed at launch.
    static let completed = "inlet.onboarding.completed"
    /// String, "grid" or "quick". The surface the saved shortcut opens.
    static let surface = "inlet.onboarding.surface"
    /// String, "tap" or "hold".
    static let pressMode = "inlet.onboarding.pressMode"
}

/// The screens in order. `done` is the summary after the try step.
enum OnboardingStep: Int, CaseIterable {
    case welcome, habit, access, shortcut, tryIt, done

    /// Progress bars above the content. One per screen before the summary.
    static let barCount = 5
}

/// The answer to "how do you open apps today?". Only used to suggest a shortcut.
enum OnboardingHabit: String, CaseIterable, Identifiable {
    case spotlight, dock, launchpad, finder
    var id: String { rawValue }
}

/// What the shortcut opens. Each one maps to one KeyboardShortcuts name.
enum OnboardingSurface: String, CaseIterable, Identifiable {
    case grid, quick
    var id: String { rawValue }

    var name: KeyboardShortcuts.Name {
        switch self {
        case .grid: .showGrid
        case .quick: .showQuickPanel
        }
    }

    var label: String {
        switch self {
        case .grid: "Full grid"
        case .quick: "Quick panel"
        }
    }

    var hint: String {
        switch self {
        case .grid: "Fills the screen with every app and file, with the search at the top."
        case .quick: "A small panel rises from the Dock with recent apps and a search field."
        }
    }
}

/// How the shortcut behaves. Hold is stored now; the overlay reads it once
/// HotkeyManager handles key-up (see the PR notes).
enum OnboardingPress: String, CaseIterable, Identifiable {
    case tap, hold
    var id: String { rawValue }

    var label: String { self == .tap ? "Tap" : "Hold" }

    var hint: String {
        switch self {
        case .tap: "Press once to open, and press again to close."
        case .hold: "Hold the keys to peek, and let go to close."
        }
    }
}

/// The four modifier keys, in the order macOS shows them: ⌃ ⌥ ⇧ ⌘.
struct OnboardingModifier: Identifiable {
    let flag: NSEvent.ModifierFlags
    let symbol: String
    let name: String

    var id: String { symbol }

    static let all: [OnboardingModifier] = [
        OnboardingModifier(flag: .control, symbol: "⌃", name: "Control"),
        OnboardingModifier(flag: .option, symbol: "⌥", name: "Option"),
        OnboardingModifier(flag: .shift, symbol: "⇧", name: "Shift"),
        OnboardingModifier(flag: .command, symbol: "⌘", name: "Command"),
    ]
}

/// The keys a shortcut can end with. Kept short on purpose: these are the
/// keys that work well as a launcher trigger.
enum OnboardingKey: String, CaseIterable, Identifiable {
    case space, tab, backtick
    var id: String { rawValue }

    var label: String {
        switch self {
        case .space: "Space"
        case .tab: "Tab"
        case .backtick: "`"
        }
    }

    var keyboardKey: KeyboardShortcuts.Key {
        switch self {
        case .space: .space
        case .tab: .tab
        case .backtick: .backtick
        }
    }
}

/// One row on the summary screen.
struct OnboardingSummaryRow: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

/// Stand-in apps for the practice desk. The real grid shows the user's own apps.
struct OnboardingSampleApp: Identifiable {
    let name: String
    let symbol: String
    let top: Color
    let bottom: Color

    var id: String { name }

    static let all: [OnboardingSampleApp] = [
        OnboardingSampleApp(name: "Safari", symbol: "safari", top: .onboardingHex(0x5AB0FF), bottom: .onboardingHex(0x2563EB)),
        OnboardingSampleApp(name: "Notes", symbol: "note.text", top: .onboardingHex(0xFFE27A), bottom: .onboardingHex(0xF5B82E)),
        OnboardingSampleApp(name: "Music", symbol: "music.note", top: .onboardingHex(0xFF7B93), bottom: .onboardingHex(0xE23D68)),
        OnboardingSampleApp(name: "Photos", symbol: "photo", top: .onboardingHex(0xB38CFF), bottom: .onboardingHex(0x7C3AED)),
        OnboardingSampleApp(name: "Calendar", symbol: "calendar", top: .onboardingHex(0xFF9B8A), bottom: .onboardingHex(0xEF5B4C)),
        OnboardingSampleApp(name: "Mail", symbol: "envelope.fill", top: .onboardingHex(0x6FD3FF), bottom: .onboardingHex(0x1CA7E0)),
        OnboardingSampleApp(name: "Maps", symbol: "map.fill", top: .onboardingHex(0x6EE7B7), bottom: .onboardingHex(0x10B981)),
        OnboardingSampleApp(name: "Terminal", symbol: "terminal.fill", top: .onboardingHex(0x4B5563), bottom: .onboardingHex(0x111827)),
    ]
}

extension Color {
    /// A fixed sRGB color from a 0xRRGGBB value. Used only for onboarding
    /// artwork that is not a theme token (step tints, sample app tiles).
    static func onboardingHex(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

@MainActor
@Observable
final class OnboardingModel {

    // MARK: Navigation

    private(set) var step: OnboardingStep = .welcome

    // MARK: Step 1: habit

    private(set) var habit: OnboardingHabit = .dock

    // MARK: Step 2: permissions

    private(set) var includeFiles: Bool
    private(set) var openAtLogin: Bool
    private(set) var loginError: String?

    // MARK: Step 3: shortcut

    var surface: OnboardingSurface = .grid
    var press: OnboardingPress = .tap
    var modifiers: NSEvent.ModifierFlags = [.option]
    var key: OnboardingKey = .space

    // MARK: Step 4: try it

    private(set) var tried = false
    /// True while the practice desk is open.
    var deskOpen = false
    /// The text in the practice desk's search field.
    var query = ""

    /// Set by the window controller. Brings the setup window forward when the
    /// real hotkey opens the desk while another app is active.
    var onRequestFront: (() -> Void)?

    private var isTrying = false
    private var savedGridHandler: (() -> Void)?
    private var savedQuickHandler: (() -> Void)?

    /// The model whose try step is on screen. The key-up handler reads it.
    private static weak var trying: OnboardingModel?
    private static var keyUpInstalled = false

    init() {
        let defaults = UserDefaults.standard
        includeFiles = defaults.bool(forKey: InletSettings.Key.searchIncludesFiles.rawValue)
        openAtLogin = SMAppService.mainApp.status == .enabled
        press = OnboardingPress(rawValue: defaults.string(forKey: OnboardingKeys.pressMode) ?? "") ?? .tap
        surface = defaults.string(forKey: OnboardingKeys.surface) == OnboardingSurface.quick.rawValue ? .quick : .grid
        restoreShortcut()
    }

    /// Reads the shortcut the surface already has, so reopening setup from Help
    /// shows the user's current choice rather than the default.
    private func restoreShortcut() {
        guard let saved = KeyboardShortcuts.getShortcut(for: surface.name),
              let savedKey = saved.key,
              let match = OnboardingKey.allCases.first(where: { $0.keyboardKey == savedKey })
        else { return }
        key = match
        modifiers = saved.modifiers
    }

    // MARK: Step 1

    /// Picks a habit and suggests the shortcut that fits it. The user can still change it.
    func pick(_ habit: OnboardingHabit) {
        self.habit = habit
        modifiers = habit == .spotlight ? [.control, .option] : [.option]
    }

    // MARK: Step 2

    func setIncludeFiles(_ on: Bool) {
        includeFiles = on
        UserDefaults.standard.set(on, forKey: InletSettings.Key.searchIncludesFiles.rawValue)
    }

    func setOpenAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "macOS did not change Open at Login. You can change it in System Settings under Login Items."
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Step 3: the shortcut

    var shortcut: KeyboardShortcuts.Shortcut {
        KeyboardShortcuts.Shortcut(key.keyboardKey, modifiers: modifiers)
    }

    /// The symbols on the keycaps, in macOS order, ending with the key.
    var keySymbols: [String] {
        OnboardingModifier.all.filter { modifiers.contains($0.flag) }.map(\.symbol) + [key.label]
    }

    /// Such as "⌥ Space". Used in every sentence that names the shortcut.
    var hotkeyLabel: String {
        keySymbols.joined(separator: " ")
    }

    /// Why Continue is blocked on the shortcut step. nil when the shortcut can be used.
    var shortcutBlock: String? {
        if modifiers.isEmpty {
            return "Pick at least one modifier key so the shortcut does not fire while you type."
        }
        if modifiers.contains(.command) && key == .space {
            return "⌘ Space belongs to Spotlight. Pick another combination, or turn Spotlight’s shortcut off in System Settings first."
        }
        if HotkeyManager.validate(shortcut, for: surface.name) != .allow {
            return "That shortcut is already used by the other Inlet hotkey. Pick a different one."
        }
        return nil
    }

    /// A warning that does not block Continue.
    var shortcutWarning: String? {
        guard modifiers.contains(.control), !modifiers.contains(.command), key == .space else { return nil }
        return "⌃ Space switches input sources by default. Keep it only if you don’t use that."
    }

    /// A note under the controls: the habit's suggestion or the ⌥ Space caveat.
    var shortcutNote: String {
        if habit == .spotlight {
            return "You search with ⌘ Space, so ⌃ ⌥ Space keeps Spotlight as it is."
        }
        if modifiers == [.option] && key == .space {
            return "⌥ Space also types a non-breaking space in text fields. While Inlet runs, the shortcut takes that key everywhere, so pick another if you type with it often."
        }
        return ""
    }

    // MARK: Navigation

    var canGoBack: Bool { step != .welcome && step != .done }

    var canSkip: Bool { step == .tryIt }

    var canContinue: Bool {
        switch step {
        case .shortcut: shortcutBlock == nil
        case .tryIt: tried
        default: true
        }
    }

    var continueTitle: String {
        step == .tryIt ? "Finish setup" : "Continue"
    }

    /// Moves to a screen. Leaving the try step ends the practice hooks, and
    /// entering it saves the shortcut and starts them.
    func go(to target: OnboardingStep) {
        if step == .tryIt && target != .tryIt {
            endTrial()
        }
        if target == .tryIt && step != .tryIt {
            commitShortcut()
            beginTrial()
        }
        step = target
    }

    func next() {
        if let target = OnboardingStep(rawValue: step.rawValue + 1) {
            go(to: target)
        }
    }

    func back() {
        if let target = OnboardingStep(rawValue: step.rawValue - 1) {
            go(to: target)
        }
    }

    func skipTry() {
        go(to: .done)
    }

    /// Ends setup. Called by "Start using Inlet", so it does not open at the next launch.
    func finish() {
        endTrial()
        UserDefaults.standard.set(true, forKey: OnboardingKeys.completed)
    }

    /// True once the user has finished setup at least once.
    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: OnboardingKeys.completed)
    }

    private func commitShortcut() {
        KeyboardShortcuts.setShortcut(shortcut, for: surface.name)
        let defaults = UserDefaults.standard
        defaults.set(surface.rawValue, forKey: OnboardingKeys.surface)
        defaults.set(press.rawValue, forKey: OnboardingKeys.pressMode)
    }

    // MARK: Step 4: practice desk

    /// Runs on each press of a Inlet hotkey while the try step is up. Only the
    /// hotkey for the surface being set up opens the desk; the other is ignored.
    private func hotkeyPressed(from source: OnboardingSurface) {
        guard isTrying, source == surface else { return }
        if press == .hold {
            deskOpen = true
        } else {
            deskOpen.toggle()
        }
        if deskOpen {
            onRequestFront?()
        } else {
            query = ""
        }
        tried = true
    }

    private func hotkeyReleased(from source: OnboardingSurface) {
        guard isTrying, source == surface, press == .hold else { return }
        closeDesk()
    }

    /// The button under the desk, for people who would rather click.
    func toggleDeskFromButton() {
        if deskOpen {
            closeDesk()
        } else {
            deskOpen = true
        }
        tried = true
    }

    func closeDesk() {
        deskOpen = false
        query = ""
    }

    var tryNote: String {
        press == .hold ? "Hold mode is on, so letting go closes it." : "Press it again to close."
    }

    private func beginTrial() {
        guard !isTrying else { return }
        isTrying = true
        deskOpen = false
        query = ""
        OnboardingModel.trying = self
        OnboardingModel.installKeyUpHandlers()

        let hotkeys = HotkeyManager.shared
        savedGridHandler = hotkeys.onGridHotkey
        savedQuickHandler = hotkeys.onQuickPanelHotkey
        hotkeys.onGridHotkey = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hotkeyPressed(from: .grid)
            }
        }
        hotkeys.onQuickPanelHotkey = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hotkeyPressed(from: .quick)
            }
        }
    }

    /// Puts the overlay's own hotkey handlers back. Safe to call more than once.
    func endTrial() {
        guard isTrying else { return }
        isTrying = false
        deskOpen = false
        query = ""
        if OnboardingModel.trying === self {
            OnboardingModel.trying = nil
        }
        let hotkeys = HotkeyManager.shared
        hotkeys.onGridHotkey = savedGridHandler
        hotkeys.onQuickPanelHotkey = savedQuickHandler
        savedGridHandler = nil
        savedQuickHandler = nil
    }

    /// KeyboardShortcuts keeps key-up handlers per name and cannot remove one
    /// alone, so these are installed once and check `trying` each time.
    private static func installKeyUpHandlers() {
        guard !keyUpInstalled else { return }
        keyUpInstalled = true
        for surface in OnboardingSurface.allCases {
            KeyboardShortcuts.onKeyUp(for: surface.name) {
                MainActor.assumeIsolated {
                    OnboardingModel.trying?.hotkeyReleased(from: surface)
                }
            }
        }
    }

    // MARK: Summary

    var summaryRows: [OnboardingSummaryRow] {
        [
            OnboardingSummaryRow(label: "Shortcut", value: hotkeyLabel),
            OnboardingSummaryRow(label: "What opens", value: surface.label),
            OnboardingSummaryRow(label: "Press", value: press == .tap ? "Tap to toggle" : "Hold to peek"),
            OnboardingSummaryRow(label: "Files and Folders", value: includeFiles ? "On" : "Off"),
            OnboardingSummaryRow(label: "Open at Login", value: openAtLogin ? "On" : "Off"),
            OnboardingSummaryRow(label: "Network access", value: "None"),
        ]
    }
}
