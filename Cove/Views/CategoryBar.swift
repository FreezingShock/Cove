//
//  CategoryBar.swift
//  Cove
//
//  The capsule above the grid: All, then the six category buckets. Tap a
//  bucket to filter the grid to it; tap the selected bucket again, or All,
//  to show every app.
//

import SwiftUI

struct CategoryBar: View {
    /// The bucket the grid is filtered to. Nil shows every app.
    @Binding var selection: AppCategory?

    /// Set this to true while the search field has text. The bar fades out
    /// so the results can take its place. The search view owns this flag.
    var isFaded = false

    /// Segment height. The bar is this plus 3 pt of padding on each side,
    /// so 36 pt tall in total.
    private let segmentHeight: CGFloat = 30

    var body: some View {
        HStack(spacing: 2) {
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
        .glassEffect(.regular.interactive(), in: .capsule)
        .opacity(isFaded ? 0 : 1)
        .allowsHitTesting(!isFaded)
        .accessibilityHidden(isFaded)
        .animation(.easeInOut(duration: 0.2), value: isFaded)
        .animation(.spring(duration: 0.24, bounce: 0), value: selection)
    }

    private func segment(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.66) // 0.06em at 11 pt
                .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: segmentHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.white.opacity(0.14))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
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
        .background(Theme.base)
}
