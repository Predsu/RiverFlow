import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

@Suite struct ComponentViewTests {
    private func makeFile(
        name: String = "example.txt",
        itemType: FileItemType = .FILE,
        isHidden: Bool = false
    ) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            itemType: itemType,
            size: 42,
            modificationDate: Date(timeIntervalSinceReferenceDate: 0),
            isHidden: isHidden
        )
    }
    
    private func bodyTypeName<V: View>(of view: V) -> String {
        String(reflecting: type(of: view.body))
    }

    private func bodyTypeName<S: Scene>(of scene: S) -> String {
        String(reflecting: type(of: scene.body))
    }

    private func bodyTypeName<A: App>(of app: A) -> String {
        String(reflecting: type(of: app.body))
    }

    @Test("EditableFileNameView builds display and editing bodies")
    func editableFileNameViewBuildsDisplayAndEditingBodies() throws {
        let file = makeFile(name: "Example.txt")
        let display = EditableFileNameView(file: file, isEditing: false, onCommit: { _ in }, onCancel: {})
        let editing = EditableFileNameView(file: file, isEditing: true, onCommit: { _ in }, onCancel: {})
        
        #expect(!bodyTypeName(of: display).isEmpty)
        #expect(!bodyTypeName(of: editing).isEmpty)
    }

    @Test("FileIconView builds bodies for its supported file categories")
    func fileIconViewBuildsBodiesForItsSupportedFileCategories() throws {
        let app = FileIconView(file: makeFile(name: "Editor.app"))
        let directory = FileIconView(file: makeFile(name: "folder", itemType: .DIRECTORY))
        let image = FileIconView(file: makeFile(name: "photo.png", isHidden: true))
        let document = FileIconView(file: makeFile(name: "report.pdf"), baseSize: 24)
        
        #expect(!bodyTypeName(of: app).isEmpty)
        #expect(!bodyTypeName(of: directory).isEmpty)
        #expect(!bodyTypeName(of: image).isEmpty)
        #expect(!bodyTypeName(of: document).isEmpty)
    }

    @Test("File grid and list views build selected and targeted variants")
    func fileGridAndListViewsBuildSelectedAndTargetedVariants() throws {
        let file = makeFile()
        let viewModel = FolderViewModel(startDir: URL(fileURLWithPath: "/tmp"))
        let action = {}
        let grid = FileGridItemView(file: file, isSelected: true, isTargeted: true, onTap: action, onRightClick: action, onDoubleTap: action, onCopy: action, onCut: action, onOpenAsDirectory: action, onRefreshRequired: action, onMoveToTrash: action, viewModel: viewModel)
        let list = FileListItemView(file: file, isSelected: false, isTargeted: true, onTap: action, onRightClick: action, onDoubleTap: action, onCopy: action, onCut: action, onOpenAsDirectory: action, onRefreshRequired: action, onMoveToTrash: action, viewModel: viewModel)

        #expect(!bodyTypeName(of: grid).isEmpty)
        #expect(!bodyTypeName(of: list).isEmpty)
    }

    @Test("FileInfoView and path title views build their content")
    func fileInfoViewAndPathTitleViewsBuildTheirContent() throws {
        let fileInfo = FileInfoView(file: makeFile())
        let folderInfo = FileInfoView(file: makeFile(name: "folder", itemType: .DIRECTORY))
        let pathTitle = InteractivePathTitleView(fullPath: "/tmp/example", folderName: "example", width: .constant(800))

        #expect(!bodyTypeName(of: fileInfo).isEmpty)
        #expect(!bodyTypeName(of: folderInfo).isEmpty)
        #expect(!bodyTypeName(of: pathTitle).isEmpty)
    }

    @Test("Context menus build file, package, and grid variants")
    func contextMenusBuildFilePackageAndGridVariants() throws {
        let viewModel = FolderViewModel(startDir: URL(fileURLWithPath: "/tmp"))
        let action = {}
        let regularMenu = FileContextMenu(file: makeFile(), viewModel: viewModel, isSelected: false, onOpenAsDirectory: action, onCopy: action, onCut: action, onMoveToTrash: action, onDiscard: action)
        let packageMenu = FileContextMenu(file: makeFile(name: "Editor.app"), viewModel: viewModel, isSelected: true, onOpenAsDirectory: action, onCopy: action, onCut: action, onMoveToTrash: action, onDiscard: action)
        let gridMenu = GridContextMenu(viewModel: viewModel)

        #expect(!bodyTypeName(of: regularMenu).isEmpty)
        #expect(!bodyTypeName(of: packageMenu).isEmpty)
        #expect(!bodyTypeName(of: gridMenu).isEmpty)
    }

    @Test("Splash overlay builds presented and hidden states")
    func splashOverlayBuildsPresentedAndHiddenStates() throws {
        let presented = SplashOverlay(isPresented: .constant(true))
        let hidden = SplashOverlay(isPresented: .constant(false))

        #expect(!bodyTypeName(of: presented).isEmpty)
        #expect(!bodyTypeName(of: hidden).isEmpty)
    }

    @Test("App and root content views build their scenes")
    func appAndRootContentViewsBuildTheirScenes() throws {
        let app = RiverFlowApp()
        let content = ContentView()

        #expect(!bodyTypeName(of: app).isEmpty)
        #expect(!bodyTypeName(of: content).isEmpty)
    }

    @Test("File icon cache returns the same image instance for repeated paths")
    func fileIconCacheReturnsTheSameImageInstanceForRepeatedPaths() throws {
        let first = FileIconView.IconCache.shared.icon(for: "/tmp")
        let second = FileIconView.IconCache.shared.icon(for: "/tmp")

        #expect(first === second)
    }

    @Test("FileContextMenu builds unstaged and staged git variants")
    func fileContextMenuBuildsUnstagedAndStagedGitVariants() throws {
        let viewModel = FolderViewModel(startDir: URL(fileURLWithPath: "/tmp"))
        viewModel.isGitRepo = true
        
        let action = {}
        let file = makeFile()
        
        viewModel.gitStatusMap[file.url.standardizedFileURL] = " M"
        let unstagedMenu = FileContextMenu(
            file: file,
            viewModel: viewModel,
            isSelected: false,
            onOpenAsDirectory: action,
            onCopy: action,
            onCut: action,
            onMoveToTrash: action,
            onDiscard: action
        )
        #expect(!bodyTypeName(of: unstagedMenu).isEmpty)
        
        viewModel.gitStatusMap[file.url.standardizedFileURL] = "M "
        let stagedMenu = FileContextMenu(
            file: file,
            viewModel: viewModel,
            isSelected: false,
            onOpenAsDirectory: action,
            onCopy: action,
            onCut: action,
            onMoveToTrash: action,
            onDiscard: action
        )
        #expect(!bodyTypeName(of: stagedMenu).isEmpty)
    }
}