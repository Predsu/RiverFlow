import Foundation

/// Structure representing folder path autocompletion suggestion.
struct PathSuggestion: Identifiable, Sendable, Hashable {
    let id: String
    let url: URL
    let path: String
    let displayName: String
    let relativeDisplayPath: String
    let revelanceTier: Int
    
    init(url: URL, homeDir: String, revelanceTier: Int) {
        self.id = url.standardizedFileURL.path()
        self.url = url.standardizedFileURL
        self.path = url.standardizedFileURL.path
        self.displayName = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
        self.revelanceTier = revelanceTier
        
        let pathString = url.standardizedFileURL.path
        if pathString == homeDir {
            self.relativeDisplayPath = "~"
        } else if pathString.hasPrefix(homeDir + "/") {
            self.relativeDisplayPath = "~/" + String(pathString.dropFirst(homeDir.count + 1))
        } else {
            self.relativeDisplayPath = pathString
        }
    }
}

/// Service providing directory autocompletion suggestions strictly filtered to user-created folders and common user directories (tier 0 and tier 1).
final class PathAutocompleteService: @unchecked Sendable {
    static let shared = PathAutocompleteService()
    
    private let fileManager = FileManager.default
    
    /// Normalizes and expands an input path, replacing ~ with the user's home directory.
    static func expandPath(_ path: String, currentDir: URL? = nil, homeDir: String = NSHomeDirectory()) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty { return "" }
        if trimmed == "~" { return homeDir }
        if trimmed.hasPrefix("~/") { return (homeDir as NSString).appendingPathComponent(String(trimmed.dropFirst(2))) }
        if trimmed.hasPrefix("/") { return trimmed }
        
        if let currentDir = currentDir {
            return (currentDir.path as NSString).appendingPathComponent(trimmed)
        }
        return (homeDir as NSString).appendingPathComponent(trimmed)
    }
    
    /// Returns autocompletion suggestions for the given query string. Only folders in relevance tiers 0 and 1 are returned.
    func autocompletionSuggestions(
        for query: String,
        currentDir: URL? = nil,
        homeDir: String = NSHomeDirectory(),
        maxResults: Int = 20
    ) -> [PathSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var resultsMap: [String: PathSuggestion] = [:]
        
        func addCandidate(_ url: URL) {
            let standardized = url.standardizedFileURL
            let path = standardized.path
            guard resultsMap[path] == nil else { return }
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                return
            }
            
            let tier = FolderViewModel.relevanceTier(for: standardized, homeDir: homeDir)
            if tier == 0 || tier == 1 {
                resultsMap[path] = PathSuggestion(url: standardized, homeDir: homeDir, revelanceTier: tier)
            }
        }
        
        if trimmed.isEmpty || trimmed == "~" || trimmed == "~/" {
            let homeURL = URL(fileURLWithPath: homeDir)
            addCandidate(homeURL)

            let commonSubfolders = ["Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music"]
            for name in commonSubfolders {
                let subURL = homeURL.appendingPathComponent(name, isDirectory: true)
                addCandidate(subURL)
            }
            
            if let directChildren = try? fileManager.contentsOfDirectory(
                at: homeURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: [.skipsHiddenFiles]
            ) {
                for child in directChildren {
                    addCandidate(child)
                }
            }
        } else {
            let expandedPath = Self.expandPath(trimmed, currentDir: currentDir, homeDir: homeDir)
            let expandedURL = URL(fileURLWithPath: expandedPath)
            
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: expandedPath, isDirectory: &isDir), isDir.boolValue {
                addCandidate(expandedURL)
                
                if let subdirs = try? fileManager.contentsOfDirectory(
                    at: expandedURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for subdir in subdirs {
                        addCandidate(subdir)
                    }
                }
            }
            let parentURL = expandedURL.deletingLastPathComponent()
            let partialName = expandedURL.lastPathComponent.lowercased()
            if fileManager.fileExists(atPath: parentURL.path, isDirectory: &isDir), isDir.boolValue {
                if let subdirs = try? fileManager.contentsOfDirectory(
                    at: parentURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for subdir in subdirs {
                        let subdirName = subdir.lastPathComponent.lowercased()
                        if subdirName.hasPrefix(partialName) || subdirName.localizedCaseInsensitiveContains(partialName) {
                            addCandidate(subdir)
                        }
                    }
                }
            }
            if resultsMap.count < maxResults {
                let searchWord = trimmed.hasPrefix("~/") || trimmed.hasPrefix("/")
                    ? expandedURL.lastPathComponent.lowercased()
                    : trimmed.lowercased()
                
                if !searchWord.isEmpty {
                    let homeURL = URL(fileURLWithPath: homeDir)
                    let commonRoots = [
                        homeURL,
                        homeURL.appendingPathComponent("Desktop"),
                        homeURL.appendingPathComponent("Documents"),
                        homeURL.appendingPathComponent("Downloads"),
                        homeURL.appendingPathComponent("Pictures"),
                        homeURL.appendingPathComponent("Movies"),
                        homeURL.appendingPathComponent("Music")
                    ]
                    
                    for root in commonRoots {
                        guard fileManager.fileExists(atPath: root.path) else { continue }
                        if let subdirs = try? fileManager.contentsOfDirectory(
                            at: root,
                            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                            options: [.skipsHiddenFiles]
                        ) {
                            for subdir in subdirs {
                                let name = subdir.lastPathComponent.lowercased()
                                if name.hasPrefix(searchWord) || name.localizedCaseInsensitiveContains(searchWord) {
                                    addCandidate(subdir)
                                }
                            }
                        }
                    }
                }
            }
        }
        let sorted = resultsMap.values.sorted { (a, b) -> Bool in
            if a.revelanceTier != b.revelanceTier {
                return a.revelanceTier < b.revelanceTier
            }
            if a.displayName.count != b.displayName.count {
                return a.displayName.count < b.displayName.count
            }
            return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
        }
        
        return Array(sorted.prefix(maxResults))
    }
}
