import SwiftUI
import Foundation
import Observation

enum FileItemType {
    case FILE
    case DIRECTORY
}

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
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

@Observable
class FolderViewModel {
    var currentDir: URL
    var files: [FileItem] = []
    
    init(startDir: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.currentDir = startDir
        loadCurrentDirectory()
    }
    
    func loadCurrentDirectory() {
        do {
            let dataKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            let content = try FileManager.default.contentsOfDirectory(
                at: currentDir,
                includingPropertiesForKeys: dataKeys
            )
            
            self.files = content.map { url in
                let resourceValues = try? url.resourceValues(forKeys: Set(dataKeys))
                
                let isDir = resourceValues?.isDirectory ?? false
                let fileSize = resourceValues?.fileSize
                let modifDate = resourceValues?.contentModificationDate
                let finalSize = isDir ? nil : (fileSize != nil ? Int64(fileSize!) : nil)
                
                return FileItem(
                    url: url,
                    name: url.lastPathComponent,
                    itemType: isDir ? .DIRECTORY : .FILE,
                    size: finalSize,
                    modificationDate: modifDate)
            }
            .sorted {
                if $0.itemType == .DIRECTORY && $1.itemType == .FILE { return true }
                if $0.itemType == .FILE && $1.itemType == .DIRECTORY { return false }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            
        } catch {
            print("Error while reading directory \(error.localizedDescription)")
            self.files = []
        }
    }
    
    func enterDirectory(dir: FileItem) {
        guard dir.itemType == .DIRECTORY else { return }
        currentDir = dir.url
        loadCurrentDirectory()
    }
    
    func goToParentDirectory() {
        let parentDir = currentDir.deletingLastPathComponent()
        if parentDir != currentDir {
            currentDir = parentDir
            loadCurrentDirectory()
        }
    }
}

struct ContentView: View {
    @State private var viewModel = FolderViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.goToParentDirectory() }) {
                    Image(systemName: "arrow.up")
                }
                .disabled(viewModel.currentDir.path == "/")
                
                Text(viewModel.currentDir.path)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { viewModel.loadCurrentDirectory() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            List {
                ForEach(viewModel.files) { file in
                    HStack {
                        HStack {
                            if file.itemType == .DIRECTORY {
                                Image(systemName: "folder.fill").foregroundColor(.blue)
                            } else {
                                Image(systemName: "doc.fill").foregroundColor(.secondary)
                            }
                            Text(file.name)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(file.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 150, alignment: .leading)
                        
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if file.itemType == .DIRECTORY {
                            viewModel.enterDirectory(dir: file)
                        } else {
                            NSWorkspace.shared.open(file.url)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    ContentView()
}
