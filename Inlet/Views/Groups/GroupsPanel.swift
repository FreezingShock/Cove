//
//  GroupsPanel.swift
//  Inlet
//
//  The panel that manages groups: add one, rename it in place, pick a color
//  and an icon, move it up or down the bar, or delete it. It only shows the
//  groups and reports what the user chose. AppGridView saves the change.
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
    /// The group whose icon grid is open, if any.
    @State private var iconPickerID: String?
    /// The group whose Delete button is showing. Deleting takes two taps.
    @State private var armedDeleteID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: InletSpace.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Groups")
                    .font(InletFont.section)
                    .foregroundStyle(InletText.secondary(contrast))
                Spacer()
                Button(action: onAdd) {
                    Label("Add group", systemImage: "plus")
                        .font(InletFont.section)
                        .foregroundStyle(InletColor.accentInk)
                        .padding(.horizontal, InletSpace.m)
                        .padding(.vertical, InletSpace.xs)
                        .background(Capsule().fill(InletColor.accent))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, InletSpace.s)
            .padding(.top, InletSpace.s)

            ScrollView {
                VStack(spacing: InletSpace.xs) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        groupRow(group, index: index)
                    }
                }
            }
            .frame(maxHeight: 440)

            Text("Each app is in one group. Right-click an icon to move it.")
                .font(InletFont.caption)
                .foregroundStyle(InletText.secondary(contrast))
                .padding(.horizontal, InletSpace.s)
                .padding(.bottom, InletSpace.xs)
        }
        .padding(InletSpace.xs)
        .frame(width: 340, alignment: .leading)
        .inletPanelGlass(cornerRadius: InletRadius.panel)
        .shadow(color: InletColor.gShadow, radius: 18, y: 8)
    }

    // MARK: - Rows

    private func groupRow(_ group: AppGroup, index: Int) -> some View {
        VStack(alignment: .leading, spacing: InletSpace.xs) {
            HStack(spacing: InletSpace.xs) {
                Button {
                    iconPickerID = iconPickerID == group.id ? nil : group.id
                } label: {
                    Image(systemName: group.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(group.color.color)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(InletColor.hover))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Icon for \(group.name)")
                .accessibilityHint("Shows the icon choices")

                GroupNameField(name: group.name) { newName in
                    onRename(group.id, newName)
                }

                iconButton("arrow.up", label: "Move \(group.name) up", enabled: index > 0) {
                    onMove(group.id, index - 1)
                }
                iconButton("arrow.down", label: "Move \(group.name) down", enabled: index < groups.count - 1) {
                    onMove(group.id, index + 1)
                }

                if armedDeleteID == group.id {
                    Button("Delete") {
                        armedDeleteID = nil
                        onDelete(group.id)
                    }
                    .buttonStyle(.plain)
                    .font(InletFont.section)
                    .foregroundStyle(.white)
                    .padding(.horizontal, InletSpace.s)
                    .padding(.vertical, InletSpace.xs)
                    .background(Capsule().fill(Color.red))
                    .contentShape(Capsule())
                } else {
                    iconButton("trash", label: "Delete \(group.name)", enabled: groups.count > 1) {
                        armedDeleteID = group.id
                    }
                }
            }

            colorRow(group)

            if iconPickerID == group.id {
                iconGrid(group)
            }

            if armedDeleteID == group.id {
                Text("Its apps move to \(fallbackName(excluding: group.id)).")
                    .font(InletFont.caption)
                    .foregroundStyle(InletText.secondary(contrast))
                    .padding(.leading, 36)
            }
        }
        .padding(InletSpace.s)
        .background(
            RoundedRectangle(cornerRadius: InletRadius.sm, style: .continuous)
                .fill(InletColor.hover)
        )
    }

    private func colorRow(_ group: AppGroup) -> some View {
        HStack(spacing: InletSpace.xs) {
            ForEach(GroupColor.allCases, id: \.self) { color in
                Button {
                    onRecolor(group.id, color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 16, height: 16)
                        .overlay {
                            Circle()
                                .strokeBorder(InletColor.text, lineWidth: 2)
                                .frame(width: 22, height: 22)
                                .opacity(group.color == color ? 1 : 0)
                        }
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(color.label) color")
                .accessibilityAddTraits(group.color == color ? .isSelected : [])
            }
        }
        .padding(.leading, 36)
    }

    private func iconGrid(_ group: AppGroup) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(38), spacing: InletSpace.xs), count: 6),
            alignment: .leading,
            spacing: InletSpace.xs
        ) {
            ForEach(AppGroup.symbolChoices, id: \.self) { symbol in
                iconChoice(symbol, for: group)
            }
        }
        .padding(.leading, 36)
    }

    private func iconChoice(_ symbol: String, for group: AppGroup) -> some View {
        let chosen = symbol == group.symbol
        return Button {
            onSetSymbol(group.id, symbol)
            iconPickerID = nil
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(chosen ? group.color.color : InletColor.text)
                .frame(width: 38, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: InletRadius.xs, style: .continuous)
                        .fill(chosen ? InletColor.accentSoft : InletColor.hover)
                )
        }
        .buttonStyle(.plain)
        .help(AppGroup.name(forSymbol: symbol))
        .accessibilityLabel("\(AppGroup.name(forSymbol: symbol)) icon")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private func iconButton(
        _ symbol: String,
        label: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(InletColor.text)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
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
            .font(InletFont.subhead)
            .foregroundStyle(InletColor.text)
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
