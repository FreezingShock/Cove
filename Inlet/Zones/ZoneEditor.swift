//
//  ZoneEditor.swift
//  Inlet
//
//  The sheet for adding, resizing, moving or deleting a zone. It opens from
//  Edit mode on the grid.
//

import SwiftUI

/// What the grid hands the editor when a sheet opens. `isNew` decides
/// whether Delete is offered.
struct ZoneDraft: Identifiable {
    let zone: GridZone
    let isNew: Bool

    var id: String { zone.id }
}

struct ZoneEditor: View {
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    /// Columns in the grid. Caps the width and the column position.
    let columns: Int
    /// The groups on the bar. A zone can hold any of them.
    let groups: [AppGroup]
    /// Every other zone, so the editor can say when this one overlaps.
    let others: [GridZone]
    /// Saves the zone. Returns false if it doesn't fit.
    let onSave: (GridZone) -> Bool
    /// Removes the zone. Only offered when `isNew` is false.
    let onDelete: () -> Void

    @State private var draft: GridZone

    init(
        zone: GridZone,
        isNew: Bool,
        columns: Int,
        groups: [AppGroup],
        others: [GridZone],
        onSave: @escaping (GridZone) -> Bool,
        onDelete: @escaping () -> Void
    ) {
        self.isNew = isNew
        self.columns = columns
        self.groups = groups
        self.others = others
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: zone.fitted(columns: columns))
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var fits: Bool {
        ZoneLayout.fits(draft, columns: columns, among: others)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $draft.name)
            }

            Section {
                if groups.isEmpty {
                    Text("No groups yet. Add one from the group bar.")
                        .foregroundStyle(.secondary)
                }
                ForEach(groups) { group in
                    Toggle(group.name, isOn: holds(group.id))
                }
            } header: {
                Text("Holds these groups")
            } footer: {
                Text("An app appears in the first zone, in order, that holds its group.")
            }

            Section("Size and place") {
                Stepper("Width: \(draft.width) of \(columns) columns", value: $draft.width, in: 1...columns)
                Stepper("Height: \(draft.height) rows", value: $draft.height, in: 1...GridZone.maxHeight)
                Stepper(
                    "Starts at column \(draft.column + 1)",
                    value: $draft.column,
                    in: 0...max(0, columns - draft.width)
                )
                Stepper("Starts at row \(draft.row + 1)", value: $draft.row, in: 0...GridZone.maxRow)
            }

            if !fits {
                Section {
                    Label("This zone runs past the grid or overlaps another zone.", systemImage: "exclamationmark.triangle")
                }
            }

            if !isNew {
                Section {
                    Button("Delete Zone", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
        .onChange(of: draft.width) { _, width in
            // Keep the start column inside the grid when the zone gets wider.
            draft.column = min(draft.column, max(0, columns - width))
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!fits || trimmedName.isEmpty)
            }
            .padding(InletSpace.l)
        }
    }

    private func holds(_ groupID: String) -> Binding<Bool> {
        Binding(
            get: { draft.groupIDs.contains(groupID) },
            set: { isOn in
                draft.groupIDs.removeAll { $0 == groupID }
                if isOn { draft.groupIDs.append(groupID) }
            }
        )
    }

    private func save() {
        var final = draft
        final.name = trimmedName.isEmpty ? "Zone" : trimmedName
        if onSave(final) { dismiss() }
    }
}
