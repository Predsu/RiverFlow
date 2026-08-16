import Foundation
import Observation
import AppKit
import CryptoKit
import UniformTypeIdentifiers

@Observable
class FolderViewModel {
    var currentDir: URL
    var files: [FileItem] = []
    var currentSortingOption: FileSortOption = .name
    
    var editingFileID: UUID? = nil
    var selectedFileIds: Set<UUID> = []
    
    var pasteboardURLs: [URL] = []
    var isOperationCut: Bool = false
    
    var searchText = "" {
        didSet {
            performSearch()
        }
    }
    
    var searchScope: SearchScope = .currentFolder {
        didSet {
            performSearch()
        }
    }
    
    var globalSearchResults: [FileItem] = []
    private var metadataQuery: NSMetadataQuery?
    
    weak var undoManager: UndoManager?
    
    deinit {
        if let query = metadataQuery {
            query.stop()
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
        }
    }
    
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
    
    var selectedFiles: [FileItem] {
        files.filter { selectedFileIds.contains($0.id) }
    }
    
    init(startDir: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.currentDir = startDir
        loadCurrentDirectory()
    }
    
    private static let userContentFolderNames: Set<String> = [
        "desktop", "documents", "downloads", "pictures", "movies", "music", "public"
    ]
    
    private static let systemNoiseComponents: Set<String> = [
        "library", "node_modules", ".git", ".svn", ".hg", "deriveddata",
        ".cache", ".npm", ".yarn", ".cargo", ".rustup", "pods", ".build",
        ".trash", ".terraform", "__pycache__", ".venv", "venv", ".gradle",
        ".docker", "site-packages", "build", "dist", ".next", ".xcodeproj",
        ".xcworkspace"
    ]
    
    /// 0: sitting loose in Home, or inside a well-known user-content folder (Desktop, Documents, ...)
    /// 1: elsewhere under Home, nothing suspicious about it
    /// 2: a dotfile/dot-folder that slipped through (configs, etc.)
    /// 3: known system/tooling noise (Library, node_modules, .git, caches, build output, Trash...)
    /// 4: outside the user's Home directory entirely
    private static func relevanceTier(for url: URL, homeDir: String) -> Int {
        let path = url.path
        guard path.hasPrefix(homeDir) else { return 4 }
        
        let lowerComponents = url.pathComponents.map { $0.lowercased() }
        if lowerComponents.contains(where: { systemNoiseComponents.contains($0) }) {
            return 3
        }
        
        if url.lastPathComponent.hasPrefix(".") {
            return 2
        }
        
        let relativePath = String(path.dropFirst(homeDir.count))
        let relativeComponents = relativePath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map { $0.lowercased() }
        
        if relativeComponents.isEmpty {
            return 0
        }
        
        if userContentFolderNames.contains(relativeComponents[0]) {
            return 0
        }
        
        if relativeComponents.count == 1 {
            return 0
        }
        
        return 1
    }
    
    var sortedFiles: [FileItem] {
        let baseFiles = (searchText.isEmpty || searchScope == .currentFolder) ? files : globalSearchResults
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSearching = !trimmedSearch.isEmpty
        
        let filtered = baseFiles.filter { file in
            guard isSearching else { return true }
            if searchScope == .currentFolder {
                return file.name.localizedCaseInsensitiveContains(trimmedSearch)
            }
            return true
        }
        
        let homeDir = NSHomeDirectory()
        
        return filtered.sorted { (a, b) -> Bool in
            if isSearching {
                let tierA = Self.relevanceTier(for: a.url, homeDir: homeDir)
                let tierB = Self.relevanceTier(for: b.url, homeDir: homeDir)
                if tierA != tierB {
                    return tierA < tierB
                }
            }
            
            switch currentSortingOption {
            case .name:
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .modificationDate:
                let d1 = a.modificationDate ?? Date.distantPast
                let d2 = b.modificationDate ?? Date.distantPast
                if d1 != d2 {
                    return d1 > d2
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .size:
                if let s1 = a.size, let s2 = b.size {
                    if s1 != s2 {
                        return s1 > s2
                    }
                } else if a.size != nil {
                    return true
                } else if b.size != nil {
                    return false
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }
    }
    
    private func performSearch() {
        let queryText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if searchScope == .thisMac && !queryText.isEmpty {
            runSpotlightQuery(text: queryText)
        } else {
            if let currentQuery = metadataQuery {
                currentQuery.stop()
                NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: currentQuery)
                NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: currentQuery)
                metadataQuery = nil
            }
            globalSearchResults = []
        }
    }
    
    private func runSpotlightQuery(text: String) {
        if let currentQuery = metadataQuery {
            currentQuery.stop()
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: currentQuery)
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: currentQuery)
        }
        
        let query = NSMetadataQuery()
        let namePredicate = NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", text)
        
        let excludePaths = ["/System/", "/Library/", "/usr/", "/bin/", "/sbin/", "/private/", "/var/"]
        var excludePredicates: [NSPredicate] = []
        for path in excludePaths {
            excludePredicates.append(NSPredicate(format: "NOT (kMDItemPath BEGINSWITH %@)", path))
        }
        
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [namePredicate] + excludePredicates)
        query.predicate = combinedPredicate
        query.searchScopes = [NSMetadataQueryIndexedLocalComputerScope]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMetadataQueryNotification(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMetadataQueryNotification(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        
        self.metadataQuery = query
        query.start()
    }
    
    @objc private func handleMetadataQueryNotification(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery,
              query === self.metadataQuery else { return }
        
        var results: [FileItem] = []
        
        query.disableUpdates()
        for item in query.results {
            if let metaItem = item as? NSMetadataItem,
               let path = metaItem.value(forAttribute: NSMetadataItemPathKey) as? String {
                let url = URL(fileURLWithPath: path)
                
                if path.contains("/.") { continue }
                
                let isDir = (metaItem.value(forAttribute: NSMetadataItemContentTypeKey) as? String) == "public.folder" || (metaItem.value(forAttribute: NSMetadataItemContentTypeKey) as? String) == "com.apple.package"
                let fileSize = metaItem.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber
                let modifDate = metaItem.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
                
                let fileItem = FileItem(
                    url: url,
                    name: url.lastPathComponent,
                    itemType: isDir ? .DIRECTORY : .FILE,
                    size: isDir ? nil : fileSize?.int64Value,
                    modificationDate: modifDate,
                    isHidden: url.lastPathComponent.hasPrefix(".")
                )
                results.append(fileItem)
            }
        }
        query.enableUpdates()
        
        let stableResults = results.sorted { (a, b) -> Bool in
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        
        DispatchQueue.main.async {
            self.globalSearchResults = stableResults
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
    
    func renameFile(file: FileItem, to newName: String) {
        let trimmedNewName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewName.isEmpty, trimmedNewName != file.url.lastPathComponent else { return }
        
        let destinationURL = file.url.deletingLastPathComponent().appendingPathComponent(trimmedNewName)
        
        do {
            try FileManager.default.moveItem(at: file.url, to: destinationURL)
            loadCurrentDirectory()
        } catch {
            print("Error renaming file \(error.localizedDescription)")
        }
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
        
        SoundEffects.playSoundEffect(name: "trash")
        
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

    func handleDrop(urls: [URL], to destinationFolder: URL? = nil) {
        let targetDir = destinationFolder ?? currentDir
        var hasChanges = false
        
        for sourceURL in urls {
            let destinationURL = targetDir.appendingPathComponent(sourceURL.lastPathComponent)
            if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
                continue
            }
            
            do {
                if sourceURL.path.hasPrefix(NSHomeDirectory()) {
                    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                } else {
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                }
                hasChanges = true
            } catch {
                print("Error handling drop: \(error.localizedDescription)")
            }
        }
        
        if hasChanges {
            loadCurrentDirectory()
        }
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
    
    func openInTerminal(url: URL) {
        let terminalBundleID = "com.apple.Terminal"
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
        } else {
            print("Terminal not found.")
        }
    }

    func openInVSCode(url: URL) {
        let vscodeBundleID = "com.microsoft.VSCode"
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: vscodeBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
        } else {
            print("VS Code not found.")
        }
    }
    
    func copyShellEscapedPath(for url: URL) {
        let escapedPath = url.path.replacingOccurrences(of: " ", with: "\\ ")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(escapedPath, forType: .string)
    }
    
    static func copySHA256Checksum(for fileURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: fileURL) else { return }
            let hash = SHA256.hash(data: data)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(hashString, forType: .string)
            }
        }
    }
    
    func compressToZip(files: [FileItem]) {
        guard !files.isEmpty else { return }
        let parentDir = files[0].url.deletingLastPathComponent()
        
        let zipName: String
        if files.count == 1 {
            zipName = "\(files[0].url.deletingPathExtension().lastPathComponent).zip"
        } else {
            zipName = "Archive.zip"
        }
        
            let destinationZipURL = parentDir.appendingPathComponent(zipName)
            
            let sourcePaths = files.map { $0.url.lastPathComponent }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.currentDirectoryURL = parentDir
                
                var arguments = ["-r", destinationZipURL.path]
                arguments.append(contentsOf: sourcePaths)
                process.arguments = arguments
            
            do {
                try process.run()
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    self.loadCurrentDirectory()
                }
            } catch {
                print("Error compressing to ZIP \(error.localizedDescription)")
            }
                
            SoundEffects.playSoundEffect(name: "confirmation")
        }
    }
    
    func openFileWith(file: FileItem) {
        let panel = NSOpenPanel()
        panel.title = "Select app used to open the file"
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.application, .applicationBundle]
        } else {
            panel.allowedFileTypes = ["app"]
        }
        panel.begin { response in
            guard response == .OK, let appURL = panel.url else { return }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([file.url], withApplicationAt: appURL, configuration: configuration) { runningApp, error in
                if let error = error {
                    print("Error opening file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    func createFolderFromSelection(files: [FileItem]) {
        guard !files.isEmpty else { return }
        let fileManager = FileManager.default
        
        let baseFolderURL = currentDir.appendingPathComponent("New Folder")
        var uniqueFolderURL = baseFolderURL
        var counter = 1
        while fileManager.fileExists(atPath: uniqueFolderURL.path) {
            uniqueFolderURL = currentDir.appendingPathComponent("New Folder \(counter)")
            counter += 1
        }
        
        do {
            try fileManager.createDirectory(at: uniqueFolderURL, withIntermediateDirectories: true)
            for file in files {
                let destination = uniqueFolderURL.appendingPathComponent(file.url.lastPathComponent)
                try fileManager.moveItem(at: file.url, to: destination)
            }
            
            loadCurrentDirectory()
        } catch {
            print("Error creating folder from selection: \(error.localizedDescription)")
        }
    }
}
