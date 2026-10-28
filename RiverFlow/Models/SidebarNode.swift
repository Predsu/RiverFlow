import Foundation
import Observation

@Observable
class SidebarNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let iconName: String
    let isRoot: Bool
    
    var isExpanded: Bool = false
    var isLoaded: Bool = false
    var children: [SidebarNode] = []
    
    private var hasSubfoldersCached: Bool? = nil
    private var loadedWithHiddenFiles: Bool? = nil
    
    init(name: String, url: URL, iconName: String, isRoot: Bool = false) {
        self.name = name
        self.url = url.standardizedFileURL
        self.iconName = iconName
        self.isRoot = isRoot
    }
    
    static func == (lhs: SidebarNode, rhs: SidebarNode) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func hasSubfolders(showHidden: Bool) -> Bool {
        if loadedWithHiddenFiles != showHidden {
            hasSubfoldersCached = nil
            if isLoaded {
                loadChildren(showHidden: showHidden)
            }
        }
        if let cached = hasSubfoldersCached {
            return cached
        }
        if isLoaded {
            let val = !children.isEmpty
            hasSubfoldersCached = val
            return val
        }
        let val = checkHasSubfolders(showHidden: showHidden)
        hasSubfoldersCached = val
        loadedWithHiddenFiles = showHidden
        return val
    }
    
    private func checkHasSubfolders(showHidden: Bool) -> Bool {
        let fileManager = FileManager.default
        do {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: showHidden ? [] : .skipsHiddenFiles)
            for itemURL in contents {
                let resourceValues = try? itemURL.resourceValues(forKeys: Set(keys))
                let isDir = resourceValues?.isDirectory ?? false
                let isHidden = resourceValues?.isHidden ?? false
                let startsWithDot = itemURL.lastPathComponent.hasPrefix(".")
                
                if isDir && (showHidden || (!isHidden && !startsWithDot)) {
                    let ext = itemURL.pathExtension.lowercased()
                    if ext != "app" && ext != "xcodeproj" && ext != "xcworkspace" {
                        return true
                    }
                }
            }
        } catch {}
        return false
    }
    
    /// Loads the immediate child folders (directories only) of this node.
    func loadChildren(showHidden: Bool) {
        guard !isLoaded || loadedWithHiddenFiles != showHidden else { return }
        isLoaded = true
        loadedWithHiddenFiles = showHidden
        
        let fileManager = FileManager.default
        do {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
            let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : .skipsHiddenFiles
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: options
            )
            
            var subfolders: [SidebarNode] = []
            let existingChildren = Dictionary(uniqueKeysWithValues: children.map { ($0.url, $0) })
            for itemURL in contents {
                let resourceValues = try? itemURL.resourceValues(forKeys: Set(keys))
                let isDir = resourceValues?.isDirectory ?? false
                let isHidden = resourceValues?.isHidden ?? false
                let startsWithDot = itemURL.lastPathComponent.hasPrefix(".")
                
                if isDir {
                    if !showHidden && (isHidden || startsWithDot) {
                        continue
                    }
                    
                    let ext = itemURL.pathExtension.lowercased()
                    if ext == "app" || ext == "xcodeproj" || ext == "xcworkspace" {
                        continue
                    }
                    
                    subfolders.append(existingChildren[itemURL.standardizedFileURL] ?? SidebarNode(
                        name: itemURL.lastPathComponent,
                        url: itemURL.standardizedFileURL,
                        iconName: "folder"
                    ))
                }
            }
            
            subfolders.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            self.children = subfolders
            self.hasSubfoldersCached = !subfolders.isEmpty
        } catch {
            print("Error loading children for \(url.path): \(error.localizedDescription)")
            self.children = []
            self.hasSubfoldersCached = false
        }
    }
    
    /// Reloads the child folders, preserving the expansion state of existing child nodes if possible.
    func reloadChildren(showHidden: Bool) {
        isLoaded = false
        hasSubfoldersCached = nil
        loadChildren(showHidden: showHidden)
        
        for child in children {
            if child.isExpanded {
                child.reloadChildren(showHidden: showHidden)
            } else {
                child.invalidateChildren()
            }
        }
    }

    func invalidateChildren() {
        isLoaded = false
        hasSubfoldersCached = nil
    }

    /// Discard hidden expansion state so reopening a branch starts at one level.
    func collapse() {
        isExpanded = false
        invalidateChildren()
        for child in children {
            child.collapse()
        }
    }

    /// Close everything outside the path without reading any new directories.
    func collapseOutsidePath(to target: URL) {
        for child in children {
            if child.url != target && Self.contains(target, in: child.url) {
                child.collapseOutsidePath(to: target)
            } else {
                child.collapse()
            }
        }
    }

    static func contains(_ target: URL, in directory: URL) -> Bool {
        let parent = directory.standardizedFileURL.pathComponents
        let child = target.standardizedFileURL.pathComponents
        return child.starts(with: parent)
    }
}

struct SidebarEntry: Identifiable {
    let node: SidebarNode
    let rootID: UUID
    let depth: Int

    var id: UUID { node.id }
}
