import Foundation
import Observation

@Observable
class FolderViewModel {
    var currentDir: URL
    var files: [FileItem] = []
    
    var showHiddenFiles: Bool = false {
        didSet {
            loadCurrentDirectory()
        }
    }
    
    var currentDirName: String {
        return currentDir.path == "/" ? "/" : currentDir.lastPathComponent
    }
    
    init(startDir: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.currentDir = startDir
        loadCurrentDirectory()
    }
    
    func loadCurrentDirectory() {
        do {
            let dataKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            
            let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : .skipsHiddenFiles
            
            let content = try FileManager.default.contentsOfDirectory(
                at: currentDir,
                includingPropertiesForKeys: dataKeys,
                options: options
            )
            
            let mappedFiles = content.map { url in
                let resourceValues = try? url.resourceValues(forKeys: Set(dataKeys))
                
                let isDir = resourceValues?.isDirectory ?? false
                let fileSize = resourceValues?.fileSize
                let modifDate = resourceValues?.contentModificationDate
                let finalSize = isDir ? nil : (fileSize != nil ? Int64(fileSize!) : nil)
                
                return FileItem(
                    url: url,
                    name: url.lastPathComponent,
                    itemType: isDir ? .DIRECTORY : .FILE,
                    size: finalSize,
                    modificationDate: modifDate)
            }
//            .sorted {
//                if $0.itemType == .DIRECTORY && $1.itemType == .FILE { return true }
//                if $0.itemType == .FILE && $1.itemType == .DIRECTORY { return false }
//                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
//            }
            
            self.files = mappedFiles.sorted {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            
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
}
