import Foundation

enum FileItemType {
    case FILE
    case DIRECTORY
}

// what is this monstrosity
enum SideBarItem: String, CaseIterable, Identifiable {
    case mac = "This Mac"
    case home = "Home"
    case desktop = "Desktop"
    case documents = "Documents"
    case downloads = "Downloads"
    case apps = "Apps"
    
    var id: String { self.rawValue }
    
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
    
    var iconName: String {
        switch self {
        case .mac: return "apple.logo"
        case .home: return "house"
        case .desktop: return "menubar.dock.rectangle"
        case .documents: return "doc.text"
        case .downloads: return "arrow.down.circle"
        case .apps: return "square.3.layers.3d"
        }
    }
}

// ngl i'm starting to like these
enum FileViewStyle: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case list = "List"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .grid: return "square.grid.3x3"
        case .list: return "list.bullet"
        }
    }
}

enum FileSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case size = "Size"
    case modificationDate = "Modification Date"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .name: return "textformat"
        case .size: return "gauge.with.dots.needle.bottom.0percent"
        case .modificationDate: return "calendar"
        }
    }
}
