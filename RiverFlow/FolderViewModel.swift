import Foundation
import Observation
import AppKit

@Observable
class FolderViewModel {
    var currentDir: URL
    var files: [FileItem] = []
    var currentSortingOption: FileSortOption = .name
    
    var pasteboardURLs: [URL] = []
    var isOperationCut: Bool = false
    
    weak var undoManager: UndoManager?
    
    private func registerUndo(actionName: String, _ handler: @escaping (FolderViewModel) -> Void) {
        undoManager?.registerUndo(withTarget: self, handler: handler)
        undoManager?.setActionName(actionName)
    }
    
    var showHiddenFiles: Bool = false {
        didSet {
            loadCurrentDirectory()
        }
    }
    
    var matchingSidebarItem: SideBarItem? {
        return SideBarItem.allCases.first { $0.url.standardizedFileURL == currentDir.standardizedFileURL }
    }
    
    var currentDirName: String {
        return currentDir.path == "/" ? "/" : currentDir.lastPathComponent
    }
    
    init(startDir: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.currentDir = startDir
        loadCurrentDirectory()
    }
    
    var sortedFiles: [FileItem] {
        switch currentSortingOption {
        case .name:
            return files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .modificationDate:
            return files.sorted {
                let d1 = $0.modificationDate ?? Date.distantPast
                let d2 = $1.modificationDate ?? Date.distantPast
                return d1 > d2
            }
        case .size:
            return files.sorted {
                if let s1 = $0.size, let s2 = $1.size {
                    return s1 > s2
                }
                if $0.size != nil { return true }
                if $1.size != nil { return false }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
    }
    
    func loadCurrentDirectory() {
        ThumbnailManager.shared.clearCache()
        
        do {
            let dataKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]
            
            let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : .skipsHiddenFiles
            
            let content = try FileManager.default.contentsOfDirectory(
                at: currentDir,
                includingPropertiesForKeys: dataKeys,
                options: options
            )
            
            let mappedFiles = autoreleasepool {
                return content.map { url in
                    let resourceValues = try? url.resourceValues(forKeys: Set(dataKeys))
                    
                    let isDir = resourceValues?.isDirectory ?? false
                    let fileSize = resourceValues?.fileSize
                    let modifDate = resourceValues?.contentModificationDate
                    let finalSize = isDir ? nil : (fileSize != nil ? Int64(fileSize!) : nil)
                    
                    let isHiddenAttribute = resourceValues?.isHidden ?? false
                    let startsWithDot = url.lastPathComponent.hasPrefix(".")
                    let isFileHidden = isHiddenAttribute || startsWithDot
                    
                    
                    
                    return FileItem(
                        url: url,
                        name: url.lastPathComponent,
                        itemType: isDir ? .DIRECTORY : .FILE,
                        size: finalSize,
                        modificationDate: modifDate,
                        isHidden: isFileHidden
                    )
                }
            }
            
            self.files = mappedFiles
            
        } catch {
            print("Error while reading directory \(error.localizedDescription)")
            self.files = []
        }
    }
    
    func enterDirectory(dir: FileItem) {
        guard dir.itemType == .DIRECTORY else { return }
        currentDir = dir.url
        loadCurrentDirectory()
    }
    
    func goToParentDirectory() {
        let parentDir = currentDir.deletingLastPathComponent()
        if parentDir != currentDir {
            currentDir = parentDir
            loadCurrentDirectory()
        }
    }
    
    func createNewDirectory() {
        var dirName: String = "New Folder"
        var counter: Int = 1
        var dirURL = currentDir.appendingPathComponent(dirName)
        
        while FileManager.default.fileExists(atPath: dirURL.path) {
            dirName = "New Folder \(counter)"
            counter += 1
            dirURL = currentDir.appendingPathComponent(dirName)
        }
        
        do {
            try FileManager.default.createDirectory(
                at: dirURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            loadCurrentDirectory()
            registerCreateUndo(url: dirURL, isDirectory: true)
        } catch {
            print("Error creating directory \(error.localizedDescription)")
        }
    }
    
    func createNewFile() {
        var fileName: String = "Untitled.txt"
        var counter: Int = 1
        var fileURL = currentDir.appendingPathComponent(fileName)
        
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileName = "Untitled \(counter).txt"
            counter += 1
            fileURL = currentDir.appendingPathComponent(fileName)
        }
        
        let success = FileManager.default.createFile(
            atPath: fileURL.path,
            contents: Data(),
            attributes: nil
        )
            
        if success {
            loadCurrentDirectory()
            registerCreateUndo(url: fileURL, isDirectory: false)
        } else {
            print("Error creating file")
        }
    }
    
    private func registerCreateUndo(url: URL, isDirectory: Bool) {
        registerUndo(actionName: isDirectory ? "New Folder" : "New File") { target in
            do {
                try FileManager.default.removeItem(at: url)
                target.loadCurrentDirectory()
                target.registerRecreateUndo(url: url, isDirectory: isDirectory)
            } catch {
                print("Error while undo creation of \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
    
    private func registerRecreateUndo(url: URL, isDirectory: Bool) {
        registerUndo(actionName: isDirectory ? "New Folder" : "New File") { target in
            do {
                if isDirectory {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                } else {
                    FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
                }
                target.loadCurrentDirectory()
                target.registerCreateUndo(url: url, isDirectory: isDirectory)
            } catch {
                print("Error while redo creation of \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
    
    func copyFiles(files: [FileItem]) {
        self.pasteboardURLs = files.map { $0.url }
        self.isOperationCut = false
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(files.map { $0.url as NSURL})
    }
    
    func cutFiles(files: [FileItem]) {
        self.pasteboardURLs = files.map { $0.url }
        self.isOperationCut = true
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(files.map { $0.url as NSURL})
    }
    
    func moveToTrash(files: [FileItem]) {
        var restorePairs: [(trashed: URL, original: URL)] = []
        for file in files {
            var resultingURL: NSURL?
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: &resultingURL)
                if let trashedURL = resultingURL as URL? {
                    restorePairs.append((trashed: trashedURL, original: file.url))
                }
            } catch {
                print("Error while moving \(file.name) to trash: \(error.localizedDescription)")
            }
        }
        loadCurrentDirectory()
        
        guard !restorePairs.isEmpty else { return }
        registerTrashUndo(restorePairs: restorePairs)
    }
    
    private func registerTrashUndo(restorePairs: [(trashed: URL, original: URL)]) {
        registerUndo(actionName: "Move to Trash") { target in
            var restoredURLs: [URL] = []
            for pair in restorePairs {
                do {
                    try FileManager.default.moveItem(at: pair.trashed, to: pair.original)
                    restoredURLs.append(pair.original)
                } catch {
                    print("Error restoring \(pair.original.lastPathComponent): \(error.localizedDescription)")
                }
            }
            target.loadCurrentDirectory()
            target.registerRetrashUndo(originalURLs: restoredURLs)
        }
    }
    
    private func registerRetrashUndo(originalURLs: [URL]) {
        registerUndo(actionName: "Move to Trash") { target in
            var restorePairs: [(trashed: URL, original: URL)] = []
            for url in originalURLs {
                var resultingURL: NSURL?
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
                    if let trashedURL = resultingURL as URL? {
                        restorePairs.append((trashed: trashedURL, original: url))
                    }
                } catch {
                    print("Error re-trashing \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func pasteFiles() {
        let finalURLs: [URL]
        if !pasteboardURLs.isEmpty {
            finalURLs = pasteboardURLs
        } else {
            let pasteboard = NSPasteboard.general
            finalURLs = (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
        }
        
        guard !finalURLs.isEmpty else { return }
        
        let wasCut = isOperationCut
        var pastedPairs: [(source: URL, destination: URL)] = []
        
        for sourceURL in finalURLs {
            let destinationURL = currentDir.appendingPathComponent(sourceURL.lastPathComponent)
            var finalDestinationURL = destinationURL
            var counter: Int = 1
            let fileExtension = sourceURL.pathExtension
            let fileNameWithoutExtension = sourceURL.deletingPathExtension().lastPathComponent
            
            while FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                counter += 1
                let newName = "\(fileNameWithoutExtension) \(counter)"
                finalDestinationURL = currentDir.appendingPathComponent(newName)
                if !fileExtension.isEmpty {
                    finalDestinationURL = finalDestinationURL.appendingPathExtension(fileExtension)
                }
            }
            
            do {
                if isOperationCut {
                    try FileManager.default.moveItem(at: sourceURL, to: finalDestinationURL)
                } else {
                    try FileManager.default.copyItem(at: sourceURL, to: finalDestinationURL)
                }
                pastedPairs.append((source: sourceURL, destination: finalDestinationURL))
            } catch {
                print("Error pasting file \(sourceURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if isOperationCut {
            self.pasteboardURLs = []
            self.isOperationCut = false
        }
        loadCurrentDirectory()
        
        guard !pastedPairs.isEmpty else { return }
        registerPasteUndo(pastedPairs: pastedPairs, wasCut: wasCut)
    }
    
    private func registerPasteUndo(pastedPairs: [(source: URL, destination: URL)], wasCut: Bool) {
        registerUndo(actionName: wasCut ? "Move": "Paste") { target in
            for pair in pastedPairs {
                do {
                    if wasCut {
                        try FileManager.default.moveItem(at: pair.destination, to: pair.source)
                    } else {
                        try FileManager.default.removeItem(at: pair.destination)
                    }
                } catch {
                    print("Error undoing paste of \(pair.destination.lastPathComponent): \(error.localizedDescription)")
                }
            }
            target.loadCurrentDirectory()
            target.registerRepasteUndo(pastedPairs: pastedPairs, wasCut: wasCut)
        }
    }
    
    private func registerRepasteUndo(pastedPairs: [(source: URL, destination: URL)], wasCut: Bool) {
        registerUndo(actionName: wasCut ? "Move" : "Paste") { target in
            for pair in pastedPairs {
                do {
                    if wasCut {
                        try FileManager.default.moveItem(at: pair.source, to: pair.destination)
                    } else {
                        try FileManager.default.copyItem(at: pair.source, to: pair.destination)
                    }
                } catch {
                    print("Error redoing paste of \(pair.destination.lastPathComponent): \(error.localizedDescription)")
                }
            }
            target.loadCurrentDirectory()
            target.registerPasteUndo(pastedPairs: pastedPairs, wasCut: wasCut)
        }
    }
}
