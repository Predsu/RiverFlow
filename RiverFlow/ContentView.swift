import SwiftUI
import Foundation
import Observation

struct ContentView: View {
    @State private var viewModel = FolderViewModel()
    @State private var selectedSideBarItem: SideBarItem? = .home
    @State private var selectedElementsViewStyle: ElementsViewStyle = .grid
    
    // Stan przechowujący ID aktualnie zaznaczonego pliku/folderu
    @State private var selectedFileId: UUID? = nil
    
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
                                FileIconView(file: file, baseSize: 18) // mniejszy rozmiar ikony dopasowany do listy
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
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            // Subtelne tło i outline dla zaznaczonego wiersza listy
                            .background(selectedFileId == file.id ? Color(.selectedControlColor).opacity(0.2) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(.selectedControlColor), lineWidth: selectedFileId == file.id ? 1.5 : 0)
                            )
                            .contentShape(Rectangle())
                            // Zintegrowana, równoległa obsługa kliknięć na liście zapobiegająca zatorom
                            .gesture(
                                TapGesture(count: 1)
                                    .onEnded {
                                        selectedFileId = file.id
                                    }
                                    .simultaneously(
                                        with: TapGesture(count: 2)
                                            .onEnded {
                                                selectedFileId = file.id
                                                if file.itemType == .DIRECTORY {
                                                    viewModel.enterDirectory(dir: file)
                                                    selectedFileId = nil
                                                } else {
                                                    NSWorkspace.shared.open(file.url)
                                                }
                                            }
                                    )
                            )
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
                                FileGridItemView(
                                    file: file,
                                    isSelected: selectedFileId == file.id,
                                    onTap: {
                                        selectedFileId = file.id
                                    },
                                    onDoubleTap: {
                                        if file.itemType == .DIRECTORY {
                                            viewModel.enterDirectory(dir: file)
                                            selectedFileId = nil
                                        } else {
                                            NSWorkspace.shared.open(file.url)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .contentShape(Rectangle())
                    // Kliknięcie w puste tło siatki odznacza aktualnie wybrany element
                    .onTapGesture {
                        selectedFileId = nil
                    }
                    .contextMenu {
                        Button(action: {
                            viewModel.createNewDirectory()
                        }) {
                            Text("Create Folder")
                            Image(systemName: "folder.badge.plus")
                        }
                        
                        Button(action: {
                            viewModel.createNewFile()
                        }) {
                            Text("Create File")
                            Image(systemName: "doc.badge.plus")
                        }
                        
                        Divider()
                        
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
            selectedFileId = nil // resetujemy zaznaczenie przy przełączaniu zakładek w SideBarze
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
