import SwiftUI

struct SidebarView: View {
    let viewModel: FolderViewModel
    @State private var isFavoritesDropTargeted = false

    private var favoriteEntries: [SidebarEntry] {
        let rootIDs = Set(viewModel.favoriteSidebarRoots.map(\.id))
        return viewModel.visibleSidebarEntries.filter { rootIDs.contains($0.rootID) }
    }

    private var locationEntries: [SidebarEntry] {
        let rootIDs = Set(viewModel.sidebarRoots.map(\.id))
        return viewModel.visibleSidebarEntries.filter { rootIDs.contains($0.rootID) }
    }

    private func sidebarRow(_ entry: SidebarEntry) -> some View {
        SidebarNodeRow(
            node: entry.node,
            depth: entry.depth,
            isSelected: viewModel.selectedSidebarNodeID == entry.id,
            showHiddenFiles: viewModel.showHiddenFiles,
            onToggle: { viewModel.toggleSidebarNode(entry.node) }
        )
        .tag(entry.id)
        .id(entry.id)
        .draggable(entry.node.url)
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.addSidebarFavorites(urls)
        } isTargeted: { targeted in
            isFavoritesDropTargeted = targeted
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: Binding(
                get: { viewModel.selectedSidebarNodeID },
                set: { viewModel.selectSidebarNode($0) }
            )) {
                Section {
                    if viewModel.favoriteSidebarRoots.isEmpty {
                        Label("Drop folders here", systemImage: "star")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .selectionDisabled()
                            .contentShape(Rectangle())
                            .dropDestination(for: URL.self) { urls, _ in
                                viewModel.addSidebarFavorites(urls)
                            } isTargeted: { targeted in
                                isFavoritesDropTargeted = targeted
                            }
                    }
                    ForEach(favoriteEntries) { entry in
                        sidebarRow(entry)
                            .contextMenu {
                                if entry.depth == 0 {
                                    Button("Remove from Favorites", systemImage: "star.slash") {
                                        viewModel.removeSidebarFavorite(entry.node)
                                    }
                                }
                            }
                    }
                } header: {
                    Text("Favorites")
                        .foregroundStyle(isFavoritesDropTargeted ? Color.accentColor : Color.secondary)
                }
                Section("Locations") {
                    ForEach(locationEntries) { entry in
                        sidebarRow(entry)
                            .contextMenu {
                                Button("Add to Favorites", systemImage: "star") {
                                    viewModel.addSidebarFavorites([entry.node.url])
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .dropDestination(for: URL.self) { urls, _ in
                viewModel.addSidebarFavorites(urls)
            } isTargeted: { targeted in
                isFavoritesDropTargeted = targeted
            }
            .onKeyPress(.rightArrow) {
                viewModel.moveInSidebar(expanding: true) ? .handled : .ignored
            }
            .onKeyPress(.leftArrow) {
                viewModel.moveInSidebar(expanding: false) ? .handled : .ignored
            }
            .onChange(of: viewModel.sidebarRevealRevision) { _, _ in
                if let id = viewModel.selectedSidebarNodeID {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onAppear {
                if let id = viewModel.selectedSidebarNodeID {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button("Collapse All", systemImage: "chevron.up.chevron.down") {
                        viewModel.collapseSidebar()
                    }
                    .help("Collapse all sidebar folders")
                    Spacer(minLength: 4)
                    Button {
                        viewModel.expandToURL(viewModel.currentDir)
                    } label: {
                        Image(systemName: "scope")
                    }
                    .help("Reveal Current Folder")
                    .accessibilityLabel("Reveal Current Folder")
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .padding(10)
            }
            .background(Material.ultraThin)
        }
        .navigationTitle("")
    }
}

private struct SidebarNodeRow: View {
    let node: SidebarNode
    let depth: Int
    let isSelected: Bool
    let showHiddenFiles: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            if node.hasSubfolders(showHidden: showHiddenFiles) {
                Button(action: onToggle) {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .frame(width: 16, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(node.isExpanded ? "Collapse" : "Expand") \(node.name)")
            } else {
                Color.clear.frame(width: 16, height: 22)
            }
            Label {
                Text(node.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: node.iconName)
            }
            Spacer(minLength: 0)
        }
        // Keep names usable even for paths many levels below the chosen root.
        .padding(.leading, CGFloat(min(depth, 3)) * 10)
        .contentShape(Rectangle())
        .help(node.url.path)
    }
}
