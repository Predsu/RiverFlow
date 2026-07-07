import SwiftUI
import Foundation
import Observation

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
