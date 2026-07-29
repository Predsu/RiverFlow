import SwiftUI
import Foundation
import Observation

private struct FileFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID : CGRect], nextValue: () -> [UUID : CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct GridContextMenu: View {
    let viewModel: FolderViewModel

    var body: some View {
        Button(action: { viewModel.pasteFiles() }) {
            Text("Paste File")
            Image(systemName: "doc.on.clipboard.fill")
        }
        
        Divider()
        
        Button(action: {
            viewModel.openInTerminal(url: viewModel.currentDir)
        }) {
            Text("Open in Terminal")
            Image(systemName: "apple.terminal")
        }
        
        Button(action: {
            viewModel.openInVSCode(url: viewModel.currentDir)
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
            pasteboard.setString(viewModel.currentDir.path, forType: .string)
        }) {
            Text("Copy Current Directory Path")
            Image(systemName: "doc.on.doc")
        }
        
        Button(action: {
            viewModel.copyShellEscapedPath(for: viewModel.currentDir)
        }) {
            Text("Copy Shell-Formatted Dir Path")
            Image(systemName: "doc.on.doc")
        }
    }
}

struct ContentView: View {
    @Environment(\.undoManager) private var undoManager
    @State private var viewModel = FolderViewModel()
    @State private var selectedSideBarItem: SideBarItem? = .home
    @State private var selectedFileViewStyle: FileViewStyle = .grid
    @State private var refreshTrigger = 0
    @State private var goUpTrigger = 0
    @State private var lastAnchorFileId: UUID?
    @State private var fileFrames: [UUID: CGRect] = [:]
    @State private var selectionRect: CGRect? = nil
    @State private var dragStartLocation: CGPoint? = nil
    @State private var selectionBaseline: Set<UUID> = []
    @State private var showSplash = !SplashOverlay.hasShownSplashInThisSession
    
    let gridCols = [
        GridItem(.adaptive(minimum: 130), spacing: 16)
    ]
    
    private func handleTap(for file: FileItem, in list: [FileItem]) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift) {
            let anchorId = lastAnchorFileId ?? file.id
            if let anchorIndex = list.firstIndex(where: { $0.id == anchorId}),
               let currentIndex = list.firstIndex(where: { $0.id == file.id }) {
                let range = anchorIndex < currentIndex ? anchorIndex...currentIndex : currentIndex...anchorIndex
                viewModel.selectedFileIds = Set(list[range].map { $0.id })
            }
        } else if modifiers.contains(.command) {
            if viewModel.selectedFileIds.contains(file.id) {
                viewModel.selectedFileIds.remove(file.id)
            } else {
                viewModel.selectedFileIds.insert(file.id)
            }
            lastAnchorFileId = file.id
        } else {
            viewModel.selectedFileIds = [file.id]
            lastAnchorFileId = file.id
        }
    }
    
    private func handleRightClick(for file: FileItem) {
        if !viewModel.selectedFileIds.contains(file.id) {
            viewModel.selectedFileIds = [file.id]
            lastAnchorFileId = file.id
        }
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .onChange(of: selectedSideBarItem) { _, newValue in
            viewModel.selectedFileIds = []
            if let newSection = newValue {
                viewModel.currentDir = newSection.url
                viewModel.loadCurrentDirectory()
            }
        }
        .onAppear() {
            SoundEffects.warmUpAudioEngine()
            viewModel.undoManager = undoManager
        }
        .overlay {
            SplashOverlay(isPresented: $showSplash)
        }
        .toolbar(showSplash ? .hidden : .automatic)
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
            if selectedFileViewStyle == .list {
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
                Picker("Sort By", selection: $viewModel.currentSortingOption) {
                    ForEach(FileSortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.iconName)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 64)
                .help("Sort Options")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Picker("View Style", selection: $selectedFileViewStyle) {
                    ForEach(FileViewStyle.allCases) { style in
                        Label(style.rawValue, systemImage: style.iconName)
                            .tag(style)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 64)
                .help("View Options")
            }
        }
        .onCommand(#selector(NSText.copy(_:))) {
            if !viewModel.selectedFiles.isEmpty {
                viewModel.copyFiles(files: viewModel.selectedFiles)
            }
        }
        .onCommand(#selector(NSText.cut(_:))) {
            if !viewModel.selectedFiles.isEmpty {
                viewModel.cutFiles(files: viewModel.selectedFiles)
            }
        }
        .onCommand(#selector(NSText.paste(_:))) {
            viewModel.pasteFiles()
        }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.sortedFiles) { file in
                    FileListItemView(
                        file: file,
                        isSelected: viewModel.selectedFileIds.contains(file.id),
                        onTap: {
                            handleTap(for: file, in: viewModel.sortedFiles)
                        },
                        onRightClick: {
                            handleRightClick(for: file)
                        },
                        onDoubleTap: {
                            if file.url.pathExtension == "app" {
                                NSWorkspace.shared.open(file.url)
                            } else if file.itemType == .DIRECTORY {
                                viewModel.enterDirectory(dir: file)
                                viewModel.selectedFileIds.removeAll()
                            } else {
                                NSWorkspace.shared.open(file.url)
                            }
                        },
                        onCopy: {
                            viewModel.copyFiles(files: viewModel.selectedFiles)
                        },
                        onCut: {
                            viewModel.cutFiles(files: viewModel.selectedFiles)
                        },
                        onOpenAsDirectory: {
                            viewModel.enterDirectory(dir: file)
                            viewModel.selectedFileIds = []
                        },
                        onRefreshRequired: {
                            viewModel.loadCurrentDirectory()
                        },
                        onMoveToTrash: {
                            let filesToTrash = viewModel.selectedFileIds.contains(file.id) ? viewModel.selectedFiles : [file]
                            viewModel.moveToTrash(files: filesToTrash)
                            viewModel.selectedFileIds.removeAll()
                        },
                        viewModel: viewModel
                    )
            }
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridCols, spacing: 16) {
                ForEach(viewModel.sortedFiles) { file in
                    FileGridItemView(
                        file: file,
                        isSelected: viewModel.selectedFileIds.contains(file.id),
                        onTap: {
                            handleTap(for: file, in: viewModel.sortedFiles)
                        },
                        onRightClick: {
                            handleRightClick(for: file)
                        },
                        onDoubleTap: {
                            if file.url.pathExtension == "app" {
                                NSWorkspace.shared.open(file.url)
                            } else if file.itemType == .DIRECTORY {
                                viewModel.enterDirectory(dir: file)
                                viewModel.selectedFileIds.removeAll()
                            } else {
                                NSWorkspace.shared.open(file.url)
                            }
                        },
                        onCopy: {
                            viewModel.copyFiles(files: viewModel.selectedFiles)
                        },
                        onCut: {
                            viewModel.cutFiles(files: viewModel.selectedFiles)
                        },
                        onOpenAsDirectory: {
                            viewModel.enterDirectory(dir: file)
                            viewModel.selectedFileIds = []
                        },
                        onRefreshRequired: {
                            viewModel.loadCurrentDirectory()
                        },
                        onMoveToTrash: {
                            let filesToTrash = viewModel.selectedFileIds.contains(file.id) ? viewModel.selectedFiles : [file]
                            viewModel.moveToTrash(files: filesToTrash)
                            viewModel.selectedFileIds.removeAll()
                        },
                        viewModel: viewModel
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: FileFramePreferenceKey.self,
                                    value: [file.id: geo.frame(in: .named("fileGridArea"))]
                                )
                        }
                    )
                }
            }
            .padding()
        }
        .coordinateSpace(name: "fileGridArea")
        .onPreferenceChange(FileFramePreferenceKey.self) { frames in
            fileFrames = frames
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .contentShape(Rectangle())
        .overlay(
            Group {
                if let rect = selectionRect {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.2))
                        .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("fileGridArea"))
                .onChanged { value in
                    if dragStartLocation == nil {
                        dragStartLocation = value.startLocation
                        selectionBaseline = NSEvent.modifierFlags.contains(.shift) ? viewModel.selectedFileIds : []
                    }
                    guard let start = dragStartLocation else { return }
                    let rect = CGRect(
                        x: min(start.x, value.location.x),
                        y: min(start.y, value.location.y),
                        width: abs(value.location.x - start.x),
                        height: abs(value.location.y - start.y)
                    )
                    selectionRect = rect
                    if rect.width > 2 || rect.height > 2 {
                        let intersectingIds = fileFrames.filter { $0.value.intersects(rect) }.map { $0.key }
                        viewModel.selectedFileIds = selectionBaseline.union(intersectingIds)
                    }
                }
                .onEnded { value in
                    let dx = abs(value.location.x - value.startLocation.x)
                    let dy = abs(value.location.y - value.startLocation.y)
                    if dx < 2 && dy < 2 {
                        let modifiers = NSEvent.modifierFlags
                        if !modifiers.contains(.shift) && !modifiers.contains(.command) {
                            viewModel.selectedFileIds.removeAll()
                        }
                    }
                    dragStartLocation = nil
                    selectionRect = nil
                }
        )
//        .onTapGesture {
//            viewModel.selectedFileIds.removeAll()
//        }
        .contextMenu {
            GridContextMenu(viewModel: viewModel)
        }
        .onChange(of: selectedSideBarItem) { _, newValue in
            if let newSection = newValue {
                if viewModel.currentDir.standardizedFileURL != newSection.url.standardizedFileURL {
                    viewModel.selectedFileIds = []
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
