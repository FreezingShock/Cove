import AppKit
import SwiftUI

/// One file row in the search results panel and the quick panel's recent files.
///
/// Layout follows theme-spec v1.2: a 30 pt file icon, a 15 pt medium title, and a
/// 12 pt path in `text2`. The selected row gets a `CoveRadius.row` (24 pt) fill,
/// which is 32 pt panel radius minus the 8 pt panel padding.
///
/// The row only draws. It does not handle keys. The parent view calls
/// `FileItem.open()` on Return and `FileItem.revealInFinder()` on Cmd+Return.
struct FileResultRow: View {
    let item: FileItem
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: CoveSpace.m) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CoveSpace.xxs) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CoveColor.text)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.displayPath)
                    .font(.system(size: 12))
                    .foregroundStyle(CoveColor.text2)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, CoveSpace.s)
        .padding(.horizontal, CoveSpace.m)
        .background(selectionBackground)
        .contentShape(RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.displayPath)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous)
                .fill(CoveColor.selTop)
                .overlay(
                    RoundedRectangle(cornerRadius: CoveRadius.row, style: .continuous)
                        .strokeBorder(CoveColor.selRing, lineWidth: 1)
                )
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        FileResultRow(
            item: FileItem(
                url: URL(fileURLWithPath: "/Users/nate/Documents/Quarterly Report.pdf"),
                name: "Quarterly Report.pdf",
                lastUsed: nil
            ),
            isSelected: true
        )
        FileResultRow(
            item: FileItem(
                url: URL(fileURLWithPath: "/Users/nate/Desktop/screenshot.png"),
                name: "screenshot.png",
                lastUsed: nil
            )
        )
    }
    .padding(8)
    .frame(width: 680)
}
