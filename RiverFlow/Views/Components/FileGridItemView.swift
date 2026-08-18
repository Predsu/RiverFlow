import SwiftUI

/// SwiftUI view representing `FileItem` in grid layout.
///
/// Displays a file icon and editable name in grid cell with interactive affordances.
/// The view is a 120x110pt cell that displays the file's thumbnail/icon and name.
/// Users can interact through single-click selection, double-click activation,
/// right-click context menus, and drag-and-drop operations.
///
/// Supports:
/// - Single click for selection (with Shift/Command modifiers via parent view)
/// - Double click to activate (open file or enter directory)
/// - Right-click context menu (via `FileContextMenu`)
/// - Drag-and-drop targeting with visual feedback
/// - Inline name editing (when `viewModel.editingFileID` matches)
///
/// - Parameters:
///   - file: The `FileItem` to display.
///   - isSelected: Whether this item is currently selected.
///   - isTargeted: Whether this item is a current drag-and-drop target (default: false).
///   - onTap: Closure invoked when the cell is single-clicked.
///   - onRightClick: Closure invoked when right-clicked to show context menu.
///   - onDoubleTap: Closure invoked when double-clicked to activate.
///   - onCopy: Closure invoked by context menu for copy operation.
///   - onCut: Closure invoked by context menu for cut operation.
///   - onOpenAsDirectory: Closure invoked by context menu to open as directory.
///   - onRefreshRequired: Closure invoked to refresh the view after operations.
///   - onMoveToTrash: Closure invoked by context menu for trash operation.
///   - viewModel: Reference to the folder view model for state management and operations.
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
