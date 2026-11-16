//
//  GridOverlays.swift
//  Cove
//
//  The panels that float over the grid: the Hidden apps list and the Undo
//  toast that follows a hide.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Hidden apps")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Text(row.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button("Restore") { onRestore(row.id) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.base)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.aqua))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .padding(8)
        .frame(width: 280, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }
}

/// A short message with an Undo button, shown after an app is hidden.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)

            Button("Undo", action: onUndo)
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.base)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.aqua))
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
    }
}
