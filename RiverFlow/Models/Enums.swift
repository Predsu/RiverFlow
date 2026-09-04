import Foundation

/// Represents the type of a file system item.
///
/// Used to distinguish between regular files and directories for display and behavior purposes.
enum FileItemType {
    case FILE
    case DIRECTORY
}

/// Represents a location in the file system that can be quickly accessed from the sidebar.
///
/// Each sidebar item maps to a standard macOS directory location. Users can navigate to these
/// predefined locations quickly without manually browsing the file hierarchy.
// what is this monstrosity
enum SideBarItem: String, CaseIterable, Identifiable {
    case mac = "This Mac"
    case home = "Home"
    case desktop = "Desktop"
    case documents = "Documents"
    case downloads = "Downloads"
    case apps = "Apps"
    
    var id: String { self.rawValue }
    
    /// The file system URL corresponding to this sidebar location.
    ///
    /// Returns the absolute URL for the location represented by this sidebar item.
    /// For standard directories like Desktop or Downloads, uses `FileManager` to retrieve the actual location, which may vary based on system configuration.
    ///
    /// - Returns: The file system URL for this sidebar location.
    var url: URL {
        switch self {
        case .mac:
            return URL(fileURLWithPath: "/")
        case .home:
            return URL(fileURLWithPath: NSHomeDirectory())
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        case .apps:
            return FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask).first!
        }
    }
    
    /// SF Symbols name for the icon representing this sidebar location.
    var iconName: String {
        switch self {
        case .mac: return "desktopcomputer"
        case .home: return "house"
        case .desktop: return "menubar.dock.rectangle"
        case .documents: return "doc.text"
        case .downloads: return "arrow.down.circle"
        case .apps: return "square.3.layers.3d"
        }
    }
}

// ngl i'm starting to like these
/// Represents the layout style for displaying files in the main view.
///
/// Users can switch between grid and list views to organize file display according to their preference.
enum FileViewStyle: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case list = "List"
    
    var id: String { self.rawValue }
    
    /// SF Symbols name for the icon representing this view style.
    var iconName: String {
        switch self {
        case .grid: return "square.grid.3x3"
        case .list: return "list.bullet"
        }
    }
}

/// Represents the sorting criterion for organizing files in the view.
///
/// Users can sort files by name, size, or modification date. The sort order is maintained
/// across navigation and applies to both current folder and search results (with relevance tiers).
enum FileSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case size = "Size"
    case modificationDate = "Modification Date"
    
    var id: String { self.rawValue }
    
    /// SF Symbols name for the icon representing this sort option.
    var iconName: String {
        switch self {
        case .name: return "textformat"
        case .size: return "gauge.with.dots.needle.bottom.0percent"
        case .modificationDate: return "calendar"
        }
    }
}

/// Defines the scope for file search operations.
///
/// Users can search within the current folder for quick filtering, or across the entire Mac using the Spotlight index for system-wide discovery. Search scope affects both the search behavior and result sorting (search results across the Mac are ranked by relevance tier).
enum SearchScope: String, CaseIterable, Identifiable {
    case currentFolder = "Current Folder"
    case thisMac = "This Mac"
    
    var id: String { rawValue }
}

enum FileCollisionChoice {
    case skip
    case replace
    case keepBoth
}
