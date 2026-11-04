import AppKit
import Foundation
import Testing
@testable import RiverFlow

@Suite(.serialized) @MainActor
struct BrowserWorkspaceTests {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for name in ["Source", "Destination", "Third", "Fourth"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try Data("pane fixture".utf8).write(to: root.appendingPathComponent("Source/example.txt"))
        return root
    }

    private func workspace(at root: URL) -> BrowserWorkspace {
        BrowserWorkspace(startDir: root) { FolderViewModel(startDir: $0, sidebarRoots: []) }
    }

    @Test("Four panes keep navigation, search, selection and display settings independent")
    func fourPanesKeepNavigationSearchSelectionAndDisplaySettingsIndependent() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = workspace(at: root)
        workspace.setLayout(.grid)
        #expect(workspace.panes.count == 4)
        #expect(Set(workspace.panes.map(\.id)).count == 4)
        let first = workspace.panes[0]
        let second = workspace.panes[1]
        first.viewModel.navigateTo(url: root.appendingPathComponent("Source"))
        let selected = try #require(first.viewModel.files.first)
        first.viewModel.selectedFileIds = [selected.id]
        first.viewModel.searchText = "example"
        first.viewStyle = .list
        first.isPreviewPresented = true
        first.viewModel.showHiddenFiles = true
        second.viewModel.navigateTo(url: root.appendingPathComponent("Destination"))
        second.viewModel.goBackward()
        #expect(first.viewModel.currentDir == root.appendingPathComponent("Source"))
        #expect(first.viewModel.selectedFileIds == [selected.id])
        #expect(first.viewModel.historyBackward == [root])
        #expect(second.viewModel.currentDir == root)
        #expect(second.viewModel.searchText.isEmpty)
        #expect(second.viewModel.selectedFileIds.isEmpty)
        #expect(!second.viewModel.showHiddenFiles)
        #expect(second.viewStyle == .grid)
        #expect(!second.isPreviewPresented)
        #expect(workspace.panes[2].viewModel.historyBackward.isEmpty)
    }

    @Test("Layout reduction retains the active model and closing never removes the final pane")
    func layoutReductionRetainsTheActiveModelAndClosingNeverRemovesTheFinalPane() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = workspace(at: root)
        workspace.setLayout(.grid)
        let active = workspace.panes[3]
        workspace.activate(active.id)
        active.viewModel.searchText = "keep me"
        workspace.setLayout(.rows)
        #expect(workspace.panes.count == 2)
        #expect(workspace.activePane === active)
        workspace.setLayout(.columns)
        #expect(workspace.activePane === active)
        #expect(active.viewModel.searchText == "keep me")
        workspace.closePane(active.id)
        #expect(workspace.panes.count == 1)
        #expect(workspace.layout == .single)
        #expect(workspace.panes.contains { $0.id == workspace.activePaneID })
        workspace.closePane(workspace.activePaneID)
        #expect(workspace.panes.count == 1)
    }

    @Test("Adding, cycling, expanding and closing panes preserves existing state")
    func addingCyclingExpandingAndClosingPanesPreservesExistingState() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = workspace(at: root)
        let first = workspace.activePane
        first.viewModel.navigateTo(url: root.appendingPathComponent("Source"))
        workspace.addPane()
        #expect(workspace.activePane.viewModel.currentDir == first.viewModel.currentDir)
        #expect(workspace.activePane.viewModel !== first.viewModel)
        workspace.addPane()
        workspace.addPane()
        workspace.addPane()
        #expect(workspace.panes.count == 4)
        workspace.focusNextPane()
        #expect(workspace.activePane === first)
        workspace.isActivePaneExpanded = true
        workspace.focusNextPane()
        #expect(workspace.panes.count == 4)
        workspace.closePane(workspace.activePaneID)
        #expect(workspace.panes.count == 3)
        #expect(!workspace.isActivePaneExpanded)
        #expect(workspace.layout == .grid)
    }

    @Test("Placement can split a specific pane before its existing content in a four-pane layout")
    func placementCanSplitSpecificPaneBeforeItsExistingContentInFourPaneLayout() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = workspace(at: root)
        workspace.setLayout(.grid)
        let target = workspace.panes[3]
        let otherPane = workspace.activePane

        workspace.beginPanePlacement()
        #expect(workspace.isPlacingPane)
        workspace.splitPane(target.id, vertically: true, before: true)

        #expect(workspace.panes.count == 5)
        #expect(!workspace.isPlacingPane)
        #expect(workspace.panes.contains { $0 === otherPane })
        let inserted = workspace.activePane
        guard case .split(true, _, .split(false, _, .split(true, .pane(inserted.id), .pane(target.id)))) = workspace.arrangement else {
            Issue.record("Expected a new pane above the selected lower-right pane")
            return
        }
    }

    @Test("Directional splits and docking retain the original pane models")
    func directionalSplitsAndDockingRetainTheOriginalPaneModels() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = workspace(at: root)
        let first = workspace.activePane
        workspace.splitPane(first.id, vertically: false)
        let right = workspace.activePane
        workspace.splitPane(right.id, vertically: true)
        let bottom = workspace.activePane
        right.viewModel.searchText = "keep me"

        guard case .split(false, .pane(first.id), .split(true, .pane(right.id), .pane(bottom.id))) = workspace.arrangement else {
            Issue.record("Expected the right pane to split into two rows")
            return
        }
        #expect(workspace.dockPane(bottom.id, beside: first.id, vertically: true, before: true))
        guard case .split(false, .split(true, .pane(bottom.id), .pane(first.id)), .pane(right.id)) = workspace.arrangement else {
            Issue.record("Expected the moved pane above the first pane")
            return
        }
        #expect(right.viewModel.searchText == "keep me")
        workspace.closePane(bottom.id)
        guard case .split(false, .pane(first.id), .pane(right.id)) = workspace.arrangement else {
            Issue.record("Expected the empty split to collapse")
            return
        }
    }

    @Test("Presented dialogs keep pane commands attached to their owner")
    func presentedDialogsKeepPaneCommandsAttachedToTheirOwner() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = workspace(at: root)
        workspace.setLayout(.grid)
        let active = workspace.activePane
        active.viewModel.isJumpToPathPresented = true
        workspace.focusNextPane()
        workspace.closePane(active.id)
        workspace.setLayout(.single)
        #expect(workspace.activePane === active)
        #expect(workspace.panes.count == 4)
    }

    @Test("Copy and cut transfer between panes using the current clipboard")
    func copyAndCutTransferBetweenPanesUsingTheCurrentClipboard() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let clipboard = NSPasteboard.withUniqueName()
        defer { clipboard.releaseGlobally() }
        let source = FolderViewModel(startDir: root.appendingPathComponent("Source"), sidebarRoots: [], filePasteboard: clipboard)
        let destination = FolderViewModel(startDir: root.appendingPathComponent("Destination"), sidebarRoots: [], filePasteboard: clipboard)
        let item = try #require(source.files.first)
        source.copyFiles(files: [item])
        destination.pasteFiles()
        #expect(FileManager.default.fileExists(atPath: item.url.path))
        #expect(destination.files.contains { $0.name == "example.txt" })
        source.cutFiles(files: [item])
        destination.navigateTo(url: root.appendingPathComponent("Third"))
        destination.pasteFiles()
        #expect(!FileManager.default.fileExists(atPath: item.url.path))
        #expect(destination.files.contains { $0.name == "example.txt" })
        #expect(clipboard.readObjects(forClasses: [NSURL.self])?.isEmpty ?? true)
        let newItem = try #require(destination.files.first)
        destination.copyFiles(files: [newItem])
        source.navigateTo(url: root.appendingPathComponent("Fourth"))
        source.pasteFiles()
        #expect(source.files.contains { $0.name == "example.txt" })
        clipboard.clearContents()
        clipboard.setString("a copied folder path", forType: .string)
        source.pasteFiles()
        #expect(source.files.count == 1)
    }

    @Test("Async navigation rejects stale reads and watchers preserve selection")
    func asyncNavigationRejectsStaleReadsAndWatchersPreserveSelection() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = FolderViewModel(startDir: root, sidebarRoots: [], loadsAsynchronously: true)
        model.navigateTo(url: root.appendingPathComponent("Destination"))
        model.navigateTo(url: root.appendingPathComponent("Source"))
        try await waitUntil { !model.isLoadingDirectory }
        #expect(model.currentDir == root.appendingPathComponent("Source"))
        let selected = try #require(model.files.first { $0.name == "example.txt" })
        model.selectedFileIds = [selected.id]
        try Data().write(to: model.currentDir.appendingPathComponent("new.txt"))
        try await waitUntil { model.files.count == 2 }
        #expect(model.selectedFileIds == [selected.id])
        #expect(model.files.first { $0.name == "example.txt" }?.id == selected.id)
        model.navigateTo(url: root.appendingPathComponent("Destination"))
        try await waitUntil { !model.isLoadingDirectory }
        #expect(model.files.isEmpty)
        #expect(model.selectedFileIds.isEmpty)
    }

    @Test("Path navigation lists current folder through root without duplicates")
    func pathNavigationListsCurrentFolderThroughRootWithoutDuplicates() {
        #expect(InteractivePathTitleView.ancestorURLs(for: "/").map(\.path) == ["/"])
        #expect(InteractivePathTitleView.ancestorURLs(for: "/Users/example/Project").map(\.path) == [
            "/Users/example/Project", "/Users/example", "/Users", "/"
        ])
        #expect(InteractivePathTitleView.ancestorURLs(for: "/tmp/Folder With Spaces/../Other/").first?.path == "/tmp/Other")
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(condition(), "Timed out waiting for directory update")
    }
}
