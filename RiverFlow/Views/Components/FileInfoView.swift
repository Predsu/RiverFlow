import SwiftUI

/// SwiftUI view presenting element's data in separate window.
///
/// Handles automatic size calculation running in background and QuickLook thumbnails.
struct FileInfoView: View {
    let file: FileItem
    weak var window: NSWindow?
    
    @State private var displaySize: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                FileIconView(file: file, baseSize: 64)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(file.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(file.itemType == .DIRECTORY ? "Directory" : "File")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Size:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(displaySize)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Modified:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(file.formattedDate)
                        .textSelection(.enabled)
                }
                
                HStack(alignment: .top) {
                    Text("Path:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(file.url.path)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .frame(minHeight: 32, maxHeight: 64)
                        .textSelection(.enabled)
                        .truncationMode(.head)
                        .help(file.url.path)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Close") {
                    window?.performClose(nil)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: 260)
        .onAppear {
            if file.itemType == .DIRECTORY {
                displaySize = "Calculating..."
                Task(priority: .userInitiated) {
                    let size = await calculateFolderSize(at: file.url)
                    displaySize = formatBytes(size)
                }
            } else {
                displaySize = file.formattedSize
            }
        }
    }
    
    /// Calculates total folder contents size.
    ///
    /// Recursively searches through folder, skipping hidden files and insides of `.app` bundles.
    /// Supports task cancellation (`Task.isCancelled`).
    ///
    /// - Parameter url: URL path to target folder as `URL`.
    /// - Returns: Total size in bytes as `Int64`.
    private func calculateFolderSize(at url: URL) async -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { (url, error) -> Bool in
                print("Error at \(url.path): \(error.localizedDescription)")
                return true
            }
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { return totalSize }
            
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            
            if let isDir = resourceValues.isDirectory, !isDir {
                if let size = resourceValues.fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return totalSize
    }
    
    /// Formats raw bytes number into human-readable text.
    ///
    /// - Parameter bytes: Bytes number as `Int64`.
    /// - Returns: Automatically formatted bytes as `String` (e.g., "1.2 MB").
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
