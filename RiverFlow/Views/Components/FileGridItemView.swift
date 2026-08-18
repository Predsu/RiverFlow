import SwiftUI

/// SwiftUI view representing `FileItem` in grid layout.
///
/// Displays a file icon and editable name in grid cell. Supports:
/// - single click selection
/// - double click activation
/// - right-click context menu
/// - drag-and-drop targeting
/// - actions from `FileContextMenu`
struct FileGridItemView: View {
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
    var viewModel: FolderViewModel
    
    var isEditing: Bool {
        viewModel.editingFileID == file.id
    }
    
    var body: some View {
        VStack(spacing: 8) {
            FileIconView(file: file, baseSize: 64)
//            Text(file.name)
//                .font(.system(size: 12))
//                .lineLimit(2)
//                .multilineTextAlignment(.center)
//                .frame(height: 32, alignment: .top)
            EditableFileNameView(
                file: file,
                isEditing: isEditing,
                onCommit: { newName in
                    viewModel.renameFile(file: file, to: newName)
                    viewModel.editingFileID = nil
                },
                onCancel: {
                    viewModel.editingFileID = nil
                }
            )
        }
        .padding(10)
        .frame(width: 120, height: 110, alignment: .top)
        .background(
            ZStack {
                if isSelected {
                    Color(.selectedControlColor).opacity(0.15)
                }
                if isTargeted && file.itemType == .DIRECTORY {
                    Color.accentColor.opacity(0.2)
                }
            }
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isTargeted && file.itemType == .DIRECTORY ? Color.accentColor : Color(.selectedControlColor), lineWidth: (isSelected || (isTargeted && file.itemType == .DIRECTORY)) ? 2 : 0)
        )
        .contentShape(Rectangle())
        .overlay(RightClickCatcher(onRightClick: {
            onRightClick()
        }))
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
