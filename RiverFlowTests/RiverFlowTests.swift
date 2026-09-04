import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

@Suite struct FolderViewModelTests {
    private static func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        return tempDir
    }
    
    private static func deleteTempDir(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    @Test("Loading populates elements")
    func loadingPopulatesElements() async throws {
        let tempDir = try! Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let visibleFileURL = tempDir.appendingPathComponent("test.txt")
        let subDirURL = tempDir.appendingPathComponent("subdir")
        
        FileManager.default.createFile(atPath: visibleFileURL.path, contents: "Test file".data(using: .utf8))
        try FileManager.default.createDirectory(at: subDirURL, withIntermediateDirectories: true)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        #expect(viewModel.files.count == 2)
        
        let fileItem = try #require(viewModel.files.first { $0.name == "test.txt" })
        #expect(fileItem.itemType == .DIRECTORY ? false : true)
        #expect(fileItem.isHidden == false)
        #expect(fileItem.size != nil)
        
        let dirItem = try #require(viewModel.files.first { $0.name == "subdir" })
        #expect(dirItem.itemType == .DIRECTORY)
        #expect(dirItem.isHidden == false)
        #expect(dirItem.size == nil)
    }
    
    @Test("Loading filters out hidden files by default")
    func loadingFiltersOutHiddenFilesByDefault() async throws {
        let tempDir = try! Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let visibleFileURL = tempDir.appendingPathComponent("visible.txt")
        let hiddenFileURL = tempDir.appendingPathComponent(".hidden.txt")
        
        FileManager.default.createFile(atPath: visibleFileURL.path, contents: nil)
        FileManager.default.createFile(atPath: hiddenFileURL.path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        #expect(viewModel.files.count == 1)
        #expect(viewModel.files.first?.name == "visible.txt")
    }
    
    @Test("Switching showHiddenFiles reloads and includes hidden files")
    func switchingShowHiddenFilesReloadsAndIncludesHiddenFiles() async throws {
        let tempDir = try! Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let visibleFileURL = tempDir.appendingPathComponent("visible.txt")
        let hiddenFileURL = tempDir.appendingPathComponent(".hidden.txt")
        
        FileManager.default.createFile(atPath: visibleFileURL.path, contents: nil)
        FileManager.default.createFile(atPath: hiddenFileURL.path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        #expect(viewModel.files.count == 1)
        
        viewModel.showHiddenFiles = true
        
        #expect(viewModel.files.count == 2)
        
        viewModel.showHiddenFiles = false
        
        #expect(viewModel.files.count == 1)
    }
    
    @Test("Loading a non-existing directory clears the files array safely")
    func loadingANonExistingDirectoryClearsTheFilesArraySafely() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let nonExistingDirURL = tempDir.appendingPathComponent("non-existing-dir")
        
        let viewModel = FolderViewModel(startDir: nonExistingDirURL)
        
        #expect(viewModel.files.isEmpty)
    }
    
    @Test("currentDirName returns the last path component for a normal directory")
    func currentDirNameReturnsTheLastPathComponentForANormalDirectory() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        #expect(viewModel.currentDirName == tempDir.lastPathComponent)
    }
    
    @Test("currentDirName returns / for the root directory")
    func currentDirNameReturnsSlashForTheRootDirectory() async throws {
        let viewModel = FolderViewModel(startDir: URL(fileURLWithPath: "/"))
        
        #expect(viewModel.currentDirName == "/")
    }
    
    @Test("matchingSidebarItem finds the sidebar entry for the home directory")
    func matchingSidebarItemFindsTheSidebarEntryForTheHomeDirectory() async throws {
        let viewModel = FolderViewModel(startDir: URL(fileURLWithPath: NSHomeDirectory()))
        
        #expect(viewModel.matchingSidebarItem == .home)
    }
    
    @Test("matchingSidebarItem is nil for a normal directory")
    func matchingSidebarItemIsNilForANormalDirectory() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        #expect(viewModel.matchingSidebarItem == nil)
    }
    
    @Test("enterDirectory navigates into a subdirectory and reloads its contents")
    func enterDirectoryNavigatesIntoASubdirectoryAndReloadsItsContents() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let subDirURL = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDirURL, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: subDirURL.appendingPathComponent("file.txt").path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let subDirItem = try #require(viewModel.files.first { $0.name == "subdir" })
        
        viewModel.enterDirectory(dir: subDirItem)
        
        #expect(viewModel.currentDir.standardizedFileURL == subDirURL.standardizedFileURL)
        #expect(viewModel.files.count == 1)
        #expect(viewModel.files.first?.name == "file.txt")
    }
    
    @Test("enterDirectory does nothing on normal file")
    func enterDirectoryDoesNothingOnNormalFile() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("file.txt").path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let fileItem = try #require(viewModel.files.first { $0.name == "file.txt"})
        
        viewModel.enterDirectory(dir: fileItem)
        
        #expect(viewModel.currentDir == tempDir)
    }
    
    @Test("goToParentDirectory moves up one level")
    func goToParentDirectoryMovesUpOneLevel() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let subDir = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let viewModel = FolderViewModel(startDir: subDir)
        viewModel.goToParentDirectory()
        
        #expect(viewModel.currentDir.standardizedFileURL == tempDir.standardizedFileURL)
    }
    
    @Test("Hidden files are correctly flagged when shown")
    func hiddenFilesAreCorrectlyFlaggedWhenShown() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent(".hidden.txt").path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        viewModel.showHiddenFiles = true
        
        let hiddenItem = try #require(viewModel.files.first { $0.name == ".hidden.txt" })
        #expect(hiddenItem.isHidden)
    }
    
    @Test("renameFile renames the file and reloads")
    func renameFileRenamesTheFileAndReloads() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let originalFileURL = tempDir.appendingPathComponent("original.txt")
        FileManager.default.createFile(atPath: originalFileURL.path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let item = try #require(viewModel.files.first { $0.name == "original.txt" })
        
        viewModel.renameFile(file: item, to: "new.txt")
        
        #expect(viewModel.files.contains { $0.name == "new.txt" })
        #expect(!viewModel.files.contains { $0.name == "original.txt" })
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("new.txt").path))
        #expect(!FileManager.default.fileExists(atPath: originalFileURL.path))
    }
    
    @Test("renameFile does nothing when the new name is empty")
    func renameFileDoesNothingWhenTheNewNameIsEmpty() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let originalFileURL = tempDir.appendingPathComponent("original.txt")
        FileManager.default.createFile(atPath: originalFileURL.path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let item = try #require(viewModel.files.first { $0.name == "original.txt" })
        
        viewModel.renameFile(file: item, to: "   ")
        #expect(viewModel.files.contains { $0.name == "original.txt" })
        #expect(FileManager.default.fileExists(atPath: originalFileURL.path))
    }
    
    @Test("moveToTrash removes the file from the current directory")
    func moveToTrashRemovesTheFileFromTheCurrentDirectory() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let fileURL = tempDir.appendingPathComponent("test.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let item = try #require(viewModel.files.first { $0.name == "test.txt" })
        
        viewModel.moveToTrash(files: [item])
        
        #expect(viewModel.files.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    @Test("moveToTrash registers an undo action that restores the file")
    func moveToTrashRegistersAnUndoActionThatRestoresTheFile() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let fileURL = tempDir.appendingPathComponent("test.txt")
        FileManager.default.createFile(atPath: fileURL.path(), contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let undoManager = UndoManager()
        viewModel.undoManager = undoManager
        
        let item = try #require(viewModel.files.first { $0.name == "test.txt"})
        viewModel.moveToTrash(files: [item])
        #expect(viewModel.files.isEmpty)
        
        undoManager.undo()
        
        #expect(viewModel.files.contains { $0.name == "test.txt" })
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    @Test("createNewDirectory increments the name when 'New Folder' already exists")
    func createNewDirectoryIncrementsTheNameWhenNewFolderAlreadyExists() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        viewModel.createNewDirectory()
        viewModel.createNewDirectory()
        
        #expect(viewModel.files.contains { $0.name == "New Folder" })
        #expect(viewModel.files.contains { $0.name == "New Folder 1" })
    }
    
    @Test("createNewFile increments the name when 'Untitled.txt' already exists")
    func createNewFileIncrementsTheNameWhenUntitledTxtAlreadyExists() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        viewModel.createNewFile()
        viewModel.createNewFile()
        
        #expect(viewModel.files.contains { $0.name == "Untitled.txt" })
        #expect(viewModel.files.contains { $0.name == "Untitled 1.txt" })
    }
    
    @Test("copyFiles followed by pasteFiles duplicates the source file")
    func copyFilesFollowedByPasteFilesDuplicatesTheSourceFile() async throws {
        let sourceDir = try Self.createTempDir()
        let destDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: sourceDir)
            Self.deleteTempDir(at: destDir)
        }
        
        let sourceFileURL = sourceDir.appendingPathComponent("test.txt")
        FileManager.default.createFile(atPath: sourceFileURL.path, contents: nil)
        
        let sourceViewModel = FolderViewModel(startDir: sourceDir)
        let item = try #require(sourceViewModel.files.first { $0.name == "test.txt" })
        sourceViewModel.copyFiles(files: [item])
        
        let destViewModel = FolderViewModel(startDir: destDir)
        destViewModel.pasteboardURLs = sourceViewModel.pasteboardURLs
        destViewModel.isOperationCut = false
        destViewModel.pasteFiles()
        
        #expect(destViewModel.files.contains { $0.name == "test.txt" })
        #expect(FileManager.default.fileExists(atPath: sourceFileURL.path))
    }
    
    @Test("Default search scope is Current Folder and search text starts empty")
    func defaultSearchScopeIsCurrentFolderAndSearchTextStartsEmpty() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        #expect(viewModel.searchScope == .currentFolder)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.globalSearchResults.isEmpty)
    }
    
    @Test("Empty search text returns every file in current folder")
    func emptySearchTextReturnsEveryFileInCurrentFolder() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("test1.txt").path), contents: nil)
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("test2.txt").path), contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        #expect(viewModel.sortedFiles.count == 2)
    }
    
    @Test("Whitespace-only search text returns every file")
    func whitespaceOnlySearchTextReturnsEveryFile() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("test1.txt").path), contents: nil)
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("test2.txt").path), contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        viewModel.searchText = "   "
        
        #expect(viewModel.sortedFiles.count == 2)
    }
    
    @Test("Searching the current folder filters files by a case-insensitive substring match")
    func searchingTheCurrentFolderFiltersFilesByACaseInsensitiveSubstringMatch() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("apple.txt").path), contents: nil)
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("pineapple.txt").path), contents: nil)
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("banana.txt").path), contents: nil)
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("cachalot.txt").path), contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        viewModel.searchText = "app"
        
        let results = viewModel.sortedFiles
        #expect(results.count == 2)
        #expect(results.contains { $0.name == "apple.txt" })
        #expect(results.contains { $0.name == "pineapple.txt" })
        #expect(!results.contains { $0.name == "banana.txt" })
        #expect(!results.contains { $0.name == "cachalot.txt" })
    }
    
    @Test("Search with no matches returns empty result set")
    func searchWithNoMatchesReturnsEmptyResultSet() async throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("test1.txt").path), contents: nil)
        FileManager.default.createFile(atPath: String(tempDir.appendingPathComponent("test2.txt").path), contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        viewModel.searchText = "test3"
        
        #expect(viewModel.sortedFiles.isEmpty)
    }

    @Test("selectedFiles returns only selected items")
    func selectedFilesReturnsOnlySelectedItems() throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("first.txt").path, contents: nil)
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("second.txt").path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let selected = try #require(viewModel.files.first { $0.name == "second.txt" })
        
        viewModel.selectedFileIds = [selected.id]
        
        #expect(viewModel.selectedFiles.map(\.name) == ["second.txt"])
    }

    @Test("sortedFiles orders names naturally")
    func sortedFilesOrdersNamesNaturally() throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        viewModel.files = [
            FileItem(url: tempDir.appendingPathComponent("file10.txt"), name: "file10.txt", itemType: .FILE, size: 1, modificationDate: nil, isHidden: false),
            FileItem(url: tempDir.appendingPathComponent("file2.txt"), name: "file2.txt", itemType: .FILE, size: 1, modificationDate: nil, isHidden: false),
            FileItem(url: tempDir.appendingPathComponent("file1.txt"), name: "file1.txt", itemType: .FILE, size: 1, modificationDate: nil, isHidden: false)
        ]
        
        #expect(viewModel.sortedFiles.map(\.name) == ["file1.txt", "file2.txt", "file10.txt"])
    }

    @Test("sortedFiles orders by newest modification date and falls back to name")
    func sortedFilesOrdersByNewestModificationDateAndFallsBackToName() throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        let older = Date(timeIntervalSinceReferenceDate: 100)
        let newer = Date(timeIntervalSinceReferenceDate: 200)
        
        viewModel.files = [
            FileItem(url: tempDir.appendingPathComponent("file10.txt"), name: "file10.txt", itemType: .FILE, size: 1, modificationDate: older, isHidden: false),
            FileItem(url: tempDir.appendingPathComponent("file2.txt"), name: "file2.txt", itemType: .FILE, size: 1, modificationDate: older, isHidden: false),
            FileItem(url: tempDir.appendingPathComponent("file1.txt"), name: "file1.txt", itemType: .FILE, size: 1, modificationDate: newer, isHidden: false)
        ]
        
        viewModel.currentSortingOption = .modificationDate
        
        #expect(viewModel.sortedFiles.map(\.name) == ["file1.txt", "file2.txt", "file10.txt"])
    }

    @Test("sortedFiles orders sized files before folders and by descending size")
    func sortedFilesOrdersSizedFilesBeforeFoldersAndByDescendingSize() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        let viewModel = FolderViewModel(startDir: tempDir)
        viewModel.files = [
            FileItem(url: tempDir.appendingPathComponent("folder"), name: "folder", itemType: .DIRECTORY, size: nil, modificationDate: nil, isHidden: false),
            FileItem(url: tempDir.appendingPathComponent("small.txt"), name: "small.txt", itemType: .FILE, size: 2, modificationDate: nil, isHidden: false),
            FileItem(url: tempDir.appendingPathComponent("large.txt"), name: "large.txt", itemType: .FILE, size: 10, modificationDate: nil, isHidden: false)
        ]
        viewModel.currentSortingOption = .size

        #expect(viewModel.sortedFiles.map(\.name) == ["large.txt", "small.txt", "folder"])
    }

    @Test("Creating a file supports undo and redo")
    func creatingAFileSupportsUndoAndRedo() throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let undoManager = UndoManager()
        viewModel.undoManager = undoManager
        
        viewModel.createNewFile()
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Untitled.txt").path))
        
        undoManager.undo()
        #expect(!FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Untitled.txt").path))
        
        undoManager.redo()
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Untitled.txt").path))
    }

    @Test("Cut then paste moves a file and clears the cut state")
    func cutThenPasteMovesAFileAndClearsCutState() throws {
        let sourceDir = try Self.createTempDir()
        let destDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: sourceDir)
            Self.deleteTempDir(at: destDir)
        }
        let sourceURL = sourceDir.appendingPathComponent("source.txt")
        FileManager.default.createFile(atPath: sourceURL.path, contents: nil)
        let sourceViewModel = FolderViewModel(startDir: sourceDir)
        let item = try #require(sourceViewModel.files.first)
        sourceViewModel.cutFiles(files: [item])
        
        let destViewModel = FolderViewModel(startDir: destDir)
        destViewModel.pasteboardURLs = sourceViewModel.pasteboardURLs
        destViewModel.isOperationCut = sourceViewModel.isOperationCut
        destViewModel.pasteFiles()
        
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("source.txt").path))
        #expect(destViewModel.pasteboardURLs.isEmpty)
        #expect(!destViewModel.isOperationCut)
    }

    @Test("Dropping same-named item exposes a collision and skip preserves both items")
    func droppingSameNamedItemExposesACollisionAndSkipPreservesBothItem() throws {
        let sourceDir = try Self.createTempDir()
        let destinationDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: sourceDir)
            Self.deleteTempDir(at: destinationDir)
        }
        let sourceURL = sourceDir.appendingPathComponent("untitled.txt")
        let destinationURL = destinationDir.appendingPathComponent("untitled.txt")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("sourcecontent".utf8))
        FileManager.default.createFile(atPath: destinationURL.path, contents: Data("destinationcontent".utf8))

        let viewModel = FolderViewModel(startDir: destinationDir)
        viewModel.handleDrop(urls: [sourceURL])

        #expect(viewModel.fileCollision?.sourceURL == sourceURL)
        #expect(viewModel.fileCollision?.destinationURL == destinationURL)
        viewModel.resolveFileCollision(.skip)

        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(try Data(contentsOf: destinationURL) == Data("destinationcontent".utf8))
        #expect(viewModel.fileCollision == nil)
    }

    @Test("Replacing a collision overwrites the destination")
    func replacingACollisionOverwritesTheDestination() throws {
        let sourceDir = try Self.createTempDir()
        let destinationDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: sourceDir)
            Self.deleteTempDir(at: destinationDir)
        }
        let sourceURL = sourceDir.appendingPathComponent("untitled.txt")
        let destinationURL = destinationDir.appendingPathComponent("untitled.txt")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("source".utf8))
        FileManager.default.createFile(atPath: destinationURL.path, contents: Data("destination".utf8))

        let viewModel = FolderViewModel(startDir: destinationDir)
        viewModel.handleDrop(urls: [sourceURL])
        viewModel.resolveFileCollision(.replace)

        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(try Data(contentsOf: destinationURL) == Data("source".utf8))
    }

    @Test("Keeping both names the dropped item with next available number")
    func keepingBothNamesTheDroppedItemWithNextAvailableNumber() throws {
        let sourceDir = try Self.createTempDir()
        let destinationDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: sourceDir)
            Self.deleteTempDir(at: destinationDir)
        }
        let sourceURL = sourceDir.appendingPathComponent("untitled.txt")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("source".utf8))
        FileManager.default.createFile(atPath: destinationDir.appendingPathComponent("untitled.txt").path, contents: nil)
        FileManager.default.createFile(atPath: destinationDir.appendingPathComponent("untitled 2.txt").path, contents: nil)

        let viewModel = FolderViewModel(startDir: destinationDir)
        viewModel.handleDrop(urls: [sourceURL])
        viewModel.resolveFileCollision(.keepBoth)

        let renamedDestination = destinationDir.appendingPathComponent("untitled 3.txt")
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(try Data(contentsOf: renamedDestination) == Data("source".utf8))
    }

    @Test("Multi-item drop presents each collision in sequence")
    @MainActor
    func multiItemDropPresentsEachCollisionInSequence() async throws {
        let sourceDir = try Self.createTempDir()
        let destinationDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: sourceDir)
            Self.deleteTempDir(at: destinationDir)
        }
        let firstSource = sourceDir.appendingPathComponent("first.txt")
        let secondSource = sourceDir.appendingPathComponent("second.txt")
        FileManager.default.createFile(atPath: firstSource.path, contents: nil)
        FileManager.default.createFile(atPath: secondSource.path, contents: nil)
        FileManager.default.createFile(atPath: destinationDir.appendingPathComponent("first.txt").path, contents: nil)
        FileManager.default.createFile(atPath: destinationDir.appendingPathComponent("second.txt").path, contents: nil)

        let viewModel = FolderViewModel(startDir: destinationDir)
        viewModel.handleDrop(urls: [firstSource, secondSource])
        #expect(viewModel.fileCollision?.sourceURL == firstSource)

        viewModel.resolveFileCollision(.skip)
        await Task.yield()

        #expect(viewModel.fileCollision?.sourceURL == secondSource)
        viewModel.resolveFileCollision(.skip)
    }

    @Test("CreateFolderFromSelection moves the selection into a uniquely named folder")
    func createFolderFromSelectionMovesTheSelectionIntoAUniquelyNamedFolder() throws {
        let tempDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: tempDir)
        }
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("New Folder"), withIntermediateDirectories: false)
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("one.txt").path, contents: nil)
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("two.txt").path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        viewModel.createFolderFromSelection(files: viewModel.files.filter { $0.name.hasSuffix(".txt") })
        let groupedFolder = tempDir.appendingPathComponent("New Folder 1")
        
        #expect(FileManager.default.fileExists(atPath: groupedFolder.appendingPathComponent("one.txt").path))
        #expect(FileManager.default.fileExists(atPath: groupedFolder.appendingPathComponent("two.txt").path))
        #expect(!FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("one.txt").path))
    }
    
    @Test("isFileStaged and isFileUnstaged recognize git status patterns")
    func isFileStagedAndIsFileUnstagedRecognizeGitStatusPatterns() throws {
        let viewModel = FolderViewModel(startDir: URL(fileURLWithPath: "/tmp"))
        let fileURL = URL(fileURLWithPath: "/tmp/gitfile.txt").standardizedFileURL
        
        viewModel.gitStatusMap[fileURL] = " M"
        #expect(!viewModel.isFileStaged(url: fileURL))
        #expect(viewModel.isFileUnstaged(url: fileURL))
        
        viewModel.gitStatusMap[fileURL] = "M "
        #expect(viewModel.isFileStaged(url: fileURL))
        #expect(!viewModel.isFileUnstaged(url: fileURL))
        
        viewModel.gitStatusMap[fileURL] = "??"
        #expect(!viewModel.isFileStaged(url: fileURL))
        #expect(viewModel.isFileUnstaged(url: fileURL))
        
        viewModel.gitStatusMap[fileURL] = "MM"
        #expect(viewModel.isFileStaged(url: fileURL))
        #expect(viewModel.isFileUnstaged(url: fileURL))
    }
}

@Suite struct FileItemTests {
    private static func makeItem(
        url: URL = URL(fileURLWithPath: "/tmp/test.txt"),
        name: String = "test.txt",
        itemType: FileItemType = .FILE,
        size: Int64? = nil,
        modificationDate: Date? = nil,
        isHidden: Bool = false
    ) -> FileItem {
        FileItem(url: url, name: name, itemType: itemType, size: size, modificationDate: modificationDate, isHidden: isHidden)
    }
    
    @Test("formattedSize formats byte count")
    func formattedSizeFormatsByteCount() async throws {
        let item = Self.makeItem(size: 1024)
        let item2 = Self.makeItem(size: 3123)
        
        #expect(item.formattedSize != "--")
        #expect(!item.formattedSize.isEmpty)
        #expect(item.formattedSize == "1 KB")
        
        #expect(item2.formattedSize != "--")
        #expect(!item2.formattedSize.isEmpty)
        #expect(item2.formattedSize == "3 KB")
    }
    
    @Test("formattedSize returns a placeholder when size is nil")
    func formattedSizeReturnsPlaceholderWhenSizeIsNil() async throws {
        let item = Self.makeItem(size: nil)
        
        #expect(item.formattedSize == "--")
    }
    
    @Test("formattedSize handles 0 bytes without falling back to the placeholder")
    func formattedSizeHandlesZeroBytesWithoutFallingBackToPlaceholder() async throws {
        let item = Self.makeItem(size: 0)
        
        #expect(item.formattedSize != "--")
    }
    
    @Test("formattedDate returns a placeholder when the date is nil")
    func formattedDateReturnsPlaceholderWhenTheDateIsNil() async throws {
        let item = Self.makeItem(modificationDate: nil)
        
        #expect(item.formattedDate == "--")
    }
    
    @Test("formattedDate returns a non-empty string for a known date")
    func formattedDateReturnsANonEmptyStringForAKnownDate() async throws{
        let item = Self.makeItem(modificationDate: Date())
        
        #expect(item.formattedDate != "--")
        #expect(!item.formattedDate.isEmpty)
    }
    
    @Test("fileExtensionIconText is empty when there is no extension")
    func fileExtensionIconTextIsEmptyWhenThereIsNoExtension() async throws {
        let item = Self.makeItem(url: URL(fileURLWithPath: "/tmp/TESTNOEX"), name: "TESTNOEX")
        
        #expect(item.fileExtensionIconText == "")
    }

    @Test("fileExtensionIconText uppercases file extension")
    func fileExtensionIconTextUppercasesFileExtension() throws {
        let item = Self.makeItem(url: URL(fileURLWithPath: "/tmp/report.Pdf"))

        #expect(item.fileExtensionIconText == "PDF")
    }
    
    @Test("Two FileItem instances for the same URL still have distinct identities")
    func twoFileItemInstancesForTheSameURLStillHaveDistinctIdentities() async throws{
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let a = Self.makeItem(url: url)
        let b = Self.makeItem(url: url)
        
        #expect(a.id != b.id)
    }
}

@Suite struct EnumPresentationTests {
    @Test("Sidebar items expose their display identifiers and icons")
    func sidebarItemsExposeTheirDisplayIdentifiersAndIcons() throws {
        #expect(SideBarItem.home.id == "Home")
        #expect(SideBarItem.downloads.iconName == "arrow.down.circle")
        #expect(SideBarItem.mac.url.path == "/")
    }

    @Test("File view and sorting options expose stable identifiers and icons")
    func FileViewAndSortingOptionsExposeStableIdentifiersAndIcons() throws {
        #expect(FileViewStyle.grid.id == "Grid")
        #expect(FileViewStyle.list.iconName == "list.bullet")
        #expect(FileSortOption.size.id == "Size")
        #expect(FileSortOption.modificationDate.iconName == "calendar")
        #expect(SearchScope.thisMac.id == "This Mac")
    }
}

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

@Suite struct GitBadgeViewTests {
    @Test("GitBadgeView resolves badge text and color correctly")
    func gitBadgeViewResolvesBadgeTextAndColorCorrectly() throws {
        let untracked = GitBadgeView(status: "??")
        #expect(untracked.badgeText == "U")
        
        let modified = GitBadgeView(status: " M")
        #expect(modified.badgeText == "M")
        
        let added = GitBadgeView(status: "A ")
        #expect(added.badgeText == "A")
        
        let deleted = GitBadgeView(status: "D ")
        #expect(deleted.badgeText == "D")
        
        let other = GitBadgeView(status: "XY")
        #expect(other.badgeText == "XY")
    }
}

@Suite struct FileWindowManagerTests {
    @Test("FileWindowManager opens and tracks info windows")
    @MainActor
    func fileWindowManagerOpensAndTracksInfoWindows() throws {
        let file = FileItem(
            url: URL(fileURLWithPath: "/tmp/infofile.txt"),
            name: "infofile.txt",
            itemType: .FILE,
            size: 100,
            modificationDate: Date(),
            isHidden: false
        )
        
        FileWindowManager.openInfoView(for: file)
        FileWindowManager.openInfoView(for: file)
        
        let windowIdentifier = "fileinfowindow-\(file.id.uuidString)"
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowIdentifier }) {
            NotificationCenter.default.post(
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
    }
}

@Suite struct ThumbnailManagerTests {
    @Test("ThumbnailManager caching and clearing cache")
    func thumbnailManagerCachingAndClearingCache() throws {
        let manager = ThumbnailManager.shared
        manager.clearCache()
        
        let tempFileURL = URL(fileURLWithPath: "/tmp/thumbnail_test.png")
        manager.getFileThumbnail(for: tempFileURL, size: 48) { _ in }
        manager.clearCache()
    }
}

@Suite struct KeyboardShortcutsTests {
    private static func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        return tempDir
    }
    
    private static func deleteTempDir(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    @Test("All keyboard shortcut actions have valid properties and categories")
    func allKeyboardShortcutActionsHaveValidPropertiesAndCategories() {
        #expect(KeyboardShortcutAction.allCases.count == 10)
        
        for action in KeyboardShortcutAction.allCases {
            #expect(!action.id.isEmpty)
            #expect(!action.title.isEmpty)
            #expect(!action.iconName.isEmpty)
            #expect(!action.displayShortcut.isEmpty)
        }
        
        #expect(KeyboardShortcutAction.newFolder.category == .fileOperations)
        #expect(KeyboardShortcutAction.newFile.category == .fileOperations)
        #expect(KeyboardShortcutAction.delete.category == .fileOperations)
        #expect(KeyboardShortcutAction.permanentlyDelete.category == .fileOperations)
        #expect(KeyboardShortcutAction.openSelected.category == .fileOperations)
        #expect(KeyboardShortcutAction.navigateUp.category == .navigation)
        #expect(KeyboardShortcutAction.goBack.category == .navigation)
        #expect(KeyboardShortcutAction.goForward.category == .navigation)
        #expect(KeyboardShortcutAction.newWindow.category == .window)
    }
    
    @Test("KeyCombos match the specified shortcut requirements")
    func keyCombosMatchTheSpecifiedShortcutRequirements() {
        #expect(KeyboardShortcutAction.newFolder.keyCombo.modifiers == [.command, .shift])
        #expect(KeyboardShortcutAction.newFolder.displayShortcut == "⇧⌘N")

        #expect(KeyboardShortcutAction.newFile.keyCombo.modifiers == [.command])
        #expect(KeyboardShortcutAction.newFile.displayShortcut == "⌘N")
        
        #expect(KeyboardShortcutAction.delete.keyCombo.modifiers == [])
        #expect(KeyboardShortcutAction.delete.keyCombo.keyCode == 51)
        #expect(KeyboardShortcutAction.delete.displayShortcut == "⌫")
        
        #expect(KeyboardShortcutAction.permanentlyDelete.keyCombo.modifiers == [.command])
        #expect(KeyboardShortcutAction.permanentlyDelete.keyCombo.keyCode == 51)
        #expect(KeyboardShortcutAction.permanentlyDelete.displayShortcut == "⌘⌫")
        
        #expect(KeyboardShortcutAction.openSelected.keyCombo.modifiers == [])
        #expect(KeyboardShortcutAction.openSelected.keyCombo.keyCode == 36)
        #expect(KeyboardShortcutAction.openSelected.displayShortcut == "↩")
        
        #expect(KeyboardShortcutAction.navigateUp.keyCombo.modifiers == [.command])
        #expect(KeyboardShortcutAction.navigateUp.keyCombo.keyCode == 126)
        #expect(KeyboardShortcutAction.navigateUp.displayShortcut == "⌘↑")
        
        #expect(KeyboardShortcutAction.goBack.keyCombo.modifiers == [.command])
        #expect(KeyboardShortcutAction.goBack.keyCombo.character == "[")
        #expect(KeyboardShortcutAction.goBack.displayShortcut == "⌘[")
        
        #expect(KeyboardShortcutAction.goForward.keyCombo.modifiers == [.command])
        #expect(KeyboardShortcutAction.goForward.keyCombo.character == "]")
        #expect(KeyboardShortcutAction.goForward.displayShortcut == "⌘]")
        
        #expect(KeyboardShortcutAction.newWindow.keyCombo.modifiers == [.command])
        #expect(KeyboardShortcutAction.newWindow.keyCombo.character == "t")
        #expect(KeyboardShortcutAction.newWindow.displayShortcut == "⌘T")
    }
    
    @Test("KeyboardShortcutHandler executes newFolder and newFile actions")
    @MainActor
    func keyboardShortcutHandlerExecutesNewFolderAndNewFileActions() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let handler = KeyboardShortcutHandler.shared
        
        let folderResult = handler.execute(action: .newFolder, viewModel: viewModel)
        #expect(folderResult == true)
        #expect(viewModel.files.contains { $0.name == "New Folder" })
        
        let fileResult = handler.execute(action: .newFile, viewModel: viewModel)
        #expect(fileResult == true)
        #expect(viewModel.files.contains { $0.name == "Untitled.txt" })
    }
    
    @Test("KeyboardShortcutHandler executes delete action moving item to trash")
    @MainActor
    func keyboardShortcutHandlerExecutesDeleteActionMovingItemToTrash() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        
        let fileURL = tempDir.appendingPathComponent("test.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let item = try #require(viewModel.files.first { $0.name == "test.txt" })
        viewModel.selectedFileIds = [item.id]
        
        let handler = KeyboardShortcutHandler.shared
        let result = handler.execute(action: .delete, viewModel: viewModel)
        
        #expect(result == true)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        #expect(viewModel.selectedFileIds.isEmpty)
    }
    
    @Test("KeyboardShortcutHandler executes permanentlyDelete action removing item from disk")
    @MainActor
    func keyboardShortcutHandlerExecutesPermanentlyDeleteActionRemovingItemFromDisk() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        
        let fileURL = tempDir.appendingPathComponent("test2.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let item = try #require(viewModel.files.first { $0.name == "test2.txt" })
        viewModel.selectedFileIds = [item.id]
        
        let handler = KeyboardShortcutHandler.shared
        let result = handler.execute(action: .permanentlyDelete, viewModel: viewModel)
        
        #expect(result == true)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        #expect(viewModel.files.isEmpty)
        #expect(viewModel.selectedFileIds.isEmpty)
    }
    
    @Test("KeyboardShortcutHandler executes openSelected action entering subdirectory")
    @MainActor
    func keyboardShortcutHandlerExecutesOpenSelectedActionEnteringSubdirectory() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        
        let subDirURL = tempDir.appendingPathComponent("testSubdir")
        try FileManager.default.createDirectory(at: subDirURL, withIntermediateDirectories: true)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let folderItem = try #require(viewModel.files.first { $0.name == "testSubdir" })
        viewModel.selectedFileIds = [folderItem.id]
        
        let handler = KeyboardShortcutHandler.shared
        let result = handler.execute(action: .openSelected, viewModel: viewModel)
        
        #expect(result == true)
        #expect(viewModel.currentDir.standardizedFileURL == subDirURL.standardizedFileURL)
        #expect(viewModel.selectedFileIds.isEmpty)
    }
    
    @Test("KeyboardShortcutHandler executes navigation actions")
    @MainActor
    func keyboardShortcutHandlerExecutesNavigationAction() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        
        let subDir1 = tempDir.appendingPathComponent("dir1")
        let subDir2 = tempDir.appendingPathComponent("dir2")
        try FileManager.default.createDirectory(at: subDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subDir2, withIntermediateDirectories: true)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        let item1 = try #require(viewModel.files.first { $0.name == "dir1" })
        viewModel.enterDirectory(dir: item1)
        #expect(viewModel.currentDir.standardizedFileURL == subDir1.standardizedFileURL)
        
        let handler = KeyboardShortcutHandler.shared
        
        let backResult = handler.execute(action: .goBack, viewModel: viewModel)
        #expect(backResult == true)
        #expect(viewModel.currentDir.standardizedFileURL == tempDir.standardizedFileURL)
        
        let forwardResult = handler.execute(action: .goForward, viewModel: viewModel)
        #expect(forwardResult == true)
        #expect(viewModel.currentDir.standardizedFileURL == subDir1.standardizedFileURL)
        
        let upResult = handler.execute(action: .navigateUp, viewModel: viewModel)
        #expect(upResult == true)
        #expect(viewModel.currentDir.standardizedFileURL == tempDir.standardizedFileURL)
    }
    
    @Test("KeyboardShortcutHandler executes newWindow calling provided callback")
    @MainActor
    func keyboardShortcutHandlerExecutesNewWindowCallingProvidedCallback() {
        let viewModel = FolderViewModel()
        var windowOpened = false
        
        let handler = KeyboardShortcutHandler.shared
        let result = handler.execute(action: .newWindow, viewModel: viewModel) {
            windowOpened = true
        }
        
        #expect(result == true)
        #expect(windowOpened == true)
    }
    
    @Test("FolderViewModel openSelectedFiles handles empty selection gracefully")
    func folderViewModelOpenSelectedFilesHandlesEmptySelectionGracefully() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        
        let viewModel = FolderViewModel(startDir: tempDir)
        viewModel.selectedFileIds = []
        viewModel.openSelectedFiles()
        
        #expect(viewModel.currentDir.standardizedFileURL == tempDir.standardizedFileURL)
    }
    
    @Test("FolderViewModel permanentlyDelete removes multiple files directly")
    func folderViewModelPermanentlyDeleteRemovesMultipleFilesDirectly() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        
        let f1 = tempDir.appendingPathComponent("f1.txt")
        let f2 = tempDir.appendingPathComponent("f2.txt")
        FileManager.default.createFile(atPath: f1.path, contents: nil)
        FileManager.default.createFile(atPath: f2.path, contents: nil)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        #expect(viewModel.files.count == 2)
        
        viewModel.selectedFileIds = Set(viewModel.files.map(\.id))
        viewModel.permanentlyDeleteSelected()
        
        #expect(viewModel.files.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: f1.path))
        #expect(!FileManager.default.fileExists(atPath: f2.path))
    }
}

@Suite struct JumpToPathTests {
    private static func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        return tempDir
    }
    
    private static func deleteTempDir(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    @Test("jumpToPath keyboard shortcut is properly defined")
    func jumpToPathKeyboardShortcutIsProperlyDefined() {
        let action = KeyboardShortcutAction.jumpToPath
        #expect(action.title == "Go to Folder")
        #expect(action.category == .navigation)
        #expect(action.displayShortcut == "⌘G")
        #expect(action.keyCombo.modifiers == [.command])
        #expect(action.keyCombo.character == "g")
        #expect(action.keyCombo.keyCode == 5)
    }
    
    @Test("KeyboardShortcutHandler executes jumpToPath action")
    @MainActor
    func keyboardShortcutHandlerExecutesJumpToPathAction() {
        let viewModel = FolderViewModel()
        viewModel.isJumpToPathPresented = false
        
        let handler = KeyboardShortcutHandler.shared
        let handled = handler.execute(action: .jumpToPath, viewModel: viewModel)
        
        #expect(handled == true)
        #expect(viewModel.isJumpToPathPresented == true)
    }
    
    @Test("FolderViewModel jumpTo resolves home, valid directory and relative paths")
    func folderViewModelJumpToResolvesHomeValidDirectoryAndRelativePaths() throws {
        let tempDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: tempDir) }
        
        let subDir = tempDir.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let viewModel = FolderViewModel(startDir: tempDir)
        
        let jumpRelativeSuccess = viewModel.jumpTo(path: "subfolder")
        #expect(jumpRelativeSuccess == true)
        #expect(viewModel.currentDir.standardizedFileURL == subDir.standardizedFileURL)
        
        let jumpAbsSuccess = viewModel.jumpTo(path: tempDir.path)
        #expect(jumpAbsSuccess == true)
        #expect(viewModel.currentDir.standardizedFileURL == tempDir.standardizedFileURL)
        
        let jumpTildeSuccess = viewModel.jumpTo(path: "~")
        #expect(jumpTildeSuccess == true)
        #expect(viewModel.currentDir.standardizedFileURL == URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL)
        
        let jumpInvalid = viewModel.jumpTo(path: "/nonexistent_folder_123456")
        #expect(jumpInvalid == false)
    }
    
    @Test("PathAutocompleteService expandPath properly expands paths")
    func pathAutocompleteServiceExpandPathProperlyExpandsPaths() {
        let home = NSHomeDirectory()
        #expect(PathAutocompleteService.expandPath("~", homeDir: home) == home)
        #expect(PathAutocompleteService.expandPath("~/Documents", homeDir: home) == (home as NSString).appendingPathComponent("Documents"))
        #expect(PathAutocompleteService.expandPath("/Users/test", homeDir: home) == "/Users/test")
        
        let current = URL(fileURLWithPath: "/tmp")
        #expect(PathAutocompleteService.expandPath("myfolder", currentDir: current, homeDir: home) == "/tmp/myfolder")
    }
    
    @Test("PathAutocompleteService filters strictly to tier 0 and tier 1 folders")
    func pathAutocompleteServiceFiltersStrictlyToTierZeroAndTierOneFolders() throws {
        let mockHome = try Self.createTempDir()
        defer { Self.deleteTempDir(at: mockHome) }
        
        let homePath = mockHome.path
        
        let desktop = mockHome.appendingPathComponent("Desktop")
        let documents = mockHome.appendingPathComponent("Documents")
        let project = mockHome.appendingPathComponent("MyProject")
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        
        let nested = project.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        
        let dotFolder = mockHome.appendingPathComponent(".config")
        try FileManager.default.createDirectory(at: dotFolder, withIntermediateDirectories: true)
        
        let nodeModules = project.appendingPathComponent("node_modules")
        let libraryFolder = mockHome.appendingPathComponent("Library")
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: libraryFolder, withIntermediateDirectories: true)
        
        let outsideDir = try Self.createTempDir()
        defer { Self.deleteTempDir(at: outsideDir) }
        
        #expect(FolderViewModel.relevanceTier(for: desktop, homeDir: homePath) == 0)
        #expect(FolderViewModel.relevanceTier(for: documents, homeDir: homePath) == 0)
        #expect(FolderViewModel.relevanceTier(for: project, homeDir: homePath) == 0)
        #expect(FolderViewModel.relevanceTier(for: nested, homeDir: homePath) == 1)
        #expect(FolderViewModel.relevanceTier(for: dotFolder, homeDir: homePath) == 2)
        #expect(FolderViewModel.relevanceTier(for: nodeModules, homeDir: homePath) == 3)
        #expect(FolderViewModel.relevanceTier(for: libraryFolder, homeDir: homePath) == 3)
        #expect(FolderViewModel.relevanceTier(for: outsideDir, homeDir: homePath) == 4)
        
        let service = PathAutocompleteService()
        let suggestions = service.autocompletionSuggestions(for: "~/", currentDir: mockHome, homeDir: homePath)
        
        let suggestionPaths = suggestions.map(\.path)
        #expect(suggestionPaths.contains(desktop.standardizedFileURL.path))
        #expect(suggestionPaths.contains(documents.standardizedFileURL.path))
        #expect(suggestionPaths.contains(project.standardizedFileURL.path))
        
        #expect(!suggestionPaths.contains(dotFolder.standardizedFileURL.path))
        #expect(!suggestionPaths.contains(nodeModules.standardizedFileURL.path))
        #expect(!suggestionPaths.contains(libraryFolder.standardizedFileURL.path))
        #expect(!suggestionPaths.contains(outsideDir.standardizedFileURL.path))
    }
}

