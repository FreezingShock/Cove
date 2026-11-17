//
//  GroupsPanel.swift
//  Inlet
//
//  The Groups popover, opened from the Groups button in the grid header. It
//  adds a group, renames one in place, picks a color from a menu, picks an
//  icon from a popover, moves a group up or down the bar, and deletes one
//  after an alert asks. It only reports what the user chose. AppGridView
//  saves the change.
//
//  Controls are the stock macOS ones: a pop-up menu for color, a popover for
//  the symbol grid, a destructive alert, and borderless icon buttons that get
//  the system hover, press and keyboard focus for free.
//

import SwiftUI

struct GroupsPanel: View {
    /// The groups, in bar order.
    let groups: [AppGroup]
    let onAdd: () -> Void
    let onRename: (String, String) -> Void
    let onRecolor: (String, GroupColor) -> Void
    let onSetSymbol: (String, String) -> Void
    /// Moves a group to a new index on the bar.
    let onMove: (String, Int) -> Void
    let onDelete: (String) -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    /// The group whose icon popover is open, if any.
    @State private var iconPickerID: String?
    /// The group the user asked to delete. Setting it shows the alert.
    @State private var pendingDelete: AppGroup?

    var body: some View {
        VStack(alignment: .leading, spacing: InletSpace.s) {
            HStack(alignment: .center) {
                Text("Groups")
                    .font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Label("Add Group", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .tint(InletColor.accent)
                .controlSize(.small)
            }
            .padding(.horizontal, InletSpace.xs)

            ScrollView {
                VStack(spacing: InletSpace.xs) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        groupRow(group, index: index)
                    }
                }
            }
            .frame(maxHeight: 420)

            Text("Each app is in one group. Right-click an icon to move it.")
                .font(.caption)
                .foregroundStyle(InletText.secondary(contrast))
                .padding(.horizontal, InletSpace.xs)
        }
        .padding(InletSpace.m)
        .frame(width: 360, alignment: .leading)
        .alert(
            alertTitle,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { group in
            Button("Delete", role: .destructive) {
                onDelete(group.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { group in
            Text("Its apps move to \(fallbackName(excluding: group.id)).")
        }
    }

    private var alertTitle: String {
        if let pendingDelete {
            return "Delete “\(pendingDelete.name)”?"
        }
        return "Delete group?"
    }

    // MARK: - Rows

    private func groupRow(_ group: AppGroup, index: Int) -> some View {
        HStack(spacing: InletSpace.xs) {
            // The icon opens a popover with the symbol choices.
            Button {
                iconPickerID = group.id
            } label: {
                Image(systemName: group.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(group.color.color)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .help("Choose an icon")
            .accessibilityLabel("Icon for \(group.name)")
            .accessibilityHint("Shows the icon choices")
            .popover(isPresented: iconPopoverBinding(for: group.id), arrowEdge: .trailing) {
                iconGrid(group)
            }

            GroupNameField(name: group.name) { newName in
                onRename(group.id, newName)
            }

            // The color is a pop-up menu. The dot shows the current choice.
            Circle()
                .fill(group.color.color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Picker(
                "Color",
                selection: Binding(
                    get: { group.color },
                    set: { onRecolor(group.id, $0) }
                )
            ) {
                ForEach(GroupColor.allCases, id: \.self) { color in
                    Text(color.label).tag(color)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Spacer(minLength: 0)

            iconButton("arrow.up", label: "Move \(group.name) up", help: "Move up", enabled: index > 0) {
                onMove(group.id, index - 1)
            }
            iconButton("arrow.down", label: "Move \(group.name) down", help: "Move down", enabled: index < groups.count - 1) {
                onMove(group.id, index + 1)
            }
            iconButton("trash", label: "Delete \(group.name)", help: "Delete group", enabled: groups.count > 1, role: .destructive) {
                pendingDelete = group
            }
        }
        .padding(.horizontal, InletSpace.s)
        .padding(.vertical, InletSpace.xs)
        .background(
            RoundedRectangle(cornerRadius: InletRadius.sm, style: .continuous)
                .fill(.quaternary)
        )
    }

    private func iconPopoverBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { iconPickerID == id },
            set: { if !$0 { iconPickerID = nil } }
        )
    }

    private func iconGrid(_ group: AppGroup) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(38), spacing: 6), count: 6),
            alignment: .center,
            spacing: 6
        ) {
            ForEach(AppGroup.symbolChoices, id: \.self) { symbol in
                iconChoice(symbol, for: group)
            }
        }
        .padding(12)
        .frame(width: 290)
    }

    private func iconChoice(_ symbol: String, for group: AppGroup) -> some View {
        let chosen = symbol == group.symbol
        return Button {
            onSetSymbol(group.id, symbol)
            iconPickerID = nil
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(chosen ? group.color.color : .primary)
                .frame(width: 38, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: InletRadius.xs, style: .continuous)
                        .fill(chosen ? Color.accentColor.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.borderless)
        .help(symbol)
        .accessibilityLabel("Icon \(symbol)")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private func iconButton(
        _ symbol: String,
        label: String,
        help: String,
        enabled: Bool = true,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(label)
    }

    /// The group that takes over this group's apps when it is deleted. Matches
    /// GridLayout.deleteGroup: the Other group if there is one, else the first.
    private func fallbackName(excluding id: String) -> String {
        let others = groups.filter { $0.id != id }
        let target = others.first(where: { $0.suggestedCategory == .other }) ?? others.first
        return target?.name ?? "another group"
    }
}

/// A group's name, edited in place. The change is saved on Return or when the
/// field loses focus. An empty name is reverted.
private struct GroupNameField: View {
    let name: String
    let onCommit: (String) -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(name: String, onCommit: @escaping (String) -> Void) {
        self.name = name
        self.onCommit = onCommit
        _text = State(initialValue: name)
    }

    var body: some View {
        TextField("Group name", text: $text)
            .textFieldStyle(.plain)
            .font(.body)
            .lineLimit(1)
            .focused($isFocused)
            .onSubmit { commit() }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onChange(of: name) { _, newName in
                text = newName
            }
    }

    private func commit() {
        let clean = AppGroup.cleanName(text)
        if let clean, clean != name {
            onCommit(clean)
        }
        text = clean ?? name
    }
}
