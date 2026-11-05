import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.undoManager) private var undoManager
    @Environment(\.openWindow) private var openWindow
    @State private var workspace = BrowserWorkspace()
    @State private var showSplash = !SplashOverlay.hasShownSplashInThisSession

    @State private var refreshTrigger = 0
    @State private var goUpTrigger = 0
    @State private var isMoveUpTargeted = false
    @State private var windowWidth: CGFloat = 400

    @State private var paneFrames: [UUID: CGRect] = [:]
    @State private var tabDrag = BrowserTabDragState()

    private var viewModel: FolderViewModel { workspace.activePane.viewModel }

    private var paneAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.20) }

    var body: some View {
        @Bindable var activePane = workspace.activePane
        @Bindable var model = viewModel
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .id(workspace.activePaneID)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 420)
        } detail: {
            paneLayout
                .onExitCommand { workspace.isPlacingPane = false }
                .navigationTitle("")
                .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search")
        }
        .overlay(alignment: .topLeading) { BrowserTabDragOverlay(drag: tabDrag) }
        .coordinateSpace(name: "browserWorkspaceTabs")
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
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .onChange(of: workspace.activePaneID) { _, _ in isMoveUpTargeted = false }
        .onChange(of: workspace.panes.flatMap { $0.tabs.map(\.id) }) { _, _ in assignUndoManager() }
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

    @ViewBuilder private var paneLayout: some View {
        if workspace.isActivePaneExpanded || workspace.panes.count == 1 {
            paneView(workspace.activePane)
        } else {
            let arrangement = workspace.arrangement
            arrangementView(arrangement)
                .frame(minWidth: arrangement.minimumSize.width, minHeight: arrangement.minimumSize.height)
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
            onTabDrag: { tab, point, ended in
                updateTabDrag(tab, from: pane.id, at: point, ended: ended)
            }
        )
        .id(pane.selectedTabID)
        .transition(.opacity)
        .animation(paneAnimation, value: pane.selectedTabID)
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

    private func updateTabDrag(_ tab: BrowserTab, from sourceID: UUID, at point: CGPoint, ended: Bool) {
        let target = tabTarget(at: point, from: sourceID)
        if ended {
            tabDrag.title = nil
            tabDrag.preview = nil
            if let target {
                workspace.moveTab(tab.id, to: target.paneID, split: target.zone.split)
            }
        } else {
            if tabDrag.title == nil { tabDrag.title = tab.viewModel.currentDirName }
            tabDrag.position = point
            let preview = target.map { BrowserTabDragState.Preview(frame: $0.frame, zone: $0.zone) }
            if tabDrag.preview != preview { tabDrag.preview = preview }
        }
    }

    private func tabTarget(at point: CGPoint, from sourceID: UUID) -> (paneID: UUID, frame: CGRect, zone: TabDropZone)? {
        guard !workspace.hasPresentedDialog, !workspace.isPlacingPane else { return nil }
        let visiblePanes = workspace.isActivePaneExpanded ? [workspace.activePane] : workspace.panes
        guard let pane = visiblePanes.first(where: { paneFrames[$0.id]?.contains(point) == true }),
              let frame = paneFrames[pane.id] else { return nil }
        let hasHeader = pane.tabs.count > 1 || workspace.showsPaneHeaders
        let zone = TabDropZone(
            point: CGPoint(x: point.x - frame.minX, y: point.y - frame.minY),
            size: frame.size, headerHeight: hasHeader ? 34 : 0
        )
        if pane.id == sourceID && (zone == .center || pane.tabs.count == 1) { return nil }
        return (pane.id, frame, zone)
    }

    private func assignUndoManager() {
        for pane in workspace.panes {
            for tab in pane.tabs { tab.viewModel.undoManager = undoManager }
        }
    }
}

#Preview { ContentView() }
