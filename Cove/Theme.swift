//
//  Theme.swift
//  Cove
//
//  Design values from the Cove handoff (design system section), kept in
//  one place so later versions can tune them without hunting through views.
//  v0.1 is a plain grid, so only the basics are used here.
//

import SwiftUI

enum Theme {
    // MARK: Colors

    /// Deepest background, #05070C.
    static let base = Color(hex: 0x05070C)
    /// The single accent, #46E6D6. Use sparingly (once or twice per screen).
    static let aqua = Color(hex: 0x46E6D6)
    /// Primary text.
    static let text = Color.white
    /// Labels, counts and hints: rgba(235, 240, 255, 0.72).
    static let textSecondary = Color(red: 235 / 255, green: 240 / 255, blue: 1, opacity: 0.72)
    /// Hover highlight behind a grid cell.
    static let hover = Color.white.opacity(0.08)

    // MARK: Grid sizing (points)

    static let iconSize: CGFloat = 72
    static let cellWidth: CGFloat = 144
    static let columns = 7
    static let rowSpacing: CGFloat = 30
    static let labelSize: CGFloat = 12
    static let cellCornerRadius: CGFloat = 18
    static let sidePadding: CGFloat = 40

    /// Window width that fits all 7 columns plus side padding.
    static var windowWidth: CGFloat {
        cellWidth * CGFloat(columns) + sidePadding * 2
    }
}

extension Color {
    /// Builds a color from a hex number like 0x46E6D6.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
