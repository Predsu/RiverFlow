import SwiftUI

/// SwiftUI view representing `FileItem` in list layout.
///
/// Displays a compact horizontal representation. Supports:
/// - single click selection
/// - double click activation
/// - right-click context menu
/// - drag-and-drop targeting
/// - actions from `FileContextMenu`
struct FileListItemView: View {
    let file: FileItem
    let isSelected: Bool
    var isTargeted: Bool = false
    let onTap: () -> Void
    let onRightClick: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onOpenAsDirectory: () -> Void
    let onRefreshRequired: () -> Void
    let onMoveToTrash: () -> Void
    let viewModel: FolderViewModel

    var body: some View {
        HStack {
            FileIconView(file: file, baseSize: 18)
            Text(file.name)
                .lineLimit(1)

            Spacer()

            Text(file.formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(file.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            ZStack {
                if isSelected {
                    Color(.selectedControlColor).opacity(0.2)
                }
                if isTargeted && file.itemType == .DIRECTORY {
                    Color.accentColor.opacity(0.2)
                }
            }
        )
        .overlay(RightClickCatcher(onRightClick: {
            onRightClick()
        }))
        .contentShape(Rectangle())
        .gesture(
            TapGesture(count: 1)
                .onEnded {
                    onTap()
                }
                .simultaneously(
                    with: TapGesture(count: 2)
                        .onEnded {
                            onDoubleTap()
                        }
                )
        )
        .contextMenu {
            FileContextMenu(
                file: file,
                viewModel: viewModel,
                isSelected: isSelected,
                onOpenAsDirectory: onOpenAsDirectory,
                onCopy: onCopy,
                onCut: onCut,
                onMoveToTrash: onMoveToTrash
            )
        }
    }
}
