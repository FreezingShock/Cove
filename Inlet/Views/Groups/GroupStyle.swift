//
//  GroupStyle.swift
//  Inlet
//
//  Shared pieces for groups: the color each GroupColor draws with, and the
//  "Move to Group" submenu that right-clicking an app offers.
//

import AppKit
import SwiftUI

extension GroupColor {
    /// The system color for this group. System colors adapt to Light, Dark
    /// and Increase Contrast on their own.
    var color: Color {
        switch self {
        case .blue: return Color(nsColor: .systemBlue)
        case .teal: return Color(nsColor: .systemTeal)
        case .green: return Color(nsColor: .systemGreen)
        case .yellow: return Color(nsColor: .systemYellow)
        case .orange: return Color(nsColor: .systemOrange)
        case .red: return Color(nsColor: .systemRed)
        case .pink: return Color(nsColor: .systemPink)
        case .purple: return Color(nsColor: .systemPurple)
        case .gray: return Color(nsColor: .systemGray)
        }
    }

    /// The name VoiceOver reads for this color.
    var label: String {
        switch self {
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .red: return "Red"
        case .pink: return "Pink"
        case .purple: return "Purple"
        case .gray: return "Gray"
        }
    }
}

/// The "Move to Group" submenu for an app's context menu. The app's current
/// group is checked and cannot be picked again.
struct MoveToGroupMenu: View {
    let groups: [AppGroup]
    let currentGroupID: String?
    let onSelect: (String) -> Void

    var body: some View {
        Menu("Move to Group") {
            ForEach(groups) { group in
                Button {
                    onSelect(group.id)
                } label: {
                    Label(
                        group.name,
                        systemImage: group.id == currentGroupID ? "checkmark" : group.symbol
                    )
                }
                .disabled(group.id == currentGroupID)
            }
        }
    }
}
