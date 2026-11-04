import Foundation
import Observation

/// Long-lived pane state survives resizing and changes to the split hierarchy.
@Observable
final class BrowserPane: Identifiable {
    let id = UUID()
    let viewModel: FolderViewModel
    var viewStyle: FileViewStyle = .grid
    var isPreviewPresented = false

    init(viewModel: FolderViewModel) {
        self.viewModel = viewModel
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

indirect enum PaneArrangement {
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
    var showsPaneHeaders = false
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
              panes.contains(where: { $0.id == id }), panes.contains(where: { $0.id == target }) else { return false }
        let moved = PaneArrangement.pane(id)
        let destination = PaneArrangement.pane(target)
        customArrangement = arrangement.replacing(id, with: nil)?.replacing(target, with:
            .split(vertical: vertically, before ? moved : destination, before ? destination : moved))
        activate(id)
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
        guard canAddPane, panes.count < BrowserLayout.grid.paneCount else { return }
        if customArrangement != nil {
            splitPane(activePaneID, vertically: false)
            return
        }
        let pane = duplicate(activePane)
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
            let retained = Array(panes.filter { $0.id != active.id }.prefix(newLayout.paneCount - 1))
            let retainedIDs = Set((retained + [active]).map(\.id))
            panes.removeAll { !retainedIDs.contains($0.id) }
        }
        while panes.count < newLayout.paneCount { addPane() }
        activePaneID = active.id
        layout = newLayout
        isActivePaneExpanded = false
    }

    func closePane(_ id: UUID) {
        guard !hasPresentedDialog, panes.count > 1, let index = panes.firstIndex(where: { $0.id == id }) else { return }
        isPlacingPane = false
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
