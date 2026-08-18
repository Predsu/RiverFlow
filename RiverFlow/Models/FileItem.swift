import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Represents a file or directory item in the file system.
///
/// `FileItem` encapsulates all information needed to display and interact with a file or directory.
/// It includes metadata such as size, modification date, and type, along with formatted display strings.
/// This structure is used throughout the app for file listing, searching, and operations.
///
/// `FileItem` conforms to `Identifiable` for use in SwiftUI collections and `Transferable`
/// for drag-and-drop support.
struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let itemType: FileItemType
    let size: Int64?
    let modificationDate: Date?
    let isHidden: Bool
    
    // i hate computed properties i hate computed properties i hate computed properties
    /// A human-readable size string formatted according to system locale.
    ///
    /// Formats the file size using `ByteCountFormatter` with file count style.
    /// Returns "--" if size information is unavailable (e.g., for directories).
    ///
    /// - Returns: Formatted size string (e.g., "1.5 MB", "45 KB", or "--").
    var formattedSize: String {
        guard let size = size else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // i love computed properties i love computed properties i love computed properties
    /// A human-readable modification date and time string formatted according to system locale.
    ///
    /// Formats the modification date using short date style and medium time style.
    /// Returns "--" if date information is unavailable.
    ///
    /// - Returns: Formatted date and time string (e.g., "8/18/26, 10:30:45 AM" or "--").
    var formattedDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    /// The file extension as an uppercase string, or empty string if no extension exists.
    ///
    /// Extracts and uppercases the file extension for display in file icons.
    /// Returns an empty string for files without extensions or directories.
    ///
    /// - Returns: Uppercase file extension (e.g., "PDF", "SWIFT", "JPG") or empty string.
    var fileExtensionIconText: String {
        let exten = url.pathExtension.lowercased()
        if exten.isEmpty { return "" }
        
        // change it later for God's sake
        switch exten {
        default: return exten.uppercased()
        }
    }
}

extension FileItem: Transferable {
    /// Enables drag-and-drop support by providing the file URL as the transferred value.
    ///
    /// This allows files to be dragged from this app and dropped into other applications that accept file URLs via the pasteboard.
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.url)
    }
}
