import SwiftUI

/// SwiftUI context menu for directory actions, folder items, and folder background interactions.
struct FolderContextMenu: View {
    let viewModel: FolderViewModel
    var targetURL: URL? = nil

    private var directoryURL: URL {
        targetURL ?? viewModel.currentDir
    }

    var body: some View {
        Button(action: { viewModel.pasteFiles() }) {
            Text("Paste File")
            Image(systemName: "doc.on.clipboard.fill")
        }
        
        Divider()
        
        Button(action: {
            viewModel.openInTerminal(url: directoryURL)
        }) {
            Text("Open in Terminal")
            Image(systemName: "apple.terminal")
        }
        
        Button(action: {
            viewModel.openInVSCode(url: directoryURL)
        }) {
            Text("Open in VSCode")
            Image(systemName: "chevron.left.forwardslash.chevron.right")
        }
        
        Divider()
        
        Button(action: {
            viewModel.createNewDirectory()
        }) {
            Text("Create Folder")
            Image(systemName: "folder.badge.plus")
        }
        
        Button(action: {
            viewModel.createNewFile()
        }) {
            Text("Create File")
            Image(systemName: "doc.badge.plus")
        }
        
        if viewModel.selectedFileIds.count > 1 {
            Button("Create Folder with Selected") {
                viewModel.createFolderFromSelection(files: viewModel.selectedFiles)
            }
        }
        
        Divider()
        
        Button(action: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(directoryURL.path, forType: .string)
        }) {
            Text("Copy Current Directory Path")
            Image(systemName: "doc.on.doc")
        }
        
        Button(action: {
            viewModel.copyShellEscapedPath(for: directoryURL)
        }) {
            Text("Copy Shell-Formatted Dir Path")
            Image(systemName: "doc.on.doc")
        }
        
        if viewModel.isGitRepo {
            Divider()
            
            Button(action: {
                viewModel.isGitCommitPresented = true
            }) {
                Text("Git Commit...")
                Image(systemName: "checkmark.circle")
            }
        }
    }
}
