import SwiftUI

/// App commands defining native macOS menu items and standard keyboard shortcuts.
struct RiverFlowCommands: Commands {
    @FocusedValue(\.activeFolderViewModel) private var activeViewModel: FolderViewModel?
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("t", modifiers: .command)
            
            Divider()
            
            Button("New Folder") {
                activeViewModel?.createNewDirectory()
            }
            .keyboardShortcut("N", modifiers: [.command, .shift])
            .disabled(activeViewModel == nil)
            
            Button("New File") {
                activeViewModel?.createNewFile()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(activeViewModel == nil)
            
            Divider()
            
            Button("Open Selected") {
                activeViewModel?.openSelectedFiles()
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(activeViewModel?.selectedFiles.isEmpty ?? true)
            
            Button("Move to Trash") {
                activeViewModel?.moveSelectedToTrash()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(activeViewModel?.selectedFiles.isEmpty ?? true)
            
            Button("Delete Immediately") {
                activeViewModel?.permanentlyDeleteSelected()
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(activeViewModel?.selectedFiles.isEmpty ?? true)
        }
        
        CommandMenu("Go") {
            Button("Back") {
                activeViewModel?.goBackward()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(activeViewModel?.historyBackward.isEmpty ?? true)
            
            Button("Forward") {
                activeViewModel?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(activeViewModel?.historyForward.isEmpty ?? true)
            
            Button("Enclosing Folder") {
                activeViewModel?.goToParentDirectory()
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .disabled(activeViewModel == nil || activeViewModel?.currentDir.path == "/")
        }
    }
}

struct ActiveFolderViewModelKey: FocusedValueKey {
    typealias Value = FolderViewModel
}

extension FocusedValues {
    var activeFolderViewModel: FolderViewModel? {
        get { self[ActiveFolderViewModelKey.self] }
        set { self[ActiveFolderViewModelKey.self] = newValue }
    }
}
