//
//  SystemPane.swift
//  Inlet
//
//  Panes of System Settings that search can jump to, so "wifi" or "privacy"
//  opens the right page. Matching uses the same rules as app search.
//
//  The links use the System Settings extension IDs (macOS 13 and later).
//  They are written from memory and must be checked on a real Mac; the
//  Mac test checklist in the PR lists each one. A link that is wrong on
//  macOS 26 should be fixed here, in one place.
//

import AppKit
import Foundation

struct SystemPane: Identifiable, Hashable, Sendable {
    /// The name shown in the results, e.g. "Wi-Fi".
    let title: String
    /// An SF Symbol for the row icon.
    let symbol: String
    /// Other words that should find this pane, e.g. "wifi" for "Wi-Fi".
    let keywords: [String]
    /// The deep link that opens the pane.
    let link: String

    var id: String { link }

    var url: URL? { URL(string: link) }

    /// Opens the pane. The caller should hide Inlet first.
    func open() {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Panes whose title or keyword matches `query`, best match first.
    /// Empty when the query is empty. At most `limit` results.
    static func matches(for query: String, limit: Int) -> [SystemPane] {
        let q = AppSearch.normalize(query)
        guard !q.isEmpty, limit > 0 else { return [] }

        let ranked = all.compactMap { pane -> (pane: SystemPane, rank: AppSearch.Rank)? in
            let best = ([pane.title] + pane.keywords)
                .compactMap { AppSearch.rank(of: AppSearch.normalize($0), query: q) }
                .min()
            guard let best else { return nil }
            return (pane, best)
        }
        return ranked
            .sorted { $0.rank < $1.rank }
            .prefix(limit)
            .map(\.pane)
    }

    static let all: [SystemPane] = [
        SystemPane(title: "Wi-Fi", symbol: "wifi",
                   keywords: ["wifi", "wireless", "internet"],
                   link: "x-apple.systempreferences:com.apple.Wi-Fi-Settings.extension"),
        SystemPane(title: "Bluetooth", symbol: "bluetooth",
                   keywords: ["devices", "airpods", "pair"],
                   link: "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension"),
        SystemPane(title: "Network", symbol: "network",
                   keywords: ["ethernet", "vpn", "proxy"],
                   link: "x-apple.systempreferences:com.apple.Network-Settings.extension"),
        SystemPane(title: "Notifications", symbol: "bell.badge",
                   keywords: ["alerts", "banners", "do not disturb"],
                   link: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"),
        SystemPane(title: "Sound", symbol: "speaker.wave.2",
                   keywords: ["volume", "audio", "speakers", "microphone"],
                   link: "x-apple.systempreferences:com.apple.Sound-Settings.extension"),
        SystemPane(title: "Focus", symbol: "moon",
                   keywords: ["do not disturb", "dnd"],
                   link: "x-apple.systempreferences:com.apple.Focus-Settings.extension"),
        SystemPane(title: "Displays", symbol: "display",
                   keywords: ["monitor", "resolution", "brightness", "night shift"],
                   link: "x-apple.systempreferences:com.apple.Displays-Settings.extension"),
        SystemPane(title: "Wallpaper", symbol: "photo.on.rectangle",
                   keywords: ["background", "desktop picture"],
                   link: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"),
        SystemPane(title: "Keyboard", symbol: "keyboard",
                   keywords: ["shortcuts", "input", "typing", "text"],
                   link: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"),
        SystemPane(title: "Trackpad", symbol: "hand.point.up.left",
                   keywords: ["gestures", "touchpad"],
                   link: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension"),
        SystemPane(title: "Mouse", symbol: "computermouse",
                   keywords: ["pointer", "scrolling"],
                   link: "x-apple.systempreferences:com.apple.Mouse-Settings.extension"),
        SystemPane(title: "Battery", symbol: "battery.75",
                   keywords: ["power", "energy", "charging"],
                   link: "x-apple.systempreferences:com.apple.Battery-Settings.extension"),
        SystemPane(title: "Privacy & Security", symbol: "hand.raised",
                   keywords: ["privacy", "permissions", "security", "full disk access"],
                   link: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"),
        SystemPane(title: "Accessibility", symbol: "accessibility",
                   keywords: ["voiceover", "zoom", "reduce motion", "display"],
                   link: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension"),
        SystemPane(title: "Login Items", symbol: "person.badge.clock",
                   keywords: ["startup", "launch at login", "background items", "login"],
                   link: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"),
        SystemPane(title: "Printers & Scanners", symbol: "printer",
                   keywords: ["printer", "scanner", "print"],
                   link: "x-apple.systempreferences:com.apple.Print-Scan-Settings.extension"),
    ]
}
