import SwiftUI

struct SidebarView: View {
    let viewModel: FolderViewModel
    @Binding var selectedFolderURL: URL?
    
    var body: some View {
        List(viewModel.sidebarRoots, selection: $selectedFolderURL) { root in
            SidebarNodeRow(
                node: root,
                selectedFolderURL: $selectedFolderURL,
                showHiddenFiles: viewModel.showHiddenFiles
            )
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("")
    }
}

struct SidebarNodeRow: View {
    let node: SidebarNode
    @Binding var selectedFolderURL: URL?
    let showHiddenFiles: Bool
    
    var body: some View {
        if node.hasSubfolders {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { node.isExpanded },
                    set: { val in
                        node.isExpanded = val
                        if val {
                            node.loadChildren(showHidden: showHiddenFiles)
                        }
                    }
                ),
                content: {
                    ForEach(node.children) { child in
                        SidebarNodeRow(
                            node: child,
                            selectedFolderURL: $selectedFolderURL,
                            showHiddenFiles: showHiddenFiles
                        )
                    }
                },
                label: {
                    NavigationLink(value: node.url) {
                        Label(node.name, systemImage: node.iconName)
                    }
                }
            )
        } else {
            NavigationLink(value: node.url) {
                Label(node.name, systemImage: node.iconName)
            }
        }
    }
}
