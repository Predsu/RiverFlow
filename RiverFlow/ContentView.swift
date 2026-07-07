import SwiftUI
import Foundation
import Observation

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
    @State private var selectedSideBarItem: SideBarItem? = .home
    
    var body: some View {
        NavigationSplitView {
            List(SideBarItem.allCases, selection: $selectedSideBarItem) { item in
                HStack {
                    Image(systemName: item.iconName)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(item.rawValue)
                }
                .tag(item)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 180, idealWidth: 200)
            
        } detail: {
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
                                .lineLimit(1)
                            
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
                        .contextMenu {
                            Button(action: {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(file.url.path, forType: .string)
                            }) {
                                Text("Copy Full Path")
                                Image(systemName: "doc.on.doc")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                do {
                                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                                    viewModel.loadCurrentDirectory() // Odświeżamy listę po usunięciu
                                } catch {
                                    print("Error while moving item to trash: \(error.localizedDescription)")
                                }
                            }) {
                                Text("Move to Trash")
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 450, minHeight: 400)
        }
        .onChange(of: selectedSideBarItem) { _, newValue in
            if let newSection = newValue {
                viewModel.currentDir = newSection.url
                viewModel.loadCurrentDirectory()
            }
        }
    }
}

#Preview {
    ContentView()
}
