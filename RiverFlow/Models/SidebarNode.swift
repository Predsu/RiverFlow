import Foundation
import Observation

@Observable
class SidebarNode: Identifiable, Hashable {
    var id: URL { url }
    let name: String
    let url: URL
    let iconName: String
    let isRoot: Bool
    
    var isExpanded: Bool = false
    var isLoaded: Bool = false
    var children: [SidebarNode] = []
    
    private var hasSubfoldersCached: Bool? = nil
    
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
    
    var hasSubfolders: Bool {
        if let cached = hasSubfoldersCached {
            return cached
        }
        if isLoaded {
            let val = !children.isEmpty
            hasSubfoldersCached = val
            return val
        }
        let val = checkHasSubfolders()
        hasSubfoldersCached = val
        return val
    }
    
    private func checkHasSubfolders() -> Bool {
        let fileManager = FileManager.default
        do {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)
            for itemURL in contents {
                let resourceValues = try? itemURL.resourceValues(forKeys: Set(keys))
                let isDir = resourceValues?.isDirectory ?? false
                let isHidden = resourceValues?.isHidden ?? false
                let startsWithDot = itemURL.lastPathComponent.hasPrefix(".")
                
                if isDir && !isHidden && !startsWithDot {
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
        guard !isLoaded else { return }
        isLoaded = true
        
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
                    
                    subfolders.append(SidebarNode(
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
        let oldChildrenMap = Dictionary(uniqueKeysWithValues: children.map { ($0.url, $0) })
        isLoaded = false
        hasSubfoldersCached = nil
        loadChildren(showHidden: showHidden)
        
        for child in children {
            if let oldChild = oldChildrenMap[child.url] {
                child.isExpanded = oldChild.isExpanded
                if oldChild.isLoaded {
                    child.reloadChildren(showHidden: showHidden)
                }
            }
        }
    }
}
