import Foundation
import Observation

/// A tab carries its browser state when moved to another pane.
@Observable
final class BrowserTab: Identifiable {
    let id = UUID()
    let viewModel: FolderViewModel
    var viewStyle: FileViewStyle = .grid
    var isPreviewPresented = false

    init(viewModel: FolderViewModel) {
        self.viewModel = viewModel
    }
}

@Observable
final class BrowserPane: Identifiable {
    let id = UUID()
    private(set) var tabs: [BrowserTab]
    private(set) var selectedTabID: UUID
    fileprivate(set) var opening: PaneOpening?

    convenience init(viewModel: FolderViewModel) {
        self.init(tab: BrowserTab(viewModel: viewModel))
    }

    init(tab: BrowserTab) {
        tabs = [tab]
        selectedTabID = tab.id
    }

    func finishOpening(_ id: UUID) {
        if opening?.id == id { opening = nil }
    }

    var selectedTab: BrowserTab { tabs.first { $0.id == selectedTabID } ?? tabs[0] }
    var viewModel: FolderViewModel { selectedTab.viewModel }
    var viewStyle: FileViewStyle {
        get { selectedTab.viewStyle }
        set { selectedTab.viewStyle = newValue }
    }
    var isPreviewPresented: Bool {
        get { selectedTab.isPreviewPresented }
        set { selectedTab.isPreviewPresented = newValue }
    }

    fileprivate func selectTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
        viewModel.reloadSidebarFavorites()
    }

    fileprivate func appendTab(_ tab: BrowserTab) {
        tabs.append(tab)
        selectTab(tab.id)
    }

    fileprivate func removeTab(_ id: UUID) {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if selectedTabID == id {
            selectTab(tabs[min(index, tabs.count - 1)].id)
        }
    }
}

enum BrowserLayout: String, CaseIterable, Identifiable {
    case single = "Single Pane"
    case columns = "Two Columns"
    case rows = "Two Rows"
    case grid = "Four Panes"

    var id: Self { self }
    var paneCount: Int {
        switch self {
        case .single: return 1
        case .columns, .rows: return 2
        case .grid: return 4
        }
    }
    var symbol: String {
        switch self {
        case .single: return "rectangle"
        case .columns: return "rectangle.split.2x1"
        case .rows: return "rectangle.split.1x2"
        case .grid: return "square.grid.2x2"
        }
    }
}

struct TabSplit {
    let vertical: Bool
    let before: Bool
}

struct PaneOpening {
    let id = UUID()
    let direction: TabSplit
}

indirect enum PaneArrangement: Equatable {
    case pane(UUID)
    case split(vertical: Bool, PaneArrangement, PaneArrangement)

    func replacing(_ id: UUID, with replacement: Self?) -> Self? {
        switch self {
        case .pane(let current): return current == id ? replacement : self
        case .split(let vertical, let first, let second):
            let left = first.replacing(id, with: replacement)
            let right = second.replacing(id, with: replacement)
            if let left, let right { return .split(vertical: vertical, left, right) }
            return left ?? right
        }
    }
}

@Observable
final class BrowserWorkspace {
    private(set) var panes: [BrowserPane]
    private(set) var activePaneID: UUID
    private(set) var layout: BrowserLayout = .single
    private(set) var customArrangement: PaneArrangement?
    var isActivePaneExpanded = false
    var showsPaneHeaders = true
    var isPlacingPane = false
    private let makeViewModel: (URL) -> FolderViewModel

    init(startDir: URL = URL(fileURLWithPath: PathAutocompleteService.userHomeDirectory),
         makeViewModel: @escaping (URL) -> FolderViewModel = { FolderViewModel(startDir: $0, loadsAsynchronously: true) }) {
        self.makeViewModel = makeViewModel
        let first = BrowserPane(viewModel: makeViewModel(startDir))
        panes = [first]
        activePaneID = first.id
    }

    var activePane: BrowserPane { panes.first { $0.id == activePaneID } ?? panes[0] }
    var hasPresentedDialog: Bool {
        let model = activePane.viewModel
        return model.isJumpToPathPresented || model.isGitCommitPresented || model.fileCollision != nil
    }
    var canAddPane: Bool { !hasPresentedDialog }

    func activate(_ id: UUID) {
        guard !hasPresentedDialog, panes.contains(where: { $0.id == id }), activePaneID != id else { return }
        activePaneID = id
        activePane.viewModel.reloadSidebarFavorites()
    }

    var arrangement: PaneArrangement {
        if let customArrangement { return customArrangement }
        let nodes = panes.map { PaneArrangement.pane($0.id) }
        switch nodes.count {
        case 1: return nodes[0]
        case 2: return .split(vertical: layout == .rows, nodes[0], nodes[1])
        default:
            let bottom = nodes.count == 4 ? PaneArrangement.split(vertical: false, nodes[2], nodes[3]) : nodes[2]
            return .split(vertical: true, .split(vertical: false, nodes[0], nodes[1]), bottom)
        }
    }

    func beginPanePlacement() {
        guard canAddPane else { return }
        isActivePaneExpanded = false
        isPlacingPane = true
    }

    func splitPane(_ id: UUID, vertically: Bool, before: Bool = false) {
        guard canAddPane, let source = panes.first(where: { $0.id == id }) else { return }
        let pane = duplicate(source)
        pane.opening = PaneOpening(direction: TabSplit(vertical: vertically, before: before))
        let existing = PaneArrangement.pane(id)
        let inserted = PaneArrangement.pane(pane.id)
        customArrangement = arrangement.replacing(id, with:
            .split(vertical: vertically, before ? inserted : existing, before ? existing : inserted))
        isPlacingPane = false
        panes.append(pane)
        activate(pane.id)
        isActivePaneExpanded = false
    }

    @discardableResult
    func dockPane(_ id: UUID, beside target: UUID, vertically: Bool, before: Bool) -> Bool {
        guard !hasPresentedDialog, id != target, !isActivePaneExpanded,
              let pane = panes.first(where: { $0.id == id }),
              panes.contains(where: { $0.id == target }) else { return false }
        let moved = PaneArrangement.pane(id)
        let destination = PaneArrangement.pane(target)
        customArrangement = arrangement.replacing(id, with: nil)?.replacing(target, with:
            .split(vertical: vertically, before ? moved : destination, before ? destination : moved))
        pane.opening = PaneOpening(direction: TabSplit(vertical: vertically, before: before))
        activate(id)
        return true
    }

    func newTab(in paneID: UUID) {
        guard !hasPresentedDialog, let pane = panes.first(where: { $0.id == paneID }) else { return }
        pane.appendTab(duplicate(pane).selectedTab)
        activate(paneID)
    }

    func selectTab(_ tabID: UUID, in paneID: UUID) {
        guard !hasPresentedDialog, let pane = panes.first(where: { $0.id == paneID }) else { return }
        pane.selectTab(tabID)
        activate(paneID)
    }

    func closeTab(_ tabID: UUID, in paneID: UUID) {
        guard !hasPresentedDialog, let pane = panes.first(where: { $0.id == paneID }),
              pane.tabs.contains(where: { $0.id == tabID }) else { return }
        if pane.tabs.count == 1 {
            closePane(paneID)
        } else {
            pane.removeTab(tabID)
        }
    }

    @discardableResult
    func moveTab(_ tabID: UUID, to targetID: UUID, split: TabSplit? = nil) -> Bool {
        guard !hasPresentedDialog, !isPlacingPane,
              let source = panes.first(where: { $0.tabs.contains { $0.id == tabID } }),
              let tab = source.tabs.first(where: { $0.id == tabID }),
              let target = panes.first(where: { $0.id == targetID }) else { return false }

        if let split {
            if source.tabs.count == 1 {
                return dockPane(source.id, beside: targetID, vertically: split.vertical, before: split.before)
            }
            let newPane = BrowserPane(tab: tab)
            newPane.opening = PaneOpening(direction: split)
            let existing = PaneArrangement.pane(targetID)
            let inserted = PaneArrangement.pane(newPane.id)
            customArrangement = arrangement.replacing(targetID, with:
                .split(vertical: split.vertical, split.before ? inserted : existing, split.before ? existing : inserted))
            source.removeTab(tabID)
            panes.append(newPane)
            activate(newPane.id)
            isActivePaneExpanded = false
        } else {
            guard source.id != targetID else { return false }
            if source.tabs.count == 1 {
                closePane(source.id)
            } else {
                source.removeTab(tabID)
            }
            target.appendTab(tab)
            activate(targetID)
        }
        return true
    }

    private func duplicate(_ source: BrowserPane) -> BrowserPane {
        let pane = BrowserPane(viewModel: makeViewModel(source.viewModel.currentDir))
        pane.viewStyle = source.viewStyle
        pane.viewModel.currentSortingOption = source.viewModel.currentSortingOption
        if source.viewModel.showHiddenFiles { pane.viewModel.showHiddenFiles = true }
        return pane
    }

    func addPane() {
        addPane(for: panes.count == 1 ? .columns : .grid)
    }

    private func addPane(for targetLayout: BrowserLayout) {
        guard canAddPane, panes.count < BrowserLayout.grid.paneCount else { return }
        if customArrangement != nil {
            splitPane(activePaneID, vertically: false)
            return
        }
        let pane = duplicate(activePane)
        let opensDown = targetLayout == .rows || (targetLayout == .grid && panes.count == 2)
        pane.opening = PaneOpening(direction: TabSplit(vertical: opensDown, before: false))
        panes.append(pane)
        activePaneID = pane.id
        isActivePaneExpanded = false
        layout = panes.count > 2 ? .grid : .columns
    }

    func setLayout(_ newLayout: BrowserLayout) {
        guard !hasPresentedDialog else { return }
        customArrangement = nil
        isPlacingPane = false
        // When reducing the layout, always retain the pane the user is working in.
        let active = activePane
        if panes.count > newLayout.paneCount {
            panes.forEach { $0.opening = nil }
            let retained = Array(panes.filter { $0.id != active.id }.prefix(newLayout.paneCount - 1))
            let retainedIDs = Set((retained + [active]).map(\.id))
            panes.removeAll { !retainedIDs.contains($0.id) }
        }
        while panes.count < newLayout.paneCount { addPane(for: newLayout) }
        activePaneID = active.id
        layout = newLayout
        isActivePaneExpanded = false
    }

    func closePane(_ id: UUID) {
        guard !hasPresentedDialog, panes.count > 1, let index = panes.firstIndex(where: { $0.id == id }) else { return }
        isPlacingPane = false
        panes.forEach { $0.opening = nil }
        customArrangement = customArrangement?.replacing(id, with: nil)
        panes.remove(at: index)
        if activePaneID == id { activate(panes[min(index, panes.count - 1)].id) }
        if panes.count == 1 { layout = .single }
        if panes.count == 2 && layout == .grid { layout = .columns }
        isActivePaneExpanded = false
    }

    func focusNextPane() {
        guard let index = panes.firstIndex(where: { $0.id == activePaneID }) else { return }
        activate(panes[(index + 1) % panes.count].id)
    }
}
