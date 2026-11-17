//
//  GridLayout.swift
//  Inlet
//
//  The saved state of the grid: the order of icons and folders, which
//  third-party apps the user hid, and the groups the group bar filters by.
//  This file is plain data with no UI, so the rules here can be checked
//  without opening a window.
//

import Foundation

/// One thing on the grid: a single app, or a folder that holds several.
enum GridEntry: Codable, Hashable, Identifiable, Sendable {
    /// An app, by its `AppItem.id` (its path on disk).
    case app(String)
    /// A folder of apps.
    case folder(GridFolder)

    var id: String {
        switch self {
        case .app(let appID): return "app:" + appID
        case .folder(let folder): return "folder:" + folder.id
        }
    }
}

/// A folder on the grid. Folders can't nest, and hold at most `maxApps`.
struct GridFolder: Codable, Hashable, Identifiable, Sendable {
    /// The most apps a folder holds. The spec: one page of 3 x 3.
    static let maxApps = 9

    /// A random id, so renaming a folder doesn't change its identity.
    var id: String
    /// Shown under the folder icon and in the open folder's title.
    var name: String
    /// Apps in the folder, in display order.
    var appIDs: [String]
}

/// A third-party app the user hid. It stays installed; it just leaves the grid.
struct HiddenApp: Codable, Hashable, Sendable {
    var appID: String
    /// Where the app sat on the grid, so Undo puts it back in the same place.
    var position: Int
}

/// The whole saved layout. Written to disk by `LayoutStore`.
struct GridLayout: Codable, Equatable, Sendable {
    /// Bump this when the file format changes.
    /// 1: order, folders, hidden apps. 2: adds `groups`.
    static let currentVersion = 2

    var version: Int
    /// Grid order, first item first.
    var entries: [GridEntry]
    /// Apps the user hid, in the order they were hidden.
    var hidden: [HiddenApp]
    /// Groups in bar order. After reconciling, every installed app is in exactly one.
    var groups: [AppGroup]

    init(
        version: Int = GridLayout.currentVersion,
        entries: [GridEntry] = [],
        hidden: [HiddenApp] = [],
        groups: [AppGroup] = []
    ) {
        self.version = version
        self.entries = entries
        self.hidden = hidden
        self.groups = groups
    }

    private enum CodingKeys: String, CodingKey {
        case version, entries, hidden, groups
    }

    /// Version 1 files have no `groups` key, so every key except `version`
    /// is optional on disk. Missing keys decode as empty.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        entries = try container.decodeIfPresent([GridEntry].self, forKey: .entries) ?? []
        hidden = try container.decodeIfPresent([HiddenApp].self, forKey: .hidden) ?? []
        groups = try container.decodeIfPresent([AppGroup].self, forKey: .groups) ?? []
    }

    /// The layout a new user sees: every app A to Z on the grid, nothing hidden,
    /// and the preset groups with each app in its suggested group.
    /// `apps` must already be sorted by name, as `AppLibrary` sorts them.
    static func makeDefault(for apps: [AppItem]) -> GridLayout {
        GridLayout().reconciled(with: apps)
    }

    /// Brings a saved layout in line with the apps installed right now.
    ///
    /// - Apps that were uninstalled are dropped, and so are folders left empty.
    /// - A folder with one app left turns back into a plain app.
    /// - A folder that somehow holds more than `maxApps` keeps its first nine;
    ///   the rest go on the grid as plain apps, so none disappear.
    /// - Newly installed apps are added at the end, in the order given.
    /// - Groups: the presets are created when there are none (new installs and
    ///   version 1 files), uninstalled apps leave their group, and each app
    ///   that is in no group joins the group its category suggests.
    func reconciled(with apps: [AppItem]) -> GridLayout {
        let installed = Set(apps.map(\.id))
        // Hidden apps are never on the grid, so treat them as already placed.
        var placed = Set(hidden.map(\.appID))
        var result = GridLayout()

        for entry in entries {
            switch entry {
            case .app(let appID):
                guard installed.contains(appID), placed.insert(appID).inserted else { continue }
                result.entries.append(.app(appID))

            case .folder(var folder):
                var kept: [String] = []
                for appID in folder.appIDs where installed.contains(appID) {
                    if placed.insert(appID).inserted { kept.append(appID) }
                }
                folder.appIDs = Array(kept.prefix(GridFolder.maxApps))
                // Overflow apps move onto the grid right after the folder.
                let overflow = kept.dropFirst(GridFolder.maxApps)

                switch folder.appIDs.count {
                case 0:
                    break
                case 1:
                    result.entries.append(.app(folder.appIDs[0]))
                default:
                    result.entries.append(.folder(folder))
                }
                result.entries.append(contentsOf: overflow.map { GridEntry.app($0) })
            }
        }

        for app in apps where placed.insert(app.id).inserted {
            result.entries.append(.app(app.id))
        }

        result.hidden = hidden.filter { installed.contains($0.appID) }
        result.groups = reconciledGroups(with: apps)
        result.version = GridLayout.currentVersion
        return result
    }

    /// Groups after a scan. Seeds the presets when there are none, drops
    /// uninstalled apps, and puts each app that has no group into the group
    /// its category suggests. Hidden apps keep their group, so Restore returns
    /// them to it.
    private func reconciledGroups(with apps: [AppItem]) -> [AppGroup] {
        var result = groups.isEmpty ? AppGroup.presets : groups
        let installed = Set(apps.map(\.id))
        var seen = Set<String>()

        for index in result.indices {
            result[index].appIDs = result[index].appIDs.filter { appID in
                installed.contains(appID) && seen.insert(appID).inserted
            }
        }

        for app in apps where !seen.contains(app.id) {
            guard let index = AppGroup.suggestedIndex(for: app.category, in: result) else { break }
            result[index].appIDs.append(app.id)
            seen.insert(app.id)
        }
        return result
    }

    /// Moves a top-level entry to `index`, clamped to the grid.
    mutating func moveEntry(withID id: String, to index: Int) {
        guard let from = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: from)
        entries.insert(entry, at: min(max(index, 0), entries.count))
    }

    /// Hides a top-level app and remembers where it was, for Undo.
    mutating func hideApp(_ appID: String) {
        guard let index = entries.firstIndex(of: .app(appID)) else { return }
        entries.remove(at: index)
        hidden.append(HiddenApp(appID: appID, position: index))
    }

    /// Puts a hidden app back at the position it was hidden from.
    mutating func restoreApp(_ appID: String) {
        guard let saved = hidden.first(where: { $0.appID == appID }) else { return }
        hidden.removeAll { $0.appID == appID }
        let index = min(max(saved.position, 0), entries.count)
        entries.insert(.app(appID), at: index)
    }

    // MARK: Folders

    /// Drops a top-level app onto another entry. Onto an app, the two become a
    /// new folder named `folderName`. Onto a folder, the app joins it if there
    /// is room. Returns false and changes nothing when the merge can't happen.
    /// `draggedID` must be a top-level app, not one already in a folder.
    @discardableResult
    mutating func merge(appID draggedID: String, ontoEntryID targetID: String, folderName: String) -> Bool {
        guard targetID != GridEntry.app(draggedID).id,
              entries.contains(.app(draggedID)),
              let targetIndex = entries.firstIndex(where: { $0.id == targetID }) else { return false }
        if case .folder(let folder) = entries[targetIndex], folder.appIDs.count >= GridFolder.maxApps {
            return false
        }

        // The dragged app leaves its place first. Its target is never the dragged app.
        entries.removeAll { $0 == .app(draggedID) }
        guard let index = entries.firstIndex(where: { $0.id == targetID }) else { return false }
        switch entries[index] {
        case .app(let targetApp):
            let folder = GridFolder(id: UUID().uuidString, name: folderName, appIDs: [targetApp, draggedID])
            entries[index] = .folder(folder)
        case .folder(var folder):
            folder.appIDs.append(draggedID)
            entries[index] = .folder(folder)
        }
        return true
    }

    /// Takes an app out of a folder. It lands on the grid right after the
    /// folder. A folder left with one app turns back into a plain app, and an
    /// empty folder disappears.
    mutating func removeFromFolder(appID: String, folderID: String) {
        guard let folderIndex = entries.firstIndex(where: { $0.id == "folder:" + folderID }),
              case .folder(var folder) = entries[folderIndex],
              folder.appIDs.contains(appID) else { return }

        folder.appIDs.removeAll { $0 == appID }
        let insertAt: Int
        switch folder.appIDs.count {
        case 0:
            entries.remove(at: folderIndex)
            insertAt = folderIndex
        case 1:
            entries[folderIndex] = .app(folder.appIDs[0])
            insertAt = folderIndex + 1
        default:
            entries[folderIndex] = .folder(folder)
            insertAt = folderIndex + 1
        }
        entries.insert(.app(appID), at: min(insertAt, entries.count))
    }

    /// Renames a folder. The caller trims the name and keeps it short.
    mutating func renameFolder(withID folderID: String, to name: String) {
        guard let index = entries.firstIndex(where: { $0.id == "folder:" + folderID }),
              case .folder(var folder) = entries[index] else { return }
        folder.name = name
        entries[index] = .folder(folder)
    }

    // MARK: - Groups

    /// The id of the group that holds `appID`, if any.
    func groupID(containing appID: String) -> String? {
        groups.first(where: { $0.appIDs.contains(appID) })?.id
    }

    /// Adds a custom group at the end of the bar. Returns its id, or nil when
    /// the name is empty.
    @discardableResult
    mutating func addGroup(name: String, color: GroupColor, symbol: String) -> String? {
        guard let clean = AppGroup.cleanName(name) else { return nil }
        let group = AppGroup(
            id: UUID().uuidString,
            name: clean,
            color: color,
            symbol: symbol,
            suggestedCategory: nil,
            appIDs: []
        )
        groups.append(group)
        return group.id
    }

    /// Changes a group's name, color or symbol. Only the fields passed are
    /// changed. An empty name is ignored.
    mutating func editGroup(
        withID id: String,
        name: String? = nil,
        color: GroupColor? = nil,
        symbol: String? = nil
    ) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        if let name, let clean = AppGroup.cleanName(name) {
            groups[index].name = clean
        }
        if let color {
            groups[index].color = color
        }
        if let symbol {
            groups[index].symbol = symbol
        }
    }

    /// Moves a group to `index` on the bar, clamped to the list.
    mutating func moveGroup(withID id: String, to index: Int) {
        guard let from = groups.firstIndex(where: { $0.id == id }) else { return }
        let group = groups.remove(at: from)
        groups.insert(group, at: min(max(index, 0), groups.count))
    }

    /// Deletes a group. Its apps move to the Other group, or to the first group
    /// left if there is no Other. The last group can't be deleted, so every app
    /// always has a group.
    mutating func deleteGroup(withID id: String) {
        guard groups.count > 1, let index = groups.firstIndex(where: { $0.id == id }) else { return }
        let removed = groups.remove(at: index)
        let target = groups.firstIndex(where: { $0.suggestedCategory == .other }) ?? 0
        groups[target].appIDs.append(contentsOf: removed.appIDs)
    }

    /// The first color no group uses yet, so a new group looks different from
    /// its neighbours. Falls back to blue when all nine are taken.
    var unusedColor: GroupColor {
        let used = Set(groups.map(\.color))
        return GroupColor.allCases.first { !used.contains($0) } ?? .blue
    }

    /// Moves an app to the end of a group, taking it out of whichever group it
    /// was in. Does nothing for an unknown group.
    mutating func moveApp(_ appID: String, toGroup groupID: String) {
        guard let target = groups.firstIndex(where: { $0.id == groupID }) else { return }
        for index in groups.indices {
            groups[index].appIDs.removeAll { $0 == appID }
        }
        groups[target].appIDs.append(appID)
    }
}
