import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

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

    @Test("PathSuggestion correctly formats relative display paths")
    func pathSuggestionCorrectlyFormatsRelativeDisplayPaths() {
        let home = "/Users/testuser"
        let homeURL = URL(fileURLWithPath: home)
        
        let homeSuggestion = PathSuggestion(url: homeURL, homeDir: home, revelanceTier: 0)
        #expect(homeSuggestion.relativeDisplayPath == "~")
        #expect(homeSuggestion.displayName == "testuser")
        
        let docURL = URL(fileURLWithPath: "/Users/testuser/Documents")
        let docSuggestion = PathSuggestion(url: docURL, homeDir: home, revelanceTier: 0)
        #expect(docSuggestion.relativeDisplayPath == "~/Documents")
        #expect(docSuggestion.displayName == "Documents")
        
        let rootURL = URL(fileURLWithPath: "/")
        let rootSuggestion = PathSuggestion(url: rootURL, homeDir: home, revelanceTier: 0)
        #expect(rootSuggestion.relativeDisplayPath == "/")
        #expect(rootSuggestion.displayName == "/")
        
        let outURL = URL(fileURLWithPath: "/Library")
        let outSuggestion = PathSuggestion(url: outURL, homeDir: home, revelanceTier: 0)
        #expect(outSuggestion.relativeDisplayPath == "/Library")
        #expect(outSuggestion.displayName == "Library")
    }

    @Test("PathAutocompleteService expandPath returns empty for whitespace")
    func pathAutocompleteServiceExpandPathReturnsEmptyForWhitespace() {
        let home = "/Users/testuser"
        #expect(PathAutocompleteService.expandPath("   ", homeDir: home) == "")
        #expect(PathAutocompleteService.expandPath("", homeDir: home) == "")
    }

    @Test("PathAutocompleteService autocompletionSuggestions query matching")
    func pathAutocompleteServiceAutocompletionSuggestionsQueryMatching() throws {
        let mockHome = try Self.createTempDir()
        defer { Self.deleteTempDir(at: mockHome) }
        
        let homePath = mockHome.path
        
        let alpha = mockHome.appendingPathComponent("Alpha")
        let beta = mockHome.appendingPathComponent("Beta")
        let alpha2 = mockHome.appendingPathComponent("Alpaca")
        
        try FileManager.default.createDirectory(at: alpha, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: beta, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: alpha2, withIntermediateDirectories: true)
        
        let service = PathAutocompleteService()
        
        let suggestions1 = service.autocompletionSuggestions(for: "Alpha", currentDir: mockHome, homeDir: homePath)
        let names1 = suggestions1.map(\.displayName)
        #expect(names1.contains("Alpha"))
        #expect(!names1.contains("Beta"))
        #expect(!names1.contains("Alpaca"))
        
        let suggestions2 = service.autocompletionSuggestions(for: "alp", currentDir: mockHome, homeDir: homePath)
        let names2 = suggestions2.map(\.displayName)
        #expect(names2.contains("Alpha"))
        #expect(names2.contains("Alpaca"))
        #expect(!names2.contains("Beta"))
    }

    @Test("PathAutocompleteService only suggests folder names that begin with the current path segment")
    func pathAutocompleteServiceDoesNotReturnSubstringMatches() throws {
        let mockHome = try Self.createTempDir()
        defer { Self.deleteTempDir(at: mockHome) }

        let apple = mockHome.appendingPathComponent("apple")
        let unrelated = mockHome.appendingPathComponent("my-apple-backup")
        try FileManager.default.createDirectory(at: apple, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)

        let suggestions = PathAutocompleteService().autocompletionSuggestions(
            for: "appl",
            currentDir: mockHome,
            homeDir: mockHome.path
        )

        let names = suggestions.map(\.displayName)
        #expect(names.contains("apple"))
        #expect(!names.contains("my-apple-backup"))
    }
    
    @Test("PathAutocompleteService autocompletionSuggestions respects maxResults")
    func pathAutocompleteServiceAutocompletionSuggestionsRespectsMaxResults() throws {
        let mockHome = try Self.createTempDir()
        defer { Self.deleteTempDir(at: mockHome) }
        
        for i in 1...10 {
            let dir = mockHome.appendingPathComponent("dir\(i)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        let service = PathAutocompleteService()
        let suggestions = service.autocompletionSuggestions(for: "dir", currentDir: mockHome, homeDir: mockHome.path, maxResults: 5)
        
        #expect(suggestions.count == 5)
    }

    @Test("PathAutocompleteService autocompletionSuggestions handles nested paths")
    func pathAutocompleteServiceAutocompletionSuggestionsHandlesNestedPaths() throws {
        let mockHome = try Self.createTempDir()
        defer { Self.deleteTempDir(at: mockHome) }
        
        let parent = mockHome.appendingPathComponent("parentDir")
        let child1 = parent.appendingPathComponent("childOne")
        let child2 = parent.appendingPathComponent("childTwo")
        
        try FileManager.default.createDirectory(at: child1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: child2, withIntermediateDirectories: true)
        
        let service = PathAutocompleteService()
        let suggestions = service.autocompletionSuggestions(for: parent.path + "/child", currentDir: mockHome, homeDir: mockHome.path)
        
        let names = suggestions.map(\.displayName)
        #expect(names.contains("childOne"))
        #expect(names.contains("childTwo"))
    }

    @Test("PathAutocompleteService autocompletionSuggestions empty query fallback")
    func pathAutocompleteServiceAutocompletionSuggestionsEmptyQueryFallback() throws {
        let mockHome = try Self.createTempDir()
        defer { Self.deleteTempDir(at: mockHome) }
        
        let dir1 = mockHome.appendingPathComponent("customDir")
        try FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
        
        let service = PathAutocompleteService()
        let suggestions = service.autocompletionSuggestions(for: "", currentDir: mockHome, homeDir: mockHome.path)
        
        let names = suggestions.map(\.displayName)
        #expect(names.contains("customDir"))
    }
}