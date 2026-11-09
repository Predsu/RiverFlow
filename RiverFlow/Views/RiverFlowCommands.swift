import SwiftUI

/// App commands defining native macOS menu items and standard keyboard shortcuts.
struct RiverFlowCommands: Commands {
    @FocusedValue(\.activeFolderViewModel) private var activeViewModel: FolderViewModel?
    @FocusedValue(\.browserWorkspace) private var workspace: BrowserWorkspace?
    @Environment(\.openWindow) private var openWindow
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "mainWindow")
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
        
        CommandMenu("Pane") {
            if let workspace, !workspace.hasPresentedDialog {
                Button("New Tab") { workspace.newTab(in: workspace.activePaneID) }
                    .keyboardShortcut("t", modifiers: [.command, .option])
                Button("Close Active Tab") {
                    workspace.closeTab(workspace.activePane.selectedTabID, in: workspace.activePaneID)
                }
                .disabled(workspace.panes.count == 1 && workspace.activePane.tabs.count == 1)
                Divider()
                Button(workspace.isPlacingPane ? "Cancel Placement" : "Place New Pane…") {
                    if workspace.isPlacingPane {
                        workspace.isPlacingPane = false
                    } else {
                        workspace.beginPanePlacement()
                    }
                }
                Button("Split Right") { workspace.splitPane(workspace.activePaneID, vertically: false) }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .disabled(!workspace.canAddPane)
                Button("Split Down") { workspace.splitPane(workspace.activePaneID, vertically: true) }
                    .disabled(!workspace.canAddPane)
                Menu("Layout") {
                    ForEach(BrowserLayout.allCases) { layout in
                        Button { workspace.setLayout(layout) } label: {
                            Label(layout.rawValue, systemImage: layout.symbol)
                        }
                    }
                }
                Button(workspace.showsPaneHeaders ? "Hide Pane Headers" : "Show Pane Headers") {
                    workspace.showsPaneHeaders.toggle()
                }
                Divider()
                Button("Close Active Pane") { workspace.closePane(workspace.activePaneID) }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .disabled(workspace.panes.count == 1)
                Button("Next Pane") {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    workspace.focusNextPane()
                }
                    .keyboardShortcut("`", modifiers: [.control])
                    .disabled(workspace.panes.count == 1)
                Button(workspace.isActivePaneExpanded ? "Show All Panes" : "Expand Active Pane") {
                    workspace.isActivePaneExpanded.toggle()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(workspace.panes.count == 1)
            }
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
            
            Divider()
            
            Button("Go to Folder") {
                activeViewModel?.isJumpToPathPresented = true
            }
            .keyboardShortcut("G", modifiers: [.command])
            .disabled(activeViewModel == nil)
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

struct BrowserWorkspaceKey: FocusedValueKey {
    typealias Value = BrowserWorkspace
}

extension FocusedValues {
    var browserWorkspace: BrowserWorkspace? {
        get { self[BrowserWorkspaceKey.self] }
        set { self[BrowserWorkspaceKey.self] = newValue }
    }
}
