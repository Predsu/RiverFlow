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

struct FileIconView: View {
    let file: FileItem
    var baseSize: CGFloat = 64
    
    var body: some View {
        if file.itemType == .DIRECTORY {
            Image(systemName: "folder")
                .font(.system(size: baseSize))
                .foregroundColor(.blue)
        } else {
            ZStack(alignment: .bottom) {
                Image(systemName: "doc")
                    .font(.system(size: baseSize))
                    .foregroundColor(.secondary)
                
                if !file.fileExtensionIconText.isEmpty {
                    Text(file.fileExtensionIconText)
                        .font(.system(size: baseSize * 0.18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 2)
                        .padding(.bottom, baseSize * 0.22)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

@Observable
class FolderViewModel {
    var currentDir: URL
    var files: [FileItem] = []
    
    var showHiddenFiles: Bool = false {
        didSet {
            loadCurrentDirectory()
        }
    }
    
    var currentDirName: String {
        return currentDir.path == "/" ? "/" : currentDir.lastPathComponent
    }
    
    init(startDir: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.currentDir = startDir
        loadCurrentDirectory()
    }
    
    func loadCurrentDirectory() {
        do {
            let dataKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            
            let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : .skipsHiddenFiles
            
            let content = try FileManager.default.contentsOfDirectory(
                at: currentDir,
                includingPropertiesForKeys: dataKeys,
                options: options
            )
            
            let mappedFiles = content.map { url in
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
//            .sorted {
//                if $0.itemType == .DIRECTORY && $1.itemType == .FILE { return true }
//                if $0.itemType == .FILE && $1.itemType == .DIRECTORY { return false }
//                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
//            }
            
            self.files = mappedFiles.sorted {
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

struct FileGridItemView: View {
    let file: FileItem
    let onDoubleTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            FileIconView(file: file, baseSize: 64)
            Text(file.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(alignment: .top)
        }
        .padding(8)
        .frame(width: 128)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .contextMenu {
            Button("Copy Full Path") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.url.path, forType: .string)
            }
        }
    }
}

struct InteractivePathTitleView: View {
    let fullPath: String
    let folderName: String
    
    @State private var isHoveringPath = false
    @State private var showCopyFeedback = false
    
    var body: some View {
        HStack(spacing: 6) {
            if isHoveringPath {
                Text(fullPath)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    // Płynne wejście/wyjście samej ścieżki
                    .transition(.asymmetric(insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                                            removal: .identity))
            } else {
                Text(folderName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .transition(.identity)
            }
            
            if isHoveringPath {
                Image(systemName: showCopyFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(showCopyFeedback ? .green : .secondary)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(isHoveringPath ? Color(NSColor.quaternaryLabelColor) : Color.clear)
        .cornerRadius(4)
        .frame(minWidth: 140, maxWidth: 320, alignment: .leading)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHoveringPath)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isHoveringPath = hovering
            }
        }
        .onTapGesture {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(fullPath, forType: .string)
            
            withAnimation(.easeInOut(duration: 0.15)) {
                showCopyFeedback = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showCopyFeedback = false
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var viewModel = FolderViewModel()
    @State private var selectedSideBarItem: SideBarItem? = .home
    @State private var selectedElementsViewStyle: ElementsViewStyle = .grid
    
    let gridCols = [
        GridItem(.adaptive(minimum: 130), spacing: 16)
    ]
    
    var body: some View {
        NavigationSplitView {
            List(SideBarItem.allCases, selection: $selectedSideBarItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.iconName)
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("")
        } detail: {
            VStack {
                if selectedElementsViewStyle == .list {
                    List {
                        ForEach(viewModel.files) { file in
                            HStack {
                                FileIconView(file: file, baseSize: 64)
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
                                    } catch {
                                        print("Error while moving item to trash \(error.localizedDescription)")
                                    }
                                }) {
                                    Text("Move to Trash")
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridCols, spacing: 16) {
                            ForEach(viewModel.files) { file in
                                FileGridItemView(file: file) {
                                    if file.itemType == .DIRECTORY {
                                        viewModel.enterDirectory(dir: file)
                                    } else {
                                        NSWorkspace.shared.open(file.url)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background()
                    .contextMenu {
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(viewModel.currentDir.path, forType: .string)
                        }) {
                            Text("Copy Current Directory Path")
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 400)
            .navigationTitle("")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: { viewModel.goToParentDirectory() }) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(viewModel.currentDir.path == "/")
                    
                    Button(action: { viewModel.loadCurrentDirectory() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigation) {
                    InteractivePathTitleView(
                        fullPath: viewModel.currentDir.path,
                        folderName: viewModel.currentDirName
                    )
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $viewModel.showHiddenFiles) {
                        Label("Show Hidden", systemImage: viewModel.showHiddenFiles ? "eye" : "eye.slash")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Picker("View Style", selection: $selectedElementsViewStyle) {
                        ForEach(ElementsViewStyle.allCases) { style in
                            Label(style.rawValue, systemImage: style.iconName)
                                .tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
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
