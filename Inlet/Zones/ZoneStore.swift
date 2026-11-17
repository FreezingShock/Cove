//
//  ZoneStore.swift
//  Inlet
//
//  Saves the zones in UserDefaults. Zones stay on disk when Supporter is
//  off; the grid just doesn't draw them.
//

import Foundation
import Observation

@MainActor
@Observable
final class ZoneStore {
    static let shared = ZoneStore()

    /// Zones in the order they were added. Not clamped to the grid; the grid fits them when drawing.
    private(set) var zones: [GridZone]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: InletSettings.Key.zones.rawValue),
           let saved = try? JSONDecoder().decode([GridZone].self, from: data) {
            zones = saved
        } else {
            zones = []
        }
    }

    /// Adds a zone, or replaces the one with the same id. Returns false, and
    /// changes nothing, when the zone runs past the grid or overlaps another zone.
    @discardableResult
    func save(_ zone: GridZone, columns: Int) -> Bool {
        let fitted = zone.fitted(columns: columns)
        let others = zones.filter { $0.id != fitted.id }
        guard ZoneLayout.fits(fitted, columns: columns, among: others) else { return false }

        if let index = zones.firstIndex(where: { $0.id == fitted.id }) {
            zones[index] = fitted
        } else {
            zones.append(fitted)
        }
        persist()
        return true
    }

    func remove(_ id: String) {
        guard zones.contains(where: { $0.id == id }) else { return }
        zones.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(zones), forKey: InletSettings.Key.zones.rawValue)
    }
}
