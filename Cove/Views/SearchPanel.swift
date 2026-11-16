//
//  SearchPanel.swift
//  Cove
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
    /// Return in the field (or a tap on the top-hit row) opens the top hit.
    let onOpenTopHit: () -> Void
    /// Down arrow in the field moves focus into the grid.
    let onDown: () -> KeyPress.Result

    @Environment(\.colorSchemeContrast) private var contrast
    /// Namespace for the shared glass ID. A second glass view with the same
    /// ID can later take over this shape as a true morph.
    @Namespace private var glassNamespace

    private var isSearching: Bool { !AppSearch.normalize(query).isEmpty }
    /// The panel only opens when there is a top hit to show.
    private var isExpanded: Bool { isSearching && topHit != nil }
    /// The field widens a little when it has focus, per the spec (500 -> 560).
    private var width: CGFloat {
        isFocused.wrappedValue ? CoveSize.searchFieldFocusedWidth : CoveSize.searchField.width
    }

    var body: some View {
        GlassEffectContainer(spacing: CoveSpace.xxl) {
            VStack(spacing: 0) {
                field

                if let topHit, isExpanded {
                    topHitRow(topHit)
                        .padding(.horizontal, CoveSpace.s)
                        .padding(.bottom, CoveSpace.s)
                    // HOOK (T3.2, Spotlight file results): file rows go here,
                    // below the top hit, as their own section.
                }
            }
            .frame(width: width)
            // Capsule when collapsed, a 32 pt panel when it has results.
            .modifier(SearchSurface(
                cornerRadius: isExpanded ? CoveRadius.panel : CoveSize.searchField.height / 2,
                tint: isExpanded ? CoveColor.gFill : CoveColor.cFill,
                interactive: !isExpanded
            ))
            .glassEffectID("search", in: glassNamespace)
            .coveAnimation(.coveMorph, value: isExpanded)
            .coveAnimation(.coveMorph, value: width)
        }
    }

    // MARK: Field

    private var field: some View {
        HStack(spacing: CoveSpace.s) {
            Image(systemName: "magnifyingglass")
                .font(CoveFont.search)
                .foregroundStyle(CoveText.tertiary(contrast))

            TextField(
                "Search apps",
                text: $query,
                prompt: Text("Search apps").foregroundStyle(CoveText.tertiary(contrast))
            )
            .textFieldStyle(.plain)
            .font(CoveFont.search)
            .foregroundStyle(CoveColor.text)
            .focused(isFocused)
            .onSubmit(onOpenTopHit)                 // Return opens the top hit
            .onKeyPress(.downArrow) { onDown() }   // Down moves into the grid
            .accessibilityLabel("Search apps")
        }
        .padding(.horizontal, CoveSpace.l)
        .frame(height: CoveSize.searchField.height)
    }

    // MARK: Top hit

    private func topHitRow(_ app: AppItem) -> some View {
        HStack(spacing: CoveSpace.m) {
            Image(nsImage: IconCache.shared.icon(for: app))
                .resizable()
                .interpolation(.high)
                .frame(width: CoveSize.rowIcon, height: CoveSize.rowIcon)

            VStack(alignment: .leading, spacing: CoveSpace.xxs) {
                Text(app.name)
                    .font(CoveFont.headline)
                    .foregroundStyle(CoveColor.text)
                    .lineLimit(1)
                Text("\(matchCount) matches · Return to open")
                    .font(CoveFont.caption)
                    .foregroundStyle(CoveText.secondary(contrast))
            }

            Spacer(minLength: 0)
        }
        .padding(CoveSpace.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous)
                .fill(CoveColor.hover)
        )
        .contentShape(RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous))
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
                .background(shape.fill(CoveColor.gSolid))
                .overlay(shape.strokeBorder(CoveColor.gEdge, lineWidth: 1))
        } else {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        }
    }
}
