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
            let content = try FileManager.default.contentsOfDirectory(
                at: currentDir,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            
            self.files = content.map { url in
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                let isDir = resourceValues?.isDirectory ?? false
                return FileItem(url: url, name: url.lastPathComponent, itemType: isDir ? .DIRECTORY : .FILE)
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
                        if file.itemType == .DIRECTORY {
                            Image(systemName: "folder.fill").foregroundColor(.blue)
                        } else {
                            Image(systemName: "doc.fill").foregroundColor(.secondary)
                        }
                        Text(file.name)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
