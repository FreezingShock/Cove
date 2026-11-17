//
//  GridOverlays.swift
//  Inlet
//
//  The panels that float over the grid: the Hidden apps list and the Undo
//  toast that follows a hide. Both use the Inlet glass and tokens.
//

import SwiftUI

/// The list of hidden apps, each with a Restore button.
struct HiddenAppsPanel: View {
    struct Row: Identifiable {
        let id: String
        let name: String
    }

    let rows: [Row]
    let onRestore: (String) -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: InletSpace.xxs) {
            Text("Hidden apps")
                .font(InletFont.section)
                .foregroundStyle(InletText.secondary(contrast))
                .padding(.horizontal, InletSpace.s)
                .padding(.vertical, InletSpace.s)

            ForEach(rows) { row in
                HStack(spacing: InletSpace.m) {
                    Text(row.name)
                        .font(InletFont.subhead)
                        .foregroundStyle(InletColor.text)
                        .lineLimit(1)
                    Spacer(minLength: InletSpace.s)
                    Button("Restore") { onRestore(row.id) }
                        .buttonStyle(InletAccentButtonStyle())
                }
                .padding(.horizontal, InletSpace.s)
                .padding(.vertical, InletSpace.xs)
            }
        }
        .padding(InletSpace.s)
        .frame(width: 280, alignment: .leading)
        .inletPanelGlass(cornerRadius: InletRadius.panel)
        .shadow(color: InletColor.gShadow, radius: 18, y: 8)
    }
}

/// A short message with an Undo button, shown after an app is hidden.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: InletSpace.l) {
            Text(message)
                .font(InletFont.subhead)
                .foregroundStyle(InletColor.text)
                .lineLimit(1)

            Button("Undo", action: onUndo)
                .buttonStyle(InletAccentButtonStyle())
        }
        .padding(.leading, InletSpace.l)
        .padding(.trailing, InletSpace.s)
        .padding(.vertical, InletSpace.s)
        .inletCapsuleGlass(interactive: false)
        .shadow(color: InletColor.gShadow, radius: 16, y: 6)
    }
}
