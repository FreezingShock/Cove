//
//  GridOverlays.swift
//  Cove
//
//  The panels that float over the grid: the Hidden apps list and the Undo
//  toast that follows a hide. Both use the Cove glass and tokens.
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
        VStack(alignment: .leading, spacing: CoveSpace.xxs) {
            Text("Hidden apps")
                .font(CoveFont.section)
                .foregroundStyle(CoveText.secondary(contrast))
                .padding(.horizontal, CoveSpace.s)
                .padding(.vertical, CoveSpace.s)

            ForEach(rows) { row in
                HStack(spacing: CoveSpace.m) {
                    Text(row.name)
                        .font(CoveFont.subhead)
                        .foregroundStyle(CoveColor.text)
                        .lineLimit(1)
                    Spacer(minLength: CoveSpace.s)
                    Button("Restore") { onRestore(row.id) }
                        .buttonStyle(.plain)
                        .font(CoveFont.section)
                        .foregroundStyle(CoveColor.accentInk)
                        .padding(.horizontal, CoveSpace.l)
                        .padding(.vertical, CoveSpace.s)
                        .background(Capsule().fill(CoveColor.accent))
                        .contentShape(Capsule())
                }
                .padding(.horizontal, CoveSpace.s)
                .padding(.vertical, CoveSpace.xs)
            }
        }
        .padding(CoveSpace.s)
        .frame(width: 280, alignment: .leading)
        .covePanelGlass(cornerRadius: CoveRadius.panel)
        .shadow(color: CoveColor.gShadow, radius: 18, y: 8)
    }
}

/// A short message with an Undo button, shown after an app is hidden.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: CoveSpace.l) {
            Text(message)
                .font(CoveFont.subhead)
                .foregroundStyle(CoveColor.text)
                .lineLimit(1)

            Button("Undo", action: onUndo)
                .buttonStyle(.plain)
                .font(CoveFont.section)
                .foregroundStyle(CoveColor.accentInk)
                .padding(.horizontal, CoveSpace.l)
                .padding(.vertical, CoveSpace.s)
                .background(Capsule().fill(CoveColor.accent))
                .contentShape(Capsule())
        }
        .padding(.leading, CoveSpace.l)
        .padding(.trailing, CoveSpace.s)
        .padding(.vertical, CoveSpace.s)
        .coveCapsuleGlass(interactive: false)
        .shadow(color: CoveColor.gShadow, radius: 16, y: 6)
    }
}
