import SwiftUI

struct ContentView: View {
    @Environment(\.undoManager) private var undoManager
    @Environment(\.openWindow) private var openWindow
    @State private var workspace: BrowserWorkspace
    private let tabTransfers: BrowserTabTransfers?
    private let transferID: UUID?
    @State private var showSplash = !SplashOverlay.hasShownSplashInThisSession

    @State private var refreshTrigger = 0
    @State private var goUpTrigger = 0
    @State private var isMoveUpTargeted = false
    @State private var windowWidth: CGFloat = 400

    @State private var paneFrames: [UUID: CGRect] = [:]
    @State private var tabDrag = BrowserTabDragState()
    @State private var displayedTabModels: [UUID: FolderViewModel] = [:]

    init(tabTransfers: BrowserTabTransfers? = nil, transferID: UUID? = nil) {
        self.tabTransfers = tabTransfers
        self.transferID = transferID
        _workspace = State(initialValue: BrowserWorkspace(initialTab: transferID.flatMap { tabTransfers?.tab(for: $0) }))
    }

    private var viewModel: FolderViewModel { workspace.activePane.viewModel }

    private var displayedTabs: [BrowserTab] {
        let panes = workspace.isActivePaneExpanded ? [workspace.activePane] : workspace.panes
        return panes.map(\.selectedTab)
    }

    var body: some View {
        @Bindable var activePane = workspace.activePane
        @Bindable var model = viewModel
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .id(workspace.activePaneID)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 420)
        } detail: {
            DeferredSidebarDetail(content: paneLayout)
                .frame(minWidth: detailMinimumSize.width, minHeight: detailMinimumSize.height)
                .overlay(alignment: .topLeading) { BrowserTabDragOverlay(drag: tabDrag) }
                .coordinateSpace(name: "browserWorkspaceTabs")
                .onExitCommand { workspace.isPlacingPane = false }
                .navigationTitle("")
                .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search")
        }
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
                WindowPathTitleView(
                    fullPath: viewModel.currentDir.path,
                    folderName: viewModel.currentDirName,
                    width: $windowWidth
                )
            }

            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $activePane.isPreviewPresented) {
                    Label("Preview", systemImage: "sidebar.right")
                }
                .help(activePane.isPreviewPresented ? "Hide Preview" : "Show Preview")
                .accessibilityIdentifier("toggleFilePreview")
            }

            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $model.showHiddenFiles) {
                    Label("Show Hidden", systemImage: viewModel.showHiddenFiles ? "eye" : "eye.slash")
                }
                .help(viewModel.showHiddenFiles ? "Hide Hidden" : "Show Hidden")
            }

            ToolbarItem(placement: .primaryAction) {
                Picker("Sort By", selection: $model.currentSortingOption) {
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
                Picker("View Style", selection: $activePane.viewStyle) {
                    ForEach(FileViewStyle.allCases) { style in
                        Label(style.rawValue, systemImage: style.iconName)
                            .tag(style)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 64)
                .help("View Options")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(BrowserLayout.allCases) { layout in
                        Button { workspace.setLayout(layout) } label: {
                            Label(layout.rawValue, systemImage: selectedLayout == layout ? "checkmark" : layout.symbol)
                        }
                    }
                    Divider()
                    Button(workspace.isPlacingPane ? "Cancel Placement" : "Place New Pane…") {
                        if workspace.isPlacingPane {
                            workspace.isPlacingPane = false
                        } else {
                            workspace.beginPanePlacement()
                        }
                    }
                    Button("New Tab") { workspace.newTab(in: workspace.activePaneID) }
                    Toggle("Show Pane Headers", isOn: $workspace.showsPaneHeaders)
                } label: {
                    Label("Split View", systemImage: selectedLayout?.symbol ?? "rectangle.split.2x2")
                }
                .help("Split View Layout")
                .disabled(workspace.hasPresentedDialog)
                .accessibilityIdentifier("splitViewMenu")
            }
        }
        .toolbar(showSplash ? .hidden : .automatic)
        .overlay { SplashOverlay(isPresented: $showSplash) }
        .overlay {
            if viewModel.isJumpToPathPresented {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.isJumpToPathPresented = false
                        }

                    JumpToPathModalView(viewModel: viewModel, isPresented: $model.isJumpToPathPresented)
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: viewModel.isJumpToPathPresented)
            }
        }
        .overlay {
            if viewModel.isGitCommitPresented {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.isGitCommitPresented = false
                        }

                    GitCommitModalView(viewModel: viewModel, isPresented: $model.isGitCommitPresented)
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: viewModel.isGitCommitPresented)
            }
        }
        .onAppear {
            SoundEffects.warmUpAudioEngine()
            assignUndoManager()
            if let transferID { tabTransfers?.finish(transferID) }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .onChange(of: workspace.activePaneID) { _, _ in isMoveUpTargeted = false }
        .onChange(of: workspace.panes.flatMap { $0.tabs.map(\.id) }) { _, _ in assignUndoManager() }
        .onChange(of: displayedTabs.map(\.id), initial: true) { _, _ in
            updateDisplayedTabModels()
        }
        .focusedSceneValue(\.activeFolderViewModel, viewModel)
        .focusedSceneValue(\.browserWorkspace, workspace)
        .handleKeyboardShortcuts(viewModel: viewModel, openWindow: { openWindow(id: "mainWindow") })
        .onCommand(#selector(NSText.copy(_:))) {
            guard !KeyboardShortcutHandler.isEditingText() else { return }
            if !viewModel.selectedFiles.isEmpty { viewModel.copyFiles(files: viewModel.selectedFiles) }
        }
        .onCommand(#selector(NSText.cut(_:))) {
            guard !KeyboardShortcutHandler.isEditingText() else { return }
            if !viewModel.selectedFiles.isEmpty { viewModel.cutFiles(files: viewModel.selectedFiles) }
        }
        .onCommand(#selector(NSText.paste(_:))) {
            guard !KeyboardShortcutHandler.isEditingText() else { return }
            viewModel.pasteFiles()
        }
    }



    private var selectedLayout: BrowserLayout? {
        if workspace.panes.count == 1 || workspace.isActivePaneExpanded { return .single }
        guard workspace.customArrangement == nil,
              workspace.layout.paneCount == workspace.panes.count else { return nil }
        return workspace.layout
    }

    private var detailMinimumSize: CGSize {
        if workspace.panes.count == 1 { return CGSize(width: 600, height: 400) }
        if workspace.isActivePaneExpanded { return CGSize(width: 230, height: 155) }
        return workspace.arrangement.minimumSize
    }

    @ViewBuilder private var paneLayout: some View {
        if workspace.isActivePaneExpanded || workspace.panes.count == 1 {
            paneView(workspace.activePane)
        } else {
            arrangementView(workspace.arrangement)
        }
    }

    private func arrangementView(_ arrangement: PaneArrangement) -> AnyView {
        switch arrangement {
        case .pane(let id):
            if let pane = workspace.panes.first(where: { $0.id == id }) {
                return AnyView(paneView(pane))
            }
            return AnyView(EmptyView())
        case .split(let vertical, let first, let second):
            return AnyView(DeferredPaneSplit(
                vertical: vertical,
                firstMinimum: vertical ? first.minimumSize.height : first.minimumSize.width,
                secondMinimum: vertical ? second.minimumSize.height : second.minimumSize.width,
                first: arrangementView(first),
                second: arrangementView(second)
            ))
        }
    }

    private func paneView(_ pane: BrowserPane) -> some View {
        BrowserPaneView(
            pane: pane,
            isActive: pane.id == workspace.activePaneID,
            showsPaneControls: workspace.panes.count > 1,
            showsPaneHeader: workspace.showsPaneHeaders,
            onActivate: {
                if pane.id != workspace.activePaneID && !workspace.hasPresentedDialog {
                    workspace.activate(pane.id)
                }
            },
            canSplit: workspace.canAddPane,
            onSplit: { workspace.splitPane(pane.id, vertically: $0) },
            onNewTab: { workspace.newTab(in: pane.id) },
            onSelectTab: { workspace.selectTab($0, in: pane.id) },
            onCloseTab: { workspace.closeTab($0, in: pane.id) },
            onTabDrag: { tab, point, phase in
                updateTabDrag(tab, from: pane.id, at: point, phase: phase)
            }
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("browserWorkspaceTabs")) } action: {
            paneFrames[pane.id] = $0
        }
        .overlay { PaneOpeningOverlay(pane: pane) }
        .overlay {
            if workspace.isPlacingPane && workspace.canAddPane {
                PanePlacementOverlay(folderName: pane.viewModel.currentDirName) { edge in
                    workspace.splitPane(pane.id, vertically: edge == .top || edge == .bottom,
                                        before: edge == .leading || edge == .top)
                }
            }
        }
        .id(pane.id)
        .frame(
            minWidth: workspace.panes.count == 1 ? 600 : 230,
            maxWidth: .infinity,
            minHeight: workspace.panes.count == 1 ? 400 : 155,
            maxHeight: .infinity
        )
    }

    private func updateTabDrag(_ tab: BrowserTab, from sourceID: UUID, at point: CGPoint, phase: BrowserTabDragPhase) {
        switch phase {
        case .dragging:
            if !tabDrag.isDragging {
                tabDrag.isDragging = true
                tabDrag.guides = tabDropGuides(from: sourceID)
            }
            let target = tabTarget(at: point, in: tabDrag.guides)
            let preview = target.map { BrowserTabDragState.Preview(frame: $0.frame, zone: $0.zone) }
            if tabDrag.preview != preview { tabDrag.preview = preview }
            return
        case .dropped:
            if let target = tabTarget(at: point, in: tabDropGuides(from: sourceID)) {
                workspace.moveTab(tab.id, to: target.paneID, split: target.zone.split)
            }
        case .droppedOutside(let window):
            moveTabToNewWindow(tab, from: sourceID, sourceWindow: window)
        case .cancelled:
            break
        }

        tabDrag.isDragging = false
        tabDrag.preview = nil
        tabDrag.guides = []
    }

    private func moveTabToNewWindow(_ tab: BrowserTab, from sourceID: UUID, sourceWindow: NSWindow) {
        guard let tabTransfers, !workspace.hasPresentedDialog, !workspace.isPlacingPane,
              let source = workspace.panes.first(where: { $0.id == sourceID }),
              source.tabs.contains(where: { $0 === tab }) else { return }

        let transferID = tabTransfers.prepare(tab) { [weak sourceWindow] in
            // The destination now owns visibility and directory monitoring.
            displayedTabModels.removeValue(forKey: tab.id)
            if workspace.panes.count == 1 && source.tabs.count == 1 {
                sourceWindow?.close()
            } else {
                workspace.closeTab(tab.id, in: sourceID)
            }
        }
        openWindow(id: "mainWindow", value: transferID)
    }

    private func tabDropGuides(from sourceID: UUID) -> [BrowserTabDragState.Guide] {
        guard !workspace.hasPresentedDialog, !workspace.isPlacingPane,
              let source = workspace.panes.first(where: { $0.id == sourceID }) else { return [] }
        let visiblePanes = workspace.isActivePaneExpanded ? [workspace.activePane] : workspace.panes
        return visiblePanes.compactMap { pane in
            guard let frame = paneFrames[pane.id] else { return nil }
            let isSource = pane.id == sourceID
            guard !isSource || source.tabs.count > 1 else { return nil }
            let edges: [TabDropZone] = [.left, .right, .top, .bottom]
            return BrowserTabDragState.Guide(
                id: pane.id, frame: frame,
                headerHeight: pane.tabs.count > 1 || workspace.showsPaneHeaders ? 34 : 0,
                zones: isSource ? edges : edges + [.center]
            )
        }
    }

    private func tabTarget(at point: CGPoint, in guides: [BrowserTabDragState.Guide]) -> (paneID: UUID, frame: CGRect, zone: TabDropZone)? {
        guard let guide = guides.first(where: { $0.frame.contains(point) }) else { return nil }
        let zone = TabDropZone(
            point: CGPoint(x: point.x - guide.frame.minX, y: point.y - guide.frame.minY),
            size: guide.frame.size, headerHeight: guide.headerHeight
        )
        guard guide.zones.contains(zone) else { return nil }
        return (guide.id, guide.frame, zone)
    }

    private func updateDisplayedTabModels() {
        // Visibility follows selection across the whole window. A pane view can
        // disappear during a transition even while its tab is still selected.
        let current = Dictionary(uniqueKeysWithValues: displayedTabs.map { ($0.id, $0.viewModel) })
        for (id, model) in displayedTabModels where current[id] == nil {
            model.setBrowserVisible(false)
        }
        for (id, model) in current where displayedTabModels[id] == nil {
            model.setBrowserVisible(true)
        }
        displayedTabModels = current
    }

    private func assignUndoManager() {
        for pane in workspace.panes {
            for tab in pane.tabs { tab.viewModel.undoManager = undoManager }
        }
    }
}

#Preview { ContentView() }
