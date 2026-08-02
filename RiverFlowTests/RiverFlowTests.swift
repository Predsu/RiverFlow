import Foundation
import Testing
@testable import RiverFlow

struct FolderViewModelTests {
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
}
