//
//  HotkeyRecorderRow.swift
//  Inlet
//
//  A row in a Settings form where the user records one Inlet hotkey.
//  The recorder stores the choice in UserDefaults and rejects a shortcut
//  that the other Inlet hotkey already uses (see HotkeyManager.validate).
//

import SwiftUI
import KeyboardShortcuts

struct HotkeyRecorderRow: View {
    /// The text shown on the left of the row, such as "Full grid".
    let title: LocalizedStringKey

    /// Which Inlet hotkey this row changes.
    let name: KeyboardShortcuts.Name

    var body: some View {
        KeyboardShortcuts.Recorder(title, name: name)
            .shortcutValidation { shortcut in
                HotkeyManager.validate(shortcut, for: name)
            }
    }
}
