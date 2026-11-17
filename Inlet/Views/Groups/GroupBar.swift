//
//  GroupBar.swift
//  Inlet
//
//  The capsule above the grid: All, then one segment per group. Tap a group
//  to filter the grid to it; tap the selected group again, or All, to show
//  every app. When the groups are too wide for the window, the bar scrolls
//  sideways. Colors and glass come from InletTheme, so Light, Dark, Increase
//  Contrast and Reduce Transparency all apply here too.
//

import SwiftUI

struct GroupBar: View {
    /// The groups, in bar order.
    let groups: [AppGroup]
    /// The id of the group the grid is filtered to. Nil shows every app.
    @Binding var selection: String?
    /// True while the search field has text. The bar fades out so the results
    /// can take its place. The search view owns this flag.
    var isFaded = false

    /// Secondary text switches to full text under Increase Contrast.
    @Environment(\.colorSchemeContrast) private var contrast

    /// Segment height. The bar adds 3 pt of padding on each side.
    private let segmentHeight: CGFloat = 30

    var body: some View {
        // Fits its content when it can, and scrolls when it can't.
        ViewThatFits(in: .horizontal) {
            row
            ScrollView(.horizontal, showsIndicators: false) {
                row
            }
        }
        .padding(3)
        .inletCapsuleGlass(interactive: true)
        .opacity(isFaded ? 0 : 1)
        .allowsHitTesting(!isFaded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Groups")
        .accessibilityHidden(isFaded)
        .inletAnimation(.inletFade, value: isFaded)
        .inletAnimation(.inletSnap, value: selection)
    }

    private var row: some View {
        HStack(spacing: InletSpace.xxs) {
            segment(title: "All", symbol: nil, color: nil, isSelected: selection == nil) {
                selection = nil
            }
            ForEach(groups) { group in
                segment(
                    title: group.name,
                    symbol: group.symbol,
                    color: group.color.color,
                    isSelected: selection == group.id
                ) {
                    // Tapping the selected group clears the filter, same as All.
                    selection = selection == group.id ? nil : group.id
                }
            }
        }
    }

    private func segment(
        title: String,
        symbol: String?,
        color: Color?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: InletSpace.xxs) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color ?? InletColor.text)
                }
                Text(title)
                    .font(InletFont.label)
                    .textCase(.uppercase)
                    .tracking(InletTracking.label)
                    .foregroundStyle(isSelected ? InletColor.text : InletText.secondary(contrast))
                    .lineLimit(1)
            }
            .padding(.horizontal, InletSpace.l - InletSpace.xxs)
            .frame(height: segmentHeight)
            .background {
                if isSelected {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [InletColor.selTop, InletColor.selBot],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .overlay(Capsule().strokeBorder(InletColor.selRing, lineWidth: 1))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection: String? = "create"
    return GroupBar(groups: AppGroup.presets, selection: $selection)
        .padding(40)
        .background(InletColor.base)
}
