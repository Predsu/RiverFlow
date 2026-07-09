import SwiftUI
import Foundation
import Observation

struct ContentView: View {
    @State private var viewModel = FolderViewModel()
    @State private var selectedSideBarItem: SideBarItem? = .home
    @State private var selectedElementsViewStyle: ElementsViewStyle = .grid
    @State private var selectedFileId: UUID? = nil
    @State private var refreshTrigger = 0
    @State private var goUpTrigger = 0
    
    let gridCols = [
        GridItem(.adaptive(minimum: 130), spacing: 16)
    ]
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .onChange(of: selectedSideBarItem) { _, newValue in
            selectedFileId = nil
            if let newSection = newValue {
                viewModel.currentDir = newSection.url
                viewModel.loadCurrentDirectory()
            }
        }
    }

    private var sidebarView: some View {
        List(SideBarItem.allCases, selection: $selectedSideBarItem) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.iconName)
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("")
    }

    @ViewBuilder
    private var detailView: some View {
        VStack {
            if selectedElementsViewStyle == .list {
                listView
            } else {
                gridView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    viewModel.goToParentDirectory()
                    goUpTrigger += 1
                }) {
                    Image(systemName: "arrow.up")
                        .symbolEffect(.bounce.byLayer, options: .speed(8), value: goUpTrigger)
                }
                .disabled(viewModel.currentDir.path == "/")
                .help("Go To Parent Directory")
                
                Button(action: {
                    viewModel.loadCurrentDirectory()
                    refreshTrigger += 1
                }) {
                    if #available(macOS 15.0, *) {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.rotate, options: .speed(16), value: refreshTrigger)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.bounce.byLayer, value: refreshTrigger)
                    }
                }
                .help("Refresh")
            }
            
            ToolbarItem(placement: .navigation) {
                InteractivePathTitleView(
                    fullPath: viewModel.currentDir.path,
                    folderName: viewModel.currentDirName
                )
            }
            
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $viewModel.showHiddenFiles) {
                    Label("Show Hidden", systemImage: viewModel.showHiddenFiles ? "eye" : "eye.slash")
                }
                .help(viewModel.showHiddenFiles ? "Hide Hidden" : "Show Hidden")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Picker("View Style", selection: $selectedElementsViewStyle) {
                    ForEach(ElementsViewStyle.allCases) { style in
                        Label(style.rawValue, systemImage: style.iconName)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .onCommand(#selector(NSText.copy(_:))) {
            if let selectedId = selectedFileId, let file = viewModel.files.first(where: { $0.id == selectedId }) {
                viewModel.copyElement(element: file)
            }
        }
        .onCommand(#selector(NSText.cut(_:))) {
            if let selectedId = selectedFileId, let file = viewModel.files.first(where: { $0.id == selectedId }) {
                viewModel.cutElement(element: file)
            }
        }
        .onCommand(#selector(NSText.paste(_:))) {
            viewModel.pasteElement()
        }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.files) { file in
                FileListItemView(
                    file: file,
                    isSelected: selectedFileId == file.id,
                    onTap: {
                        selectedFileId = file.id
                    },
                    onDoubleTap: {
                        selectedFileId = file.id
                        if file.url.pathExtension == "app" {
                            NSWorkspace.shared.open(file.url)
                        } else if file.itemType == .DIRECTORY {
                            viewModel.enterDirectory(dir: file)
                            selectedFileId = nil
                        } else {
                            NSWorkspace.shared.open(file.url)
                        }
                    },
                    onCopy: {
                        viewModel.copyElement(element: file)
                    },
                    onCut: {
                        viewModel.cutElement(element: file)
                    },
                    onOpenAsDirectory: {
                        viewModel.enterDirectory(dir: file)
                        selectedFileId = nil
                    }
                )
            }
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridCols, spacing: 16) {
                ForEach(viewModel.files) { file in
                    FileGridItemView(
                        file: file,
                        isSelected: selectedFileId == file.id,
                        onTap: {
                            selectedFileId = file.id
                        },
                        onDoubleTap: {
                            if file.url.pathExtension == "app" {
                                NSWorkspace.shared.open(file.url)
                            } else if file.itemType == .DIRECTORY {
                                viewModel.enterDirectory(dir: file)
                                selectedFileId = nil
                            } else {
                                NSWorkspace.shared.open(file.url)
                            }
                        },
                        onCopy: {
                            viewModel.copyElement(element: file)
                        },
                        onCut: {
                            viewModel.cutElement(element: file)
                        },
                        onOpenAsDirectory: {
                            viewModel.enterDirectory(dir: file)
                            selectedFileId = nil
                        }
                    )
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFileId = nil
        }
        .contextMenu {
            Button(action: { viewModel.pasteElement() }) {
                Text("Paste Element")
                Image(systemName: "doc.on.clipboard.fill")
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
            
            Divider()
            
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(viewModel.currentDir.path, forType: .string)
            }) {
                Text("Copy Current Directory Path")
                Image(systemName: "doc.on.doc")
            }
        }
        .onChange(of: selectedSideBarItem) { _, newValue in
            if let newSection = newValue {
                if viewModel.currentDir.standardizedFileURL != newSection.url.standardizedFileURL {
                    selectedFileId = nil
                    viewModel.currentDir = newSection.url
                    viewModel.loadCurrentDirectory()
                }
            }
        }
        .onChange(of: viewModel.currentDir) { _, newValue in
            let matchingItem = viewModel.matchingSidebarItem
            if selectedSideBarItem != matchingItem {
                selectedSideBarItem = matchingItem
            }
        }
    }
}

#Preview {
    ContentView()
}
