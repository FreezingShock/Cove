//
//  CategoryBar.swift
//  Inlet
//
//  The capsule above the grid: All, then the six category buckets. Tap a
//  bucket to filter the grid to it; tap the selected bucket again, or All,
//  to show every app.
//  Colors and glass come from InletTheme, so Light, Dark, Increase Contrast
//  and Reduce Transparency all apply here too.
//

import SwiftUI

struct CategoryBar: View {
    /// The bucket the grid is filtered to. Nil shows every app.
    @Binding var selection: AppCategory?

    /// Set this to true while the search field has text. The bar fades out
    /// so the results can take its place. The search view owns this flag.
    var isFaded = false

    /// Secondary text switches to full text under Increase Contrast.
    @Environment(\.colorSchemeContrast) private var contrast

    /// Segment height. The bar is this plus 3 pt of padding on each side,
    /// so 36 pt tall in total.
    private let segmentHeight: CGFloat = 30

    var body: some View {
        HStack(spacing: InletSpace.xxs) {
            segment(title: "All", isSelected: selection == nil) {
                selection = nil
            }
            ForEach(AppCategory.allCases) { category in
                segment(title: category.title, isSelected: selection == category) {
                    // Tapping the selected bucket clears the filter, same as All.
                    selection = selection == category ? nil : category
                }
            }
        }
        .padding(3)
        .inletCapsuleGlass(interactive: true)
        .opacity(isFaded ? 0 : 1)
        .allowsHitTesting(!isFaded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Categories")
        .accessibilityHidden(isFaded)
        .inletAnimation(.inletFade, value: isFaded)
        .inletAnimation(.inletSnap, value: selection)
    }

    private func segment(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(InletFont.label)
                .textCase(.uppercase)
                .tracking(InletTracking.label)
                .foregroundStyle(isSelected ? InletColor.text : InletText.secondary(contrast))
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
    @Previewable @State var selection: AppCategory? = .create
    return CategoryBar(selection: $selection)
        .padding(40)
        .background(InletColor.base)
}
