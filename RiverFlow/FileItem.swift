import Foundation

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let itemType: FileItemType
    let size: Int64?
    let modificationDate: Date?
    
    // i hate computed properties i hate computed properties i hate computed properties
    var formattedSize: String {
        guard let size = size else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // i love computed properties i love computed properties i love computed properties
    var formattedDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    var fileExtensionIconText: String {
        let exten = url.pathExtension.lowercased()
        if exten.isEmpty { return "" }
        
        // change it later for God's sake
        switch exten {
        default: return exten.uppercased()
        }
    }
}
