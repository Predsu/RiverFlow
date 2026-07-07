import Foundation

enum FileItemType {
    case FILE
    case DIRECTORY
}

// what is this monstrosity
enum SideBarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case desktop = "Desktop"
    case documents = "Documents"
    case downloads = "Downloads"
    
    var id: String { self.rawValue }
    
    var url: URL {
        switch self {
        case .home:
            return URL(fileURLWithPath: NSHomeDirectory())
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house"
        case .desktop: return "menubar.dock.rectangle"
        case .documents: return "doc.text"
        case .downloads: return "arrow.down.circle"
        }
    }
}

// ngl i'm starting to like these
enum ElementsViewStyle: String, CaseIterable, Identifiable {
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
