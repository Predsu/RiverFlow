import Foundation
import Testing
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

    @Test("fileExtensionIconText uppercases a file extension")
    func fileExtensionIconTextUppercasesExtension() {
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
    func sidebarItemsExposeTheirDisplayIdentifiersAndIcons() {
        #expect(SideBarItem.home.id == "Home")
        #expect(SideBarItem.downloads.iconName == "arrow.down.circle")
        #expect(SideBarItem.mac.url.path == "/")
    }

    @Test("File view and sorting options expose stable identifiers and icons")
    func FileViewAndSortingOptionsExposeStableIdentifiersAndIcons() {
        #expect(FileViewStyle.grid.id == "Grid")
        #expect(FileViewStyle.list.iconName == "list.bullet")
        #expect(FileSortOption.size.id == "Size")
        #expect(FileSortOption.modificationDate.iconName == "calendar")
        #expect(SearchScope.thisMac.id == "This Mac")
    }
}
