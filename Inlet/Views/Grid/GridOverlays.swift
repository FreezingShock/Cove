//
//  GridOverlays.swift
//  Inlet
//
//  The panels that float over the grid: the Hidden apps list, the Undo toast
//  that follows a hide, and the open folder. All use Inlet glass and tokens.
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
                        .buttonStyle(.plain)
                        .font(InletFont.section)
                        .foregroundStyle(InletColor.accentInk)
                        .padding(.horizontal, InletSpace.l)
                        .padding(.vertical, InletSpace.s)
                        .background(Capsule().fill(InletColor.accent))
                        .contentShape(Capsule())
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
                .buttonStyle(.plain)
                .font(InletFont.section)
                .foregroundStyle(InletColor.accentInk)
                .padding(.horizontal, InletSpace.l)
                .padding(.vertical, InletSpace.s)
                .background(Capsule().fill(InletColor.accent))
                .contentShape(Capsule())
        }
        .padding(.leading, InletSpace.l)
        .padding(.trailing, InletSpace.s)
        .padding(.vertical, InletSpace.s)
        .inletCapsuleGlass(interactive: false)
        .shadow(color: InletColor.gShadow, radius: 16, y: 6)
    }
}

/// The open folder: an editable name, its apps, and drag-out.
///
/// Tapping an app launches it. Dragging an app and letting go outside the
/// panel takes it out of the folder; it lands on the grid right after the
/// folder. The panel's own frame is measured in `FolderPanel.coordinateSpace`,
/// which the caller must name on the view that holds the panel.
struct FolderPanel: View {
    /// Name of the coordinate space the caller provides around the panel.
    static let coordinateSpace = "folderSpace"
    /// Movement under this many points is a tap, not a drag.
    private static let tapSlop: CGFloat = 6
    /// Longest folder name, in characters.
    private static let maxNameLength = 32

    let folder: GridFolder
    /// The folder's apps, in order. Apps that are not installed are already left out.
    let apps: [AppItem]
    let onRename: (String) -> Void
    let onLaunch: (AppItem) -> Void
    let onTakeOut: (AppItem) -> Void
    let onClose: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var nameFocused: Bool
    @State private var name = ""
    /// The panel's frame in `coordinateSpace`, measured after each layout.
    @State private var panelFrame: CGRect = .zero
    /// The app being dragged, and how far it has moved.
    @State private var drag: AppDrag?

    private struct AppDrag: Equatable {
        var appID: String
        var offset: CGSize
    }

    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: InletSpace.xs),
        count: 3
    )

    var body: some View {
        VStack(spacing: 0) {
            header

            LazyVGrid(columns: Self.columns, spacing: InletSpace.xs) {
                ForEach(apps) { app in
                    cell(app)
                }
            }

            Text("Drag an app out to take it out of the folder.")
                .font(InletFont.caption)
                .foregroundStyle(InletText.tertiary(contrast))
                .padding(.top, InletSpace.s)
        }
        .padding(InletSpace.panelPad)
        .frame(width: 452)
        .inletPanelGlass(cornerRadius: InletRadius.panel)
        .shadow(color: InletColor.gShadow, radius: 40, y: 16)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.coordinateSpace))
        } action: { frame in
            panelFrame = frame
        }
        .onAppear { name = folder.name }
        // Leaving the folder saves a rename, whatever closed it.
        .onDisappear { commitName() }
        .onChange(of: name) { _, newName in
            if newName.count > Self.maxNameLength {
                name = String(newName.prefix(Self.maxNameLength))
            }
        }
        .onChange(of: nameFocused) { _, focused in
            if !focused { commitName() }
        }
    }

    private var header: some View {
        HStack(spacing: InletSpace.m) {
            TextField("Folder name", text: $name)
                .textFieldStyle(.plain)
                .font(InletFont.title)
                .tracking(InletTracking.title)
                .foregroundStyle(InletColor.text)
                .focused($nameFocused)
                .onSubmit { commitName() }
                .padding(.horizontal, InletSpace.s)
                .padding(.vertical, InletSpace.xs)
                .background(
                    RoundedRectangle(cornerRadius: InletRadius.sm, style: .continuous)
                        .fill(nameFocused ? InletColor.field : Color.clear)
                )

            Spacer(minLength: InletSpace.s)

            Text("\(apps.count) apps")
                .font(InletFont.caption)
                .foregroundStyle(InletText.secondary(contrast))

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(InletColor.text)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(InletColor.field))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close folder")
        }
        .padding(.horizontal, InletSpace.xs)
        .padding(.bottom, InletSpace.s)
    }

    /// One app in the folder. A short touch launches it; a longer drag that
    /// ends outside the panel takes it out.
    private func cell(_ app: AppItem) -> some View {
        let lifted = drag?.appID == app.id
        let offset = lifted ? (drag?.offset ?? .zero) : .zero

        return VStack(spacing: InletSpace.s) {
            Image(nsImage: IconCache.shared.icon(for: app))
                .resizable()
                .interpolation(.high)
                .frame(width: InletSize.quickIcon, height: InletSize.quickIcon)

            Text(app.name)
                .font(InletFont.iconLabel)
                .foregroundStyle(InletColor.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, InletSpace.s)
        .frame(maxWidth: .infinity)
        .scaleEffect(lifted ? 1.08 : 1)
        .shadow(color: InletColor.gShadow.opacity(lifted ? 1 : 0), radius: 12, y: 8)
        .offset(offset)
        .zIndex(lifted ? 1 : 0)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
                .onChanged { value in
                    drag = AppDrag(appID: app.id, offset: value.translation)
                }
                .onEnded { value in
                    drag = nil
                    let moved = hypot(value.translation.width, value.translation.height)
                    if moved < Self.tapSlop {
                        onLaunch(app)
                    } else if !panelFrame.contains(value.location) {
                        onTakeOut(app)
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { onLaunch(app) }
        .accessibilityAction(named: Text("Take out of folder")) { onTakeOut(app) }
    }

    /// Saves the name if it changed. An empty name keeps the old one.
    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            name = folder.name
            return
        }
        if trimmed != folder.name {
            onRename(trimmed)
        }
    }
}
