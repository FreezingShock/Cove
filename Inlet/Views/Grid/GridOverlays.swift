//
//  GridOverlays.swift
//  Inlet
//
//  The Hidden apps list, shown in a popover from the header, and the Undo
//  toast that follows a hide. Restore and Undo use the system glass button
//  style, so they get the native hover, press and focus behavior.
//

import SwiftUI

/// The list of hidden apps, each with a Restore button. The popover that
/// holds it supplies the window chrome, so this view draws no background.
struct HiddenAppsPanel: View {
    struct Row: Identifiable {
        let id: String
        let name: String
    }

    let rows: [Row]
    let onRestore: (String) -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: InletSpace.xs) {
            Text("Hidden apps")
                .font(.headline)
                .foregroundStyle(InletText.secondary(contrast))

            if rows.isEmpty {
                Text("No hidden apps.")
                    .font(.callout)
                    .foregroundStyle(InletText.secondary(contrast))
            }

            ForEach(rows) { row in
                HStack(spacing: InletSpace.m) {
                    Text(row.name)
                        .font(.body)
                        .lineLimit(1)
                    Spacer(minLength: InletSpace.s)
                    Button("Restore") { onRestore(row.id) }
                        .buttonStyle(InletAccentButtonStyle())
                }
            }
        }
        .padding(InletSpace.m)
        .frame(width: 280, alignment: .leading)
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
