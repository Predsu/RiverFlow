import Foundation
import Observation
import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct FileCollision: Identifiable {
    let sourceURL: URL
    let destinationURL: URL
    
    var id: URL { sourceURL }
}

/// View model for directory operations.
///
/// Includes folder navigation, file operations, searching and undo management.
@Observable
class FolderViewModel {
    var currentDir: URL
    var files: [FileItem] = []
    var currentSortingOption: FileSortOption = .name
    var sidebarRoots: [SidebarNode] = []
    
    var editingFileID: UUID? = nil
    var selectedFileIds: Set<UUID> = []
    
    var pasteboardURLs: [URL] = []
    var isOperationCut: Bool = false
    
    var historyBackward: [URL] = []
    var historyForward: [URL] = []
    
    var availableDiskSpace: String = ""
    var itemCountText: String = ""
    
    var gitBranch: String? = nil
    var gitUncommittedCount: Int = 0
    var isGitRepo: Bool = false
    var gitStatusMap: [URL: String] = [:]
    var gitBranches: [String] = []
    
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
    
    var fileCollision: FileCollision?
    private var pendingDropOperations: [(source: URL, destination: URL)] = []
    private var dropHadChanges = false
    
    deinit {
        if let query = metadataQuery {
            query.stop()
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
        }
    }
    
    /// Registers undo operation in UndoManager class instance.
    ///
    /// - Parameters:
    ///     - actionName: Self-explanatory identifier for undoable action usable in development as `String`.
    ///     - handler: Closure executing the undo operation on the target view model.
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
        self.sidebarRoots = SideBarItem.allCases.map { item in
            SidebarNode(name: item.rawValue, url: item.url, iconName: item.iconName, isRoot: true)
        }
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
    
    /// Evaluates file URL to determine its revelance tier for search sorting.
    /// 
    /// - 0: sitting loose in Home, or inside a well-known user-content folder (Desktop, Documents, ...)
    /// - 1: elsewhere under Home, nothing suspicious about it
    /// - 2: a dotfile/dot-folder that slipped through (configs, etc.)
    /// - 3: known system/tooling noise (Library, node_modules, .git, caches, build output, Trash...)
    /// - 4: outside the user's Home directory entirely
    ///
    /// - Parameters:
    ///     - url: URL of file to evaluate as `URL`.
    ///     - homeDir: Absolute path string of user's home directory as `String`.
    /// - Returns: Integer representing tier ranking (0 highest, 4 lowest) as `Int`.
    /// - Note: This does not guarantee perfect search results or no "junk files" in them.
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
    
    /// Triggers search processing or clears previous search states based on the active search scope.
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
    
    /// Initiates a system-wide Spotlight metadata query for specified text.
    ///
    /// - Parameter text: Search text as `String`.
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
    
    /// Receives and processes notifications emmited by `NSMetadataQuery` instance.
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
    
    /// Loads contents of current directory and updates file list.
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
            
            updateStatusBar()
            updateGitStatus()
            reloadSidebarTree()
            expandToURL(currentDir)
        } catch {
            print("Error while reading directory \(error.localizedDescription)")
            self.files = []
        }
    }
    
    /// Reloads the loaded folders in the sidebar tree.
    func reloadSidebarTree() {
        for root in sidebarRoots {
            if root.isLoaded {
                root.reloadChildren(showHidden: showHiddenFiles)
            }
        }
    }
    
    /// Recursively traverses and expands the sidebar nodes leading to the target URL.
    func expandToURL(_ targetURL: URL) {
        let target = targetURL.standardizedFileURL
        for root in sidebarRoots {
            if isParent(parent: root.url, child: target) {
                var current = root
                while current.url != target {
                    current.isExpanded = true
                    current.loadChildren(showHidden: showHiddenFiles)
                    
                    if let nextNode = current.children.first(where: { isParent(parent: $0.url, child: target) }) {
                        current = nextNode
                    } else {
                        break
                    }
                }
            }
        }
    }
    
    private func isParent(parent: URL, child: URL) -> Bool {
        let parentPath = parent.standardizedFileURL.path
        let childPath = child.standardizedFileURL.path
        
        if parentPath == childPath {
            return true
        }
        
        if parentPath == "/" {
            return true
        }
        
        let prefix = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
        return childPath.hasPrefix(prefix)
    }
    
    /// Navigates into the specified directory.
    func enterDirectory(dir: FileItem) {
        guard dir.itemType == .DIRECTORY else { return }
        historyBackward.append(currentDir)
        historyForward.removeAll()
        currentDir = dir.url
        loadCurrentDirectory()
    }
    
    /// Opens the currently selected files, or enters directory if a single folder is selected. If multiple directories are selected, temporarily opens them in Finder.
    func openSelectedFiles() {
        let targets = selectedFiles
        guard !targets.isEmpty else { return }
        
        if targets.count == 1, let singleItem = targets.first {
            if singleItem.url.pathExtension == "app" {
                NSWorkspace.shared.open(singleItem.url)
            } else if singleItem.itemType == .DIRECTORY {
                enterDirectory(dir: singleItem)
                selectedFileIds.removeAll()
            } else {
                NSWorkspace.shared.open(singleItem.url)
            }
        } else {
            for file in targets {
                NSWorkspace.shared.open(file.url)
            }
        }
    }
    
    /// Navigates one level up in directories tree.
    func goToParentDirectory() {
        let parentDir = currentDir.deletingLastPathComponent()
        if parentDir != currentDir {
            historyBackward.append(currentDir)
            historyForward.removeAll()
            currentDir = parentDir
            loadCurrentDirectory()
        }
    }
    
    func goBackward() {
        guard let previous = historyBackward.popLast() else { return }
        historyForward.append(currentDir)
        currentDir = previous
        loadCurrentDirectory()
    }
    
    func goForward() {
        guard let next = historyForward.popLast() else { return }
        historyBackward.append(currentDir)
        currentDir = next
        loadCurrentDirectory()
    }
    
    /// Creates new directory inside current directory with auto-incrementing name.
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
    
    /// Creates new file inside current directory with auto-incrementing name.
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
    
    /// Registers undo step for file or directory creation.
    /// - Parameters:
    ///     - url: URL of the created item as `URL`.
    ///     - isDirectory: Indicating wheter the created item is directory as `Bool`.
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
    
    /// Registers a redo step for recreating previously deleted file or directory.
    /// - Parameters:
    ///     - url: URL of item to recreate as `URL`.
    ///     - isDirectory: Indicating wheter the item is directory as `Bool`.
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
    
    /// Copies given files to the system pasteboard.
    func copyFiles(files: [FileItem]) {
        self.pasteboardURLs = files.map { $0.url }
        self.isOperationCut = false
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(files.map { $0.url as NSURL})
    }
    
    /// Copies given files to the system pasteboard and flags the operation as cut.
    func cutFiles(files: [FileItem]) {
        self.pasteboardURLs = files.map { $0.url }
        self.isOperationCut = true
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(files.map { $0.url as NSURL})
    }
    
    /// Renames a specified `FileItem`.
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
    
    /// Moves the specified files to system trash and registers undo operation.
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
    
    /// Moves currently selected files to system trash.
    func moveSelectedToTrash() {
        let targets = selectedFiles
        guard !targets.isEmpty else { return }
        moveToTrash(files: targets)
        selectedFileIds.removeAll()
    }
    
    /// Permanently deletes the specified files from the filesystem without moving them to trash.
    func permanentlyDelete(files: [FileItem]) {
        guard !files.isEmpty else { return }
        for file in files {
            do {
                try FileManager.default.removeItem(at: file.url)
            } catch {
                print("Error permanently deleting \(file.name): \(error.localizedDescription)")
            }
        }
        loadCurrentDirectory()
        SoundEffects.playSoundEffect(name: "trash")
    }

    /// Permanently deletes currently selected files from the filesystem.
    func permanentlyDeleteSelected() {
        let targets = selectedFiles
        guard !targets.isEmpty else { return }
        permanentlyDelete(files: targets)
        selectedFileIds.removeAll()
    }

    
    /// Registers undo step to restore items back from the trash to their original locations.
    /// - Parameter restorePairs: List of tuples linking the trashed URL with its original path URL.
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
    
    /// Registers a redo step to move restored items back to the trash.
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
    
    /// Pastes or moves files from pasteboard into current directory.
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

    /// Handles drag-and-drop file imports into targeted destination directory.
    /// - Parameters:
    ///     - urls: Array of file URLs dropped into app's view as `[URL]`.
    ///     - destinationFolder: Optional custom destination folder (falls back to `currentDir` if not specified) as `URL`.
    func handleDrop(urls: [URL], to destinationFolder: URL? = nil) {
        let targetDir = destinationFolder ?? currentDir
        pendingDropOperations = urls.compactMap { sourceURL in
            let destinationURL = targetDir.appendingPathComponent(sourceURL.lastPathComponent)
            return sourceURL.standardizedFileURL == destinationURL.standardizedFileURL
                ? nil
                : (source: sourceURL, destination: destinationURL)
        }
        dropHadChanges = false
        processNextDropOperation()
    }
    
    func resolveFileCollision(_ choice: FileCollisionChoice) {
        guard let collision = fileCollision else { return }
        fileCollision = nil
        
        switch choice {
        case .skip:
            break
        case .replace:
            do {
                try FileManager.default.removeItem(at: collision.destinationURL)
                try transferDroppedItem(from: collision.sourceURL, to: collision.destinationURL)
                dropHadChanges = true
            } catch {
                print("Error replacing dropped file: \(error.localizedDescription)")
            }
        case .keepBoth:
            let uniqueDestination = uniqueDropDestination(for: collision.sourceURL, to: collision.destinationURL.deletingLastPathComponent())
            do {
                try transferDroppedItem(from: collision.sourceURL, to: uniqueDestination)
                dropHadChanges = true
            } catch {
                print("Error keeping both dropped files: \(error.localizedDescription)")
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.processNextDropOperation()
        }
    }
    
    private func processNextDropOperation() {
        while !pendingDropOperations.isEmpty {
            let operation = pendingDropOperations.removeFirst()
            if FileManager.default.fileExists(atPath: operation.destination.path) {
                fileCollision = FileCollision(sourceURL: operation.source, destinationURL: operation.destination)
                return
            }
            do {
                try transferDroppedItem(from: operation.source, to: operation.destination)
                dropHadChanges = true
            } catch {
                print("Error handling drop: \(error.localizedDescription)")
            }
        }
        if dropHadChanges {
            loadCurrentDirectory()
        }
    }
    
    private func transferDroppedItem(from sourceURL: URL, to destinationURL: URL) throws {
        if sourceURL.path.hasPrefix(NSHomeDirectory()) {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        } else {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
    }
    
    private func uniqueDropDestination(for sourceURL: URL, to directory: URL) -> URL {
        let fileExtension = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var counter = 2
        var destination = directory.appendingPathComponent("\(baseName) \(counter)")
        if !fileExtension.isEmpty {
            destination.appendPathExtension(fileExtension)
        }
        while FileManager.default.fileExists(atPath: destination.path) {
            counter += 1
            destination = directory.appendingPathComponent("\(baseName) \(counter)")
            if !fileExtension.isEmpty {
                destination.appendPathExtension(fileExtension)
            }
        }
        return destination
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
    
    /// Opens the specified directory URL in system Terminal.
    func openInTerminal(url: URL) {
        let terminalBundleID = "com.apple.Terminal"
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
        } else {
            print("Terminal not found.")
        }
    }

    /// Opens the specified directory URL in VSCode (if installed).
    func openInVSCode(url: URL) {
        let vscodeBundleID = "com.microsoft.VSCode"
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: vscodeBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
        } else {
            print("VS Code not found.")
        }
    }
    
    /// Copies a shell-escaped string representation of the URL path to the system pasteboard.
    func copyShellEscapedPath(for url: URL) {
        let escapedPath = url.path.replacingOccurrences(of: " ", with: "\\ ")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(escapedPath, forType: .string)
    }
    
    /// Generates SHA256 checksum for selected file asynchronously and copies the hash string to system pasteboard.
    ///
    /// - Parameters fileURL: Target file URL as `URL`.
    /// - Warning: Disabled in main program, didn't work when first implemented. Not for use, issue fixing ongoing.
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
    
    private func runGitCommand(args: [String], in directory: URL? = nil) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = directory ?? currentDir
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            _ = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return nil
            }
            
            if let output = String(data: data, encoding: .utf8) {
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            return nil
        }
        return nil
    }
    
    func updateGitStatus() {
        let directoryToCheck = currentDir
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let gitRootPath = self.runGitCommand(args: ["rev-parse", "--show-toplevel"], in: directoryToCheck) else {
                DispatchQueue.main.async {
                    guard self.currentDir == directoryToCheck else { return }
                    self.isGitRepo = false
                    self.gitBranch = nil
                    self.gitUncommittedCount = 0
                    self.gitStatusMap = [:]
                    self.gitBranches = []
                }
                return
            }
            
            let gitRootURL = URL(fileURLWithPath: gitRootPath).standardizedFileURL
            
            let branch = self.runGitCommand(args: ["branch", "--show-current"], in: directoryToCheck)
            
            var newStatusMap: [URL: String] = [:]
            var uncommittedCount = 0
            
            if let statusOutput = self.runGitCommand(args: ["status", "--porcelain"], in: directoryToCheck) {
                let lines = statusOutput.components(separatedBy: .newlines)
                
                for line in lines {
                    guard line.count >= 4 else { continue }
                    uncommittedCount += 1
                    
                    let startIndex = line.startIndex
                    let x = line[startIndex]
                    let y = line[line.index(after: startIndex)]
                    
                    let pathPart = String(line[line.index(startIndex, offsetBy: 3)...])
                    
                    let relativePath: String
                    if pathPart.contains(" -> ") {
                        relativePath = pathPart.components(separatedBy: " -> ").last?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? pathPart
                    } else {
                        relativePath = pathPart.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    let code = String(x) + String(y)
                    let fileURL = gitRootURL.appendingPathComponent(relativePath).standardizedFileURL
                    newStatusMap[fileURL] = code
                }
            }
            
            var propagatedMap = newStatusMap
            for (fileURL, code) in newStatusMap {
                let folderCode: String
                if code.contains("M") || code.contains("D") {
                    folderCode = " m"
                } else if code.contains("A") {
                    folderCode = " a"
                } else {
                    folderCode = "??"
                }
                
                var parentURL = fileURL.deletingLastPathComponent().standardizedFileURL
                while parentURL.path.hasPrefix(gitRootURL.path) && parentURL != gitRootURL {
                    let currentPropagatedCode = propagatedMap[parentURL]
                    
                    if currentPropagatedCode == nil {
                        propagatedMap[parentURL] = folderCode
                    } else {
                        if folderCode.contains("m") {
                            propagatedMap[parentURL] = " m"
                        } else if folderCode.contains("a") && !(currentPropagatedCode?.contains("m") ?? false) {
                            propagatedMap[parentURL] = " a"
                        }
                    }
                    
                    let nextParent = parentURL.deletingLastPathComponent().standardizedFileURL
                    if nextParent == parentURL { break }
                    parentURL = nextParent
                }
            }
            
            let branches = self.runGitCommand(args: ["branch", "--format=%(refname:short)"], in: directoryToCheck)?
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            
            DispatchQueue.main.async {
                guard self.currentDir == directoryToCheck else { return }
                self.isGitRepo = true
                self.gitBranch = branch
                self.gitUncommittedCount = uncommittedCount
                self.gitStatusMap = propagatedMap
                self.gitBranches = branches
            }
        }
    }
    
    func isFileStaged(url: URL) -> Bool {
        guard let code = gitStatusMap[url.standardizedFileURL], code.count == 2 else { return false }
        let x = code[code.startIndex]
        return x != " " && x != "?"
    }
    
    func isFileUnstaged(url: URL) -> Bool {
        guard let code = gitStatusMap[url.standardizedFileURL], code.count == 2 else { return false }
        let x = code[code.startIndex]
        let y = code[code.index(after: code.startIndex)]
        return y != " " || (x == "?" && y == "?")
    }
    
    private func updateStatusBar() {
        let count = files.count
        itemCountText = "\(count) item\(count == 1 ? "" : "s")"
        
        do {
            let vals = try currentDir.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let capacity = vals.volumeAvailableCapacity {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useAll]
                formatter.countStyle = .file
                availableDiskSpace = formatter.string(fromByteCount: Int64(capacity)) + " available"
            } else {
                availableDiskSpace = ""
            }
        } catch {
            availableDiskSpace = ""
        }
    }
    
    func gitStage(file: FileItem) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runGitCommand(args: ["add", file.url.path])
            self.updateGitStatus()
            DispatchQueue.main.async {
                self.loadCurrentDirectory()
            }
        }
    }
    
    func gitUnstage(file: FileItem) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runGitCommand(args: ["restore", "--staged", file.url.path])
            self.updateGitStatus()
            DispatchQueue.main.async {
                self.loadCurrentDirectory()
            }
        }
    }
    
    func gitDiscard(file: FileItem) {
        let status = gitStatusMap[file.url.standardizedFileURL]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if status == "??" {
                DispatchQueue.main.async {
                    do {
                        try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                        self.loadCurrentDirectory()
                    } catch {
                        print("Error trashing untracked file: \(error.localizedDescription)")
                    }
                }
            } else {
                _ = self.runGitCommand(args: ["restore", file.url.path])
                self.updateGitStatus()
                DispatchQueue.main.async {
                    self.loadCurrentDirectory()
                }
            }
        }
    }
    
    func copyGitRelativePath(for url: URL) {
        guard let gitRootPath = runGitCommand(args: ["rev-parse", "--show-toplevel"]) else { return }
        let gitRootURL = URL(fileURLWithPath: gitRootPath).standardizedFileURL
        var relativePath = url.standardizedFileURL.path.replacingOccurrences(of: gitRootURL.path + "/", with: "")
        if relativePath == gitRootURL.path {
            relativePath = "."
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(relativePath, forType: .string)
    }
    
    func getGitHubOrGitLabURL(for url: URL) -> URL? {
        guard let remoteURLString = runGitCommand(args: ["config", "--get", "remote.origin.url"]) else { return nil }
        guard let gitRootPath = runGitCommand(args: ["rev-parse", "--show-toplevel"]) else { return nil }
        
        let gitRootURL = URL(fileURLWithPath: gitRootPath).standardizedFileURL
        let fileRelativePath = url.standardizedFileURL.path.replacingOccurrences(of: gitRootURL.path + "/", with: "")
        let branch = runGitCommand(args: ["branch", "--show-current"]) ?? "unknown"
        
        var webURLString = remoteURLString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "git@", with: "https://")
            .replacingOccurrences(of: "ssh://", with: "")
            .replacingOccurrences(of: "https://github.com:", with: "https://github.com/")
            .replacingOccurrences(of: "https://gitlab.com:", with: "https://gitlab.com/")
        
        if webURLString.hasSuffix(".git") {
            webURLString = String(webURLString.dropLast(4))
        }
        
        let separator = webURLString.contains("gitlab.com") ? "/-/blob/" : "/blob/"
        
        guard let encodedPath = fileRelativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        let finalURLString = "\(webURLString)\(separator)\(branch)/\(encodedPath)"
        
        return URL(string: finalURLString)
    }
    
    func openInGitHubOrGitLab(file: FileItem) {
        if let webURL = getGitHubOrGitLabURL(for: file.url) {
            NSWorkspace.shared.open(webURL)
        }
    }
    
    func checkoutBranch(name: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runGitCommand(args: ["checkout", name])
            self.updateGitStatus()
            DispatchQueue.main.async {
                self.loadCurrentDirectory()
            }
        }
    }
}
