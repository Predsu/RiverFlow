import SwiftUI

/// SwiftUI context menu containing actions for `FileItem`.
struct FileContextMenu: View {
    let file: FileItem
    let viewModel: FolderViewModel
    let isSelected: Bool
    let onOpenAsDirectory: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onMoveToTrash: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        Group {
            Button(action: {
                viewModel.openFileWith(file: file)
            }) {
                Text("Open File With")
                Image(systemName: "arrow.up.forward.app")
            }
            
            Button(action: {
                viewModel.revealInFinder(url: file.url)
            }) {
                Text("Reveal in Finder")
                Image(systemName: "magnifyingglass")
            }
            
            Divider()
            
            if file.url.pathExtension == "app" {
                Button(action: onOpenAsDirectory) {
                    Text("Show Package Contents")
                    Image(systemName: "folder.badge.gearshape")
                }
                
                Divider()
            }
            
            Button(action: {
                FileWindowManager.openInfoView(for: file)
            }) {
                Text("File Info")
                Image(systemName: "info.circle")
            }

            Divider()

            Button(action: onCopy) {
                Text("Copy File")
                Image(systemName: "doc.on.doc")
            }
            
            Button(action: onCut) {
                Text("Cut File")
                Image(systemName: "arrow.right.doc.on.clipboard")
            }
            
            Button(action: {
                viewModel.editingFileID = file.id
            }) {
                Text("Rename")
                Image(systemName: "character.cursor.ibeam")
            }
            
            Button(action: {
                if isSelected {
                    let selectedFiles = viewModel.files.filter { viewModel.selectedFileIds.contains($0.id) }
                    viewModel.compressToZip(files: selectedFiles)
                } else {
                    viewModel.compressToZip(files: [file])
                }
            }) {
                Text("Compress to ZIP")
                Image(systemName: "archivebox")
            }
            
            if viewModel.selectedFileIds.count > 1 && viewModel.selectedFileIds.contains(file.id) {
                Button(action: {
                    viewModel.createFolderFromSelection(files: viewModel.selectedFiles)
                    viewModel.selectedFileIds.removeAll()
                }) {
                    Text("Create Folder with Selected")
                    Image(systemName: "folder.badge.plus")
                }
            }
            
            Divider()
            
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.url.path, forType: .string)
            }) {
                Text("Copy File Path")
                Image(systemName: "doc.on.doc")
            }
            
            if viewModel.isGitRepo && file.itemType == .FILE {
                Divider()
                
                if viewModel.isFileUnstaged(url: file.url) {
                    Button(action: {
                        viewModel.gitStage(file: file)
                    }) {
                        Text("Git Stage")
                        Image(systemName: "plus.circle")
                    }
                    
                    Button(role: .destructive, action: onDiscard) {
                        Text("Git Discard")
                        Image(systemName: "arrow.counterclockwise.circle")
                    }
                }
                
                if viewModel.isFileStaged(url: file.url) {
                    Button(action: {
                        viewModel.gitUnstage(file: file)
                    }) {
                        Text("Git Unstage")
                        Image(systemName: "minus.circle")
                    }
                }
                
                Button(action: {
                    viewModel.copyGitRelativePath(for: file.url)
                }) {
                    Text("Copy Git Relative Path")
                    Image(systemName: "doc.on.doc.fill")
                }
                
                if viewModel.getGitHubOrGitLabURL(for: file.url) != nil {
                    Button(action: {
                        viewModel.openInGitHubOrGitLab(file: file)
                    }) {
                        Text("Open on GitHub / GitLab")
                        Image(systemName: "globe")
                    }
                }
            }
            
            Divider()
            
            Button(action: onMoveToTrash) {
                Text("Move to Trash")
                Image(systemName: "trash")
            }
        }
    }
}
