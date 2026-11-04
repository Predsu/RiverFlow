import SwiftUI
import Foundation
import Observation
import UniformTypeIdentifiers

private struct PaneDrag: Codable, Transferable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: "com.toriyukari.riverflow.pane"))
    }
}

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
        
        if viewModel.isGitRepo {
            Divider()
            
            Button(action: {
                viewModel.isGitCommitPresented = true
            }) {
                Text("Git Commit")
                Image(systemName: "checkmark.circle")
            }
        }
    }
}

struct BrowserPaneView: View {
    @Bindable var pane: BrowserPane
    let isActive: Bool
    let showsPaneControls: Bool
    let showsPaneHeader: Bool
    let isExpanded: Bool
    let onActivate: () -> Void
    let canSplit: Bool
    let onSplit: (Bool) -> Void
    let onDock: (UUID, Bool, Bool) -> Bool
    let onClose: () -> Void
    let onExpand: () -> Void

    private var viewModel: FolderViewModel { pane.viewModel }
    @State private var goUpTrigger = 0
    @State private var lastAnchorFileId: UUID?
    @State private var fileFrames: [UUID: CGRect] = [:]
    @State private var selectionRect: CGRect? = nil
    @State private var dragStartLocation: CGPoint? = nil
    @State private var selectionBaseline: Set<UUID> = []
    @State private var dropTargetedFileId: UUID? = nil
    @State private var isMoveUpTargeted = false
    @State private var paneWidth: CGFloat = 0
    @State private var showsSearch = false
    @State private var contentSize: CGSize = .zero
    @State private var isDockTargeted = false
    @FocusState private var isSearchFocused: Bool
    

    private var compactGrid: Bool { showsPaneControls && paneWidth < 460 }
    private var gridCols: [GridItem] {
        [GridItem(.adaptive(minimum: compactGrid ? 84 : 130), spacing: compactGrid ? 8 : 16)]
    }
    
    private func handleTap(for file: FileItem, in list: [FileItem]) {
        activateBrowser()
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
        activateBrowser()
        if !viewModel.selectedFileIds.contains(file.id) {
            viewModel.selectedFileIds = [file.id]
            lastAnchorFileId = file.id
        }
    }
    
    private func activateBrowser() {
        guard showsPaneControls else { return }
        onActivate()
        isSearchFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    var body: some View {
        Group {
            if showsPaneControls {
                splitContent
                    .background(Color(NSColor.controlBackgroundColor))
            } else {
                singlePaneContent
            }
        }
        .overlay(alignment: .top) {
            if showsPaneControls {
                Rectangle()
                    .fill(isActive ? Color.accentColor : Color.clear)
                    .frame(height: 2)
                    .allowsHitTesting(false)
            }
        }
        .background(PaneActivationObserver(onActivate: onActivate))
        .onChange(of: isSearchFocused) { _, focused in
            if focused { onActivate() }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { paneWidth = $0 }
        .onChange(of: viewModel.currentDir) { _, _ in
            viewModel.selectedFileIds = []
            isMoveUpTargeted = false
            lastAnchorFileId = nil
            fileFrames = [:]
            selectionRect = nil
            dragStartLocation = nil
        }
        .dropDestination(for: URL.self) { urls, _ in
            onActivate()
            viewModel.handleDrop(urls: urls)
            return !urls.isEmpty
        }
        .alert("Item with this name already exists", isPresented: Binding(
            get: { viewModel.fileCollision != nil }, set: { _ in }
        ), presenting: viewModel.fileCollision) { _ in
            Button("Skip", role: .cancel) { viewModel.resolveFileCollision(.skip) }
            Button("Replace", role: .destructive) { viewModel.resolveFileCollision(.replace) }
            Button("Keep Both") { viewModel.resolveFileCollision(.keepBoth) }
        } message: { collision in
            Text("\"\(collision.destinationURL.lastPathComponent)\" already exists in \"\(collision.destinationURL.deletingLastPathComponent().lastPathComponent)\". Choose whether to replace it or keep both items.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Browser pane: \(viewModel.currentDirName)\(isActive ? ", active" : "")")
        .accessibilityIdentifier("browserPane-\(pane.id)")
    }

    private var singlePaneContent: some View {
        @Bindable var model = viewModel
        return VStack {
            if !viewModel.searchText.isEmpty {
                HStack {
                    Picker("Search scope", selection: $model.searchScope) {
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

            HSplitView {
                browserItems.frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                if pane.isPreviewPresented {
                    preview.frame(minWidth: 260, idealWidth: 300, maxWidth: 500, maxHeight: .infinity)
                }
            }
        }
    }

    private var splitContent: some View {
        VStack(spacing: 0) {
            if showsPaneHeader { navigationBar }
            if (showsPaneHeader && showsSearch) || !viewModel.searchText.isEmpty { searchBar }
            if showsPaneHeader || !viewModel.searchText.isEmpty { Divider() }
            fileContent
                .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
                .overlay {
                    if isDockTargeted {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.accentColor.opacity(0.65), lineWidth: 2)
                            .padding(3)
                            .allowsHitTesting(false)
                    }
                }
                .dropDestination(for: PaneDrag.self) { items, point in
                    guard let item = items.first, showsPaneControls, !isExpanded else { return false }
                    let edges = [point.x, contentSize.width - point.x, point.y, contentSize.height - point.y]
                    guard let edge = edges.indices.min(by: { edges[$0] < edges[$1] }),
                          edges[edge] <= 48 else { return false }
                    return onDock(item.id, edge >= 2, edge == 0 || edge == 2)
                } isTargeted: { isDockTargeted = $0 && showsPaneControls && !isExpanded }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 4) {
            Button { activateBrowser(); viewModel.goBackward() } label: { Image(systemName: "chevron.left") }
                .disabled(viewModel.historyBackward.isEmpty)
                .help("Go Back")
                .accessibilityLabel("Go Back")
            Button { activateBrowser(); viewModel.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(viewModel.historyForward.isEmpty)
                .help("Go Forward")
                .accessibilityLabel("Go Forward")
            Button {
                activateBrowser()
                guard viewModel.currentDir.path != "/" else { return }
                viewModel.goToParentDirectory()
                goUpTrigger += 1
            } label: {
                Image(systemName: "arrow.up")
                    .symbolEffect(.bounce.byLayer, options: .speed(8), value: goUpTrigger)
            }
            .opacity(viewModel.currentDir.path == "/" ? 0.4 : 1)
            .help("Go To Parent Directory")
            .accessibilityLabel("Go To Parent Directory")
            .background(isMoveUpTargeted ? Color.accentColor.opacity(0.25) : Color.clear, in: Capsule())
            .dropDestination(for: URL.self) { urls, _ in
                guard viewModel.currentDir.path != "/" else { return false }
                onActivate()
                viewModel.handleDrop(urls: urls, to: viewModel.currentDir.deletingLastPathComponent())
                return true
            } isTargeted: { isMoveUpTargeted = $0 && viewModel.currentDir.path != "/" }

            if showsPaneControls && !isExpanded {
                Image(systemName: "folder")
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .padding(.leading, 4)
                    .draggable(PaneDrag(id: pane.id))
                    .help("Drag this folder icon to another pane’s edge to dock")
                    .accessibilityLabel("Pane drag handle")
            }

            InteractivePathTitleView(
                fullPath: viewModel.currentDir.path,
                folderName: viewModel.currentDirName,
                onNavigate: { activateBrowser(); viewModel.navigateTo(url: $0) },
                onGoToFolder: { onActivate(); viewModel.isJumpToPathPresented = true },
                onActivate: onActivate
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onActivate()
                if showsSearch || !viewModel.searchText.isEmpty {
                    viewModel.searchText = ""
                    showsSearch = false
                } else {
                    showsSearch = true
                }
            } label: { Image(systemName: "magnifyingglass") }
            .help("Search This Pane")
            .accessibilityLabel("Search This Pane")

            Menu {
                Button("Split Right", systemImage: "rectangle.split.2x1") { onSplit(false) }
                    .disabled(!canSplit)
                Button("Split Down", systemImage: "rectangle.split.1x2") { onSplit(true) }
                    .disabled(!canSplit)
                Divider()
                PaneOptionsMenu(pane: pane, onActivate: onActivate)
                Divider()
                Button("Refresh", systemImage: "arrow.clockwise") { activateBrowser(); viewModel.loadCurrentDirectory() }
                if showsPaneControls {
                    Divider()
                    Button(isExpanded ? "Show All Panes" : "Expand Pane", systemImage: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", action: onExpand)
                    Button("Close Pane", systemImage: "xmark", action: onClose)
                }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Pane Options")
            .accessibilityLabel("Pane Options")
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Material.bar)
    }

    private var searchBar: some View {
        @Bindable var model = viewModel
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search this pane", text: $model.searchText)
                    .focused($isSearchFocused)
                    .onAppear { if showsSearch { isSearchFocused = true } }
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search this pane")
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Clear Search")
                        .accessibilityLabel("Clear Search")
                }
            }
            if !viewModel.searchText.isEmpty {
                Picker("Search scope", selection: $model.searchScope) {
                    Text(viewModel.currentDirName).tag(SearchScope.currentFolder)
                    Text("This Mac").tag(SearchScope.thisMac)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Material.ultraThin)
    }

    @ViewBuilder private var fileContent: some View {
        if pane.isPreviewPresented && paneWidth >= 620 {
            HSplitView {
                fileBrowser.frame(minWidth: 280)
                preview.frame(minWidth: 260, idealWidth: 300, maxWidth: 500)
            }
        } else {
            fileBrowser
                .overlay(alignment: .trailing) {
                    if pane.isPreviewPresented {
                        preview
                            .frame(maxWidth: min(320, max(260, paneWidth - 24)))
                            .overlay(alignment: .leading) { Divider() }
                            .shadow(color: .black.opacity(0.12), radius: 8, x: -4)
                    }
                }
        }
    }

    private var preview: some View {
        FilePreviewPanel(files: viewModel.previewFiles) { pane.isPreviewPresented = false }
    }

    @ViewBuilder private var browserItems: some View {
        if pane.viewStyle == .list { listView } else { gridView }
    }

    private var fileBrowser: some View {
        browserItems
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if viewModel.isLoadingDirectory && viewModel.files.isEmpty {
                ProgressView().controlSize(.small).allowsHitTesting(false)
            } else if let error = viewModel.directoryLoadError {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark").font(.title)
                    Text("Unable to Open Folder").font(.headline)
                    Text(error).font(.caption).multilineTextAlignment(.center)
                    Button("Try Again") { viewModel.loadCurrentDirectory() }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.sortedFiles) { file in
                    FileListItemView(
                        file: file,
                        isCompact: showsPaneControls && paneWidth < 520,
                        isSelected: viewModel.selectedFileIds.contains(file.id),
                        isTargeted: dropTargetedFileId == file.id,
                        onTap: {
                            handleTap(for: file, in: viewModel.sortedFiles)
                        },
                        onRightClick: {
                            handleRightClick(for: file)
                        },
                        onDoubleTap: {
                            activateBrowser()
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
        .contextMenu {
            FolderContextMenu(viewModel: viewModel)
        }
    }

    private var gridStatusBar: some View {
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
                    .fixedSize(horizontal: !showsPaneControls, vertical: false)
                    .frame(maxWidth: showsPaneControls ? 160 : nil)
                    .lineLimit(showsPaneControls ? 1 : nil)
                    .disabled(viewModel.gitUncommittedCount > 0)
                    .help(viewModel.gitUncommittedCount > 0 ? "Cannot switch branches with uncommitted changes" : "Switch Git Branch")

                    if (!showsPaneControls || paneWidth > 460) && viewModel.gitUncommittedCount > 0 {
                        Text("(\(viewModel.gitUncommittedCount) uncommitted)")
                            .foregroundStyle(.orange)
                    } else if !showsPaneControls || paneWidth > 460 {
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

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridCols, spacing: compactGrid ? 8 : 16) {
                ForEach(viewModel.sortedFiles) { file in
                    FileGridItemView(
                        file: file,
                        isCompact: compactGrid,
                        isSelected: viewModel.selectedFileIds.contains(file.id),
                        isTargeted: dropTargetedFileId == file.id,
                        onTap: {
                            handleTap(for: file, in: viewModel.sortedFiles)
                        },
                        onRightClick: {
                            handleRightClick(for: file)
                        },
                        onDoubleTap: {
                            activateBrowser()
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
            .padding(.all, compactGrid ? 8 : nil)
        }
        .safeAreaInset(edge: .bottom) { gridStatusBar }
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
                        activateBrowser()
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
