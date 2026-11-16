//
//  SearchPanel.swift
//  Inlet
//
//  The search field, plus a results panel that grows out of it while you
//  type (T3.4). The field and panel share one GlassEffectContainer and one
//  glass ID, so they read as one liquid shape: the capsule melts into the
//  panel with the `morph` spring. Reduce Motion crossfades instead.
//

import SwiftUI

struct SearchPanel: View {
    /// The text in the field. Empty means "show everything".
    @Binding var query: String
    /// Keyboard focus for the field, owned by AppGridView so it can move
    /// focus between the field and the grid.
    var isFocused: FocusState<Bool>.Binding
    /// The best match, or nil. Shown as the top-hit row while typing.
    let topHit: AppItem?
    /// How many apps match the query, for the row's caption.
    let matchCount: Int
    /// Spotlight file matches for the query, best first. Shown under the top hit.
    let files: [FileItem]
    /// Return in the field (or a tap on the top-hit row) opens the top hit.
    let onOpenTopHit: () -> Void
    /// A tap on a file row opens that file.
    let onOpenFile: (FileItem) -> Void
    /// Cmd+Return in the field reveals the top file in Finder.
    let onRevealFile: (FileItem) -> Void
    /// Down arrow in the field moves focus into the grid.
    let onDown: () -> KeyPress.Result

    @Environment(\.colorSchemeContrast) private var contrast
    /// Namespace for the shared glass ID. A second glass view with the same
    /// ID can later take over this shape as a true morph.
    @Namespace private var glassNamespace

    private var isSearching: Bool { !AppSearch.normalize(query).isEmpty }
    /// The panel opens when there is an app or a file to show.
    private var isExpanded: Bool { isSearching && (topHit != nil || !files.isEmpty) }
    /// The field widens a little when it has focus, per the spec (500 -> 560).
    private var width: CGFloat {
        isFocused.wrappedValue ? InletSize.searchFieldFocusedWidth : InletSize.searchField.width
    }

    var body: some View {
        GlassEffectContainer(spacing: InletSpace.xxl) {
            VStack(spacing: 0) {
                field

                if isExpanded {
                    if let topHit {
                        topHitRow(topHit)
                            .padding(.horizontal, InletSpace.s)
                            .padding(.bottom, InletSpace.s)
                    }
                    if !files.isEmpty {
                        fileRows
                            .padding(.horizontal, InletSpace.s)
                            .padding(.bottom, InletSpace.s)
                    }
                }
            }
            .frame(width: width)
            // Capsule when collapsed, a 32 pt panel when it has results.
            .modifier(SearchSurface(
                cornerRadius: isExpanded ? InletRadius.panel : InletSize.searchField.height / 2,
                tint: isExpanded ? InletColor.gFill : InletColor.cFill,
                interactive: !isExpanded
            ))
            .glassEffectID("search", in: glassNamespace)
            .inletAnimation(.inletMorph, value: isExpanded)
            .inletAnimation(.inletMorph, value: width)
        }
    }

    // MARK: Field

    private var field: some View {
        HStack(spacing: InletSpace.s) {
            Image(systemName: "magnifyingglass")
                .font(InletFont.search)
                .foregroundStyle(InletText.tertiary(contrast))

            TextField(
                "Search apps",
                text: $query,
                prompt: Text("Search apps").foregroundStyle(InletText.tertiary(contrast))
            )
            .textFieldStyle(.plain)
            .font(InletFont.search)
            .foregroundStyle(InletColor.text)
            .focused(isFocused)
            .onSubmit(onOpenTopHit)                 // Return opens the top hit
            .onKeyPress(.downArrow) { onDown() }   // Down moves into the grid
            .onKeyPress(.return, phases: .down) { press in
                // Cmd+Return reveals the top file match in Finder. Plain Return
                // is left to onSubmit above.
                guard press.modifiers.contains(.command), let first = files.first else {
                    return .ignored
                }
                onRevealFile(first)
                return .handled
            }
            .accessibilityLabel("Search apps")
        }
        .padding(.horizontal, InletSpace.l)
        .frame(height: InletSize.searchField.height)
    }

    // MARK: Files

    /// The file matches from Spotlight, under a small "Files" caption with a
    /// hint for Cmd+Return. Each row is a button, so Tab and VoiceOver reach it.
    /// Tapping opens the file.
    private var fileRows: some View {
        VStack(alignment: .leading, spacing: InletSpace.xxs) {
            HStack(spacing: InletSpace.s) {
                Text("Files")
                Spacer(minLength: 0)
                Text("⌘Return reveals top file")
            }
            .font(InletFont.caption)
            .foregroundStyle(InletText.secondary(contrast))
            .padding(.horizontal, InletSpace.m)
            .padding(.top, InletSpace.xs)

            ForEach(files) { file in
                Button {
                    onOpenFile(file)
                } label: {
                    FileResultRow(item: file)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Top hit

    private func topHitRow(_ app: AppItem) -> some View {
        HStack(spacing: InletSpace.m) {
            Image(nsImage: IconCache.shared.icon(for: app))
                .resizable()
                .interpolation(.high)
                .frame(width: InletSize.rowIcon, height: InletSize.rowIcon)

            VStack(alignment: .leading, spacing: InletSpace.xxs) {
                Text(app.name)
                    .font(InletFont.headline)
                    .foregroundStyle(InletColor.text)
                    .lineLimit(1)
                Text("\(matchCount) matches · Return to open")
                    .font(InletFont.caption)
                    .foregroundStyle(InletText.secondary(contrast))
            }

            Spacer(minLength: 0)
        }
        .padding(InletSpace.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: InletRadius.row, style: .continuous)
                .fill(InletColor.hover)
        )
        .contentShape(RoundedRectangle(cornerRadius: InletRadius.row, style: .continuous))
        .onTapGesture(perform: onOpenTopHit)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Open \(app.name)")
    }
}

/// Glass for the search surface. Under Reduce Transparency it becomes a
/// solid fill with a rim, the same fallback the theme uses everywhere.
private struct SearchSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let tint: Color
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(shape.fill(InletColor.gSolid))
                .overlay(shape.strokeBorder(InletColor.gEdge, lineWidth: 1))
        } else {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        }
    }
}
