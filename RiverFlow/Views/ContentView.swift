import SwiftUI
import Foundation
import Observation

/// Custom SwiftUI preference key used to map file IDs to their bounding frame rectangles in screen space.
private struct FileFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID : CGRect], nextValue: () -> [UUID : CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Context menu view for grid layout view.
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
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = FolderViewModel()
    @State private var selectedFolderURL: URL? = SideBarItem.home.url.standardizedFileURL
    @State private var selectedFileViewStyle: FileViewStyle = .grid
    @State private var refreshTrigger = 0
    @State private var goUpTrigger = 0
    @State private var lastAnchorFileId: UUID?
    @State private var fileFrames: [UUID: CGRect] = [:]
    @State private var selectionRect: CGRect? = nil
    @State private var dragStartLocation: CGPoint? = nil
    @State private var selectionBaseline: Set<UUID> = []
    @State private var showSplash = !SplashOverlay.hasShownSplashInThisSession
    @State private var dropTargetedFileId: UUID? = nil
    @State private var isMoveUpTargeted = false
    @State private var windowWidth: CGFloat = 0
    
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
        .onChange(of: selectedFolderURL) { _, newValue in
            viewModel.selectedFileIds = []
            isMoveUpTargeted = false
            if let newURL = newValue, viewModel.currentDir.standardizedFileURL != newURL.standardizedFileURL {
                viewModel.currentDir = newURL
                viewModel.loadCurrentDirectory()
            }
        }
        .onChange(of: viewModel.currentDir) { _, newValue in
            let standardized = newValue.standardizedFileURL
            if selectedFolderURL?.standardizedFileURL != standardized {
                selectedFolderURL = standardized
            }
        }
        .onAppear() {
            SoundEffects.warmUpAudioEngine()
            viewModel.undoManager = undoManager
        }
        .overlay {
            SplashOverlay(isPresented: $showSplash)
        }
        .overlay {
            if viewModel.isJumpToPathPresented {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.isJumpToPathPresented = false
                        }
                    
                    JumpToPathModalView(viewModel: viewModel, isPresented: $viewModel.isJumpToPathPresented)
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: viewModel.isJumpToPathPresented)
            }
        }
        .toolbar(showSplash ? .hidden : .automatic)
        .dropDestination(for: URL.self) { urls, location in
            viewModel.handleDrop(urls: urls)
            return true
        }
        .alert("Item with this name already exists", isPresented: Binding(
            get: { viewModel.fileCollision != nil },
            set: { _ in }
        ), presenting: viewModel.fileCollision) { collision in
            Button("Skip", role: .cancel) {
                viewModel.resolveFileCollision(.skip)
            }
            Button("Replace", role: .destructive) {
                viewModel.resolveFileCollision(.replace)
            }
            Button("Keep Both") {
                viewModel.resolveFileCollision(.keepBoth)
            }
        } message: { collision in
            Text("\"\(collision.destinationURL.lastPathComponent)\" already exists i\"\(collision.destinationURL.deletingLastPathComponent().lastPathComponent)\". Choose whether to replace it or keep botitems.")
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            windowWidth = newWidth
        }
        .focusedValue(\.activeFolderViewModel, viewModel)
        .handleKeyboardShortcuts(viewModel: viewModel, openWindow: {
            openWindow(id: "mainWindow")
        })
    }

    private var sidebarView: some View {
        SidebarView(viewModel: viewModel, selectedFolderURL: $selectedFolderURL)
    }

    @ViewBuilder
    private var detailView: some View {
        VStack {
            if !viewModel.searchText.isEmpty {
                HStack {
//                    Text("Search in:")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
                    
                    Picker("Search scope", selection: $viewModel.searchScope) {
                        Text("(\(viewModel.currentDirName))").tag(SearchScope.currentFolder)
                        Text("This Mac").tag(SearchScope.thisMac)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Material.ultraThin)
            }
            
            Group {
                if selectedFileViewStyle == .list {
                    listView
                } else {
                    gridView
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("")
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    viewModel.goBackward()
                }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(viewModel.historyBackward.isEmpty)
                .help("Go Back")
                Button(action: {
                    viewModel.goForward()
                }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(viewModel.historyForward.isEmpty)
                .help("Go Forward")
                Button(action: {
                    guard viewModel.currentDir.path != "/" else { return }
                    viewModel.goToParentDirectory()
                    goUpTrigger += 1
                }) {
                    Image(systemName: "arrow.up")
                        .symbolEffect(.bounce.byLayer, options: .speed(8), value: goUpTrigger)
                }
                // disabled blocks hit testing
                .opacity(viewModel.currentDir.path == "/" ? 0.4 : 1.0)
                .help("Go To Parent Directory")
                .padding(4)
                .contentShape(Rectangle())
                .background {
                    if isMoveUpTargeted {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.25))
                    }
                }
                .scaleEffect(isMoveUpTargeted ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMoveUpTargeted)
                .dropDestination(for: URL.self) { urls, _ in
                    guard viewModel.currentDir.path != "/" else { return false }
                    viewModel.handleDrop(urls: urls, to: viewModel.currentDir.deletingLastPathComponent())
                    return true
                } isTargeted: { targeted in
                    isMoveUpTargeted = targeted && viewModel.currentDir.path != "/"
                }
                
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
                    folderName: viewModel.currentDirName,
                    width: $windowWidth
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
                        isTargeted: dropTargetedFileId == file.id,
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
                    .draggable(file) {
                        FileIconView(file: file, baseSize: 32)
                    }
                    .dropDestination(for: URL.self) { urls, _ in
                        if file.itemType == .DIRECTORY {
                            viewModel.handleDrop(urls: urls, to: file.url)
                            return true
                        }
                        return false
                    } isTargeted: { targeted in
                        if file.itemType == .DIRECTORY {
                            dropTargetedFileId = targeted ? file.id : nil
                        }
                    }
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
                        isTargeted: dropTargetedFileId == file.id,
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
                    .draggable(file) {
                        FileIconView(file: file, baseSize: 32)
                    }
                    .dropDestination(for: URL.self) { urls, _ in
                        if file.itemType == .DIRECTORY {
                            viewModel.handleDrop(urls: urls, to: file.url)
                            return true
                        }
                        return false
                    } isTargeted: { targeted in
                        if file.itemType == .DIRECTORY {
                            dropTargetedFileId = targeted ? file.id : nil
                        }
                    }
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
        .safeAreaInset(edge: .bottom) {
            HStack {
                if viewModel.isGitRepo, let branch = viewModel.gitBranch {
                    HStack(spacing: 4) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .imageScale(.small)
                        
                        Menu {
                            ForEach(viewModel.gitBranches, id: \.self) { branchName in
                                Button(action: {
                                    viewModel.checkoutBranch(name: branchName)
                                }) {
                                    HStack {
                                        Text(branchName)
                                        if branchName == branch {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text(branch)
                                .fontWeight(.semibold)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .disabled(viewModel.gitUncommittedCount > 0)
                        .help(viewModel.gitUncommittedCount > 0 ? "Cannot switch branches with uncommitted changes" : "Switch Git Branch")
                        
                        if viewModel.gitUncommittedCount > 0 {
                            Text("(\(viewModel.gitUncommittedCount) uncommitted)")
                                .foregroundStyle(.orange)
                        } else {
                            Text("(all committed)")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
                }
                Spacer()
                Text("\(viewModel.itemCountText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }
            .padding(.vertical, 6)
            .background(.bar)
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
    }
}

#Preview {
    ContentView()
}
