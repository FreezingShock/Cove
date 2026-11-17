//
//  Supporter.swift
//  Inlet
//
//  The one switch for Supporter features: custom themes and zones.
//  Inlet is MIT licensed, so this gate is honor-based. Anyone building from
//  source can turn it on. Payment is not wired up yet.
//

import Foundation

enum Supporter {
    /// Whether Supporter features are on. Stored like every other setting.
    static func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: InletSettings.Key.supporterActive.rawValue)
    }
}
