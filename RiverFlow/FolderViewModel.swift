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
//            .sorted {
//                if $0.itemType == .DIRECTORY && $1.itemType == .FILE { return true }
//                if $0.itemType == .FILE && $1.itemType == .DIRECTORY { return false }
//                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
//            }
            
//            self.files = mappedFiles.sorted {
//                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
//            }
            
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
        } else {
            print("Error creating file")
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
        for file in files {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            } catch {
                print("Error while moving \(file.name) to trash: \(error.localizedDescription)")
            }
        }
        loadCurrentDirectory()
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
            } catch {
                print("Error pasting file \(sourceURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if isOperationCut {
            self.pasteboardURLs = []
            self.isOperationCut = false
        }
        loadCurrentDirectory()
    }
}