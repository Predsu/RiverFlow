import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

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
}